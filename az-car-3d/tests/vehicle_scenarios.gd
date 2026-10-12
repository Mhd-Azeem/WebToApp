extends RefCounted
const T = preload("res://scripts/transmission.gd")
const G = preload("res://scripts/geometry.gd")
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func settle(scene: Node3D) -> void:
	for i in range(90): await scene.get_tree().physics_frame
func track(scene: Node3D,slope: float) -> MeshInstance3D:
	var road := G.box(scene,Vector3(1500,35,0),Vector3(26,1,300),G.material("asphalt"),true)
	road.rotation.x=slope
	return road
func place(car: VehicleBody3D,road: Node3D,speed: float) -> void:
	car.reset()
	car.global_transform=Transform3D(road.global_basis*Basis(Vector3.UP,PI),road.to_global(Vector3(0,1,80)))
	car.transmission.mode=T.Mode.AUTOMATIC
	car.transmission.selector="P"
	car.controls_enabled=true
	car.release_controls()
	car.linear_velocity=car.global_basis.z*speed
func rolling_trial(scene: Node3D,slope: float,in_gear: bool = false,brake: float = 0.0,handbrake: bool = false) -> Vector2:
	var road := track(scene,slope)
	place(scene.car,road,0)
	await settle(scene)
	var car: VehicleBody3D=scene.car
	car.transmission.mode=T.Mode.MANUAL
	car.transmission.gear=3 if in_gear else 0
	car.clutch_pedal=0 if in_gear else 1
	car.transmission.clutch=car.clutch_pedal
	car.pedal_brake=brake
	car.handbrake=1.0 if handbrake else 0.0
	car.linear_velocity=car.global_basis.z*(60.0/3.6)
	car.transmission.rpm=60/3.6/car.transmission.config.wheel_radius_m*car.transmission.config.forward_ratios[3]*car.transmission.config.final_drive*60/TAU if in_gear else 800
	var start := car.position
	for i in range(180): await scene.get_tree().physics_frame
	var result := Vector2(car.signed_speed,car.position.distance_to(start))
	road.queue_free()
	await scene.get_tree().physics_frame
	return result
func power_trial(scene: Node3D,slope: float) -> Vector3:
	var road := track(scene,slope)
	place(scene.car,road,0)
	await settle(scene)
	var car: VehicleBody3D=scene.car
	car.transmission.mode=T.Mode.MANUAL
	car.transmission.gear=3
	car.transmission.clutch=0
	car.transmission.rpm=60/3.6/car.transmission.config.wheel_radius_m*car.transmission.config.forward_ratios[3]*car.transmission.config.final_drive*60/TAU
	car.linear_velocity=car.global_basis.z*(60.0/3.6)
	car.gas=0.5
	var load_sum := 0.0
	var start := car.position
	for i in range(150):
		await scene.get_tree().physics_frame
		load_sum+=car.transmission.engine.load
	var result := Vector3(car.signed_speed,load_sum/150,car.position.distance_to(start))
	road.queue_free()
	await scene.get_tree().physics_frame
	return result
func run(scene: Node3D) -> int:
	var coast: Vector2=await rolling_trial(scene,0)
	var coupled: Vector2=await rolling_trial(scene,0,true)
	var braked: Vector2=await rolling_trial(scene,0,false,0.65)
	var handbraked: Vector2=await rolling_trial(scene,0,false,0,true)
	check(coast.x>14 and coast.y>35,"Neutral continues coasting at speed without hidden damping")
	check(coupled.x<coast.x-1,"Coupled engine braking slows actual chassis more than neutral")
	check(braked.x<5 and braked.y<coast.y,"Wheel brake torque decelerates actual vehicle")
	check(handbraked.x<coast.x-3,"Rear-wheel handbrake decelerates vehicle")
	var up_coast: Vector2=await rolling_trial(scene,0.09)
	var down_coast: Vector2=await rolling_trial(scene,-0.09)
	check(down_coast.x>coast.x+1 and up_coast.x<coast.x-1,"Physical road slope and gravity change coasting speed")
	var flat: Vector3=await power_trial(scene,0)
	var uphill: Vector3=await power_trial(scene,0.09)
	check(uphill.x<flat.x-1,"Same throttle accelerates less uphill")
	check(uphill.y>flat.y+0.005,"Uphill increases measured clutch / engine load")
	# Park holds a physical incline without assigning zero velocity every frame.
	var road := track(scene,0.09)
	place(scene.car,road,0)
	await settle(scene)
	var start: Vector3=scene.car.position
	for i in range(180): await scene.get_tree().physics_frame
	check(scene.car.position.distance_to(start)<0.3,"Automatic Park wheel lock holds incline")
	road.queue_free()
	await scene.get_tree().physics_frame
	# A real incline launch with a held handbrake and progressive analog clutch.
	road=track(scene,0.09)
	place(scene.car,road,0)
	await settle(scene)
	scene.car.transmission.mode=T.Mode.MANUAL
	scene.car.transmission.gear=1
	scene.car.transmission.clutch=1
	scene.car.clutch_pedal=1
	scene.car.handbrake=1
	scene.car.gas=0.45
	for i in range(36): await scene.get_tree().physics_frame
	scene.car.clutch_pedal=0.5
	for i in range(18): await scene.get_tree().physics_frame
	start=scene.car.position
	scene.car.handbrake=0
	for i in range(150):
		scene.car.clutch_pedal=maxf(0,0.5-float(i)/180)
		await scene.get_tree().physics_frame
	check(scene.car.transmission.running and scene.car.position.z<start.z-1,"Handbrake-assisted analog clutch hill start climbs without stalling")
	road.queue_free()
	await scene.get_tree().physics_frame
	# Native audio parameter regression: same vehicle speed, actual engine state.
	var audio: Node=scene.find_children("*","AudioStreamPlayer",true,false)[0].get_parent()
	scene.car.freeze=true
	scene.car.set_physics_process(false)
	audio.set_process(false)
	var pitches := []
	for gear in [2,5]:
		scene.car.transmission=T.new()
		scene.car.transmission.gear=gear
		for i in range(300): scene.car.transmission.update(1.0/120,60/3.6,0.25)
		for i in range(80): audio._process(1.0/60)
		pitches.append(audio.frequency)
		var sum := 0.0
		for weight in audio.layer_weights: sum+=weight
		check(absf(sum-1)<0.01 and audio.engine_mix>0,"RPM layers crossfade continuously with nonzero combustion audio")
	check(pitches[0]>pitches[1]*2.5,"At identical road speed, second produces higher native audio pitch than fifth")
	scene.car.transmission.engine.stop()
	for i in range(120): audio._process(1.0/60)
	check(audio.engine_mix==0 and audio.layers.all(func(p: AudioStreamPlayer): return not p.playing),"Shutdown stops combustion streams while road/wind can remain")
	audio.set_process(true)
	scene.car.set_physics_process(true)
	scene.car.freeze=false
	print("Physical vehicle scenarios: ","PASS" if failures==0 else "FAIL", " coast/brake ",coast," / ",braked," uphill/flat ",uphill," / ",flat," 60 km/h audio Hz ",pitches)
	return failures

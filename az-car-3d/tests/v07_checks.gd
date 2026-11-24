extends SceneTree

const Graphics = preload("res://scripts/adaptive_graphics.gd")
const Road = preload("res://scripts/regional_road.gd")
const Navigation = preload("res://scripts/road_navigation.gd")
const Progress = preload("res://scripts/driving_progress.gd")
const Signals = preload("res://scripts/traffic_signal.gd")
const WheelPhysics = preload("res://scripts/drivetrain/wheel_physics_controller.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures+=1
		push_error(message)

func run() -> void:
	check_models()
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var landscape = scene.landscape
	var spawn_chunks: Dictionary = landscape.chunks.duplicate()
	check(spawn_chunks.size()>12 and spawn_chunks.size()<85,"Spawn keeps only nearby terrain")
	var highland: Vector3=Road.DESTINATIONS[2][1]
	landscape.stream_at(highland,true)
	await physics_frame
	await physics_frame
	var released := 0
	for key in spawn_chunks:
		if not is_instance_valid(spawn_chunks[key]): released+=1
	check(released>0 and landscape.chunks.size()<90,"Distant chunks and collision bodies are freed")
	for i in range(Road.LINE.size()):
		var point: Vector3=Road.LINE[i]
		landscape.stream_at(point,true)
		await physics_frame
		var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*4,point-Vector3.UP*2,1)
		var hit := root.world_3d.direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.collider.get_meta("surface","")=="asphalt" and absf(hit.position.y-point.y)<0.35,
			"Regional asphalt collision supports road joint %d" % i)
		if i>0:
			var previous: Vector3=Road.LINE[i-1]
			var middle := previous.lerp(point,0.5)
			query.from=middle+Vector3.UP*4
			query.to=middle-Vector3.UP*2
			hit=root.world_3d.direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider.get_meta("surface","")=="asphalt" and absf(hit.position.y-middle.y)<0.30,
				"Regional asphalt collision supports segment %d" % i)
	scene.settings.quality_selector.select(Graphics.Preset.ULTRA_LOW)
	scene._select_quality()
	check(Engine.max_fps==30 and scene.camera.far==150 and scene.traffic.density==4,
		"Ultra Low changes frame cap, range, and traffic")
	scene.settings.quality_selector.select(Graphics.Preset.HIGH)
	scene._select_quality()
	check(Engine.max_fps==60 and scene.camera.far==285 and scene.traffic.density==10,
		"High changes frame cap, range, and traffic")
	scene.weather_selector.select(1)
	scene._update_weather()
	check(scene.rain.visible and scene.car.wheel_physics.wet_roads,"Rain reduces road grip")
	scene.weather_selector.select(2)
	scene._update_weather()
	check(not scene.rain.visible and not scene.car.wheel_physics.wet_roads and root.world_3d.environment.fog_depth_end < 200,
		"Fog uses a shorter visibility range")
	scene.car.linear_velocity=Vector3.ZERO
	scene.gameplay._switch_vehicle(1)
	check(scene.car.garage_kind=="hatchback" and scene.car.drive_multiplier<1.0,"Garage changes model and driving profile")
	scene.gameplay._switch_vehicle(2)
	check(scene.car.garage_kind=="suv" and scene.car.mass>scene.car.transmission.config.mass_kg,"SUV has a heavier driving profile")
	scene.gameplay._switch_vehicle(0)
	scene.interior.set_headlights(true)
	check(scene.interior.lamps[0].visible,"Headlamp control changes actual light output")
	scene.camera_mode=3
	await process_frame
	await process_frame
	check(scene.camera.global_position.distance_to(scene.car.global_position)>2.5,"Orbit camera tracks the car")
	scene.car.position=Vector3(9,1,62)
	scene.car.recovery_point=Vector3(-3.5,1,120)
	scene.car.recover()
	check(absf(scene.car.position.x)<6 and absf(scene.car.position.z-62)<19,"Recovery selects a supported clear lane near the vehicle")
	scene.desktop_mode=false
	scene.steering_selector.select(1)
	await process_frame
	var wheel = scene.steering_wheel
	var touch := InputEventScreenTouch.new()
	touch.index=8
	touch.position=wheel.position+Vector2(40,0)
	touch.pressed=true
	root.push_input(touch,true)
	var drag := InputEventScreenDrag.new()
	drag.index=8
	drag.position=wheel.position+Vector2(0,40)
	root.push_input(drag,true)
	check(absf(scene.car.turn)>0.6,"Native wheel drag produces analog steering")
	touch.pressed=false
	root.push_input(touch,true)
	check(is_zero_approx(scene.car.turn),"Releasing the wheel centers touch steering")
	scene.queue_free()
	await process_frame
	await physics_frame
	print("v0.7 streaming / regional roads / graphics / garage / controls / weather: ", "PASS" if failures==0 else "FAIL")
	quit(1 if failures else 0)

func check_models() -> void:
	var auto := Graphics.new()
	auto.choose(Graphics.Preset.AUTO,60)
	for frame in range(12): auto.sample(0.10)
	check(auto.tier==Graphics.Preset.MEDIUM,"Auto ignores short frame spikes")
	for frame in range(95): auto.sample(0.055)
	check(auto.tier==Graphics.Preset.LOW,"Auto reduces quality for sustained slow frames")
	auto.reset_sample()
	for frame in range(1150): auto.sample(1.0/60.0)
	check(auto.tier>=Graphics.Preset.MEDIUM,"Auto restores quality after sustained headroom")
	check(Signals.permits(true,3) and not Signals.permits(false,3) and Signals.permits(false,16),
		"Traffic signals permit only the green direction")
	var surface := Node.new()
	surface.set_meta("surface","sand")
	check(WheelPhysics.surface_grip(surface,false)<WheelPhysics.surface_grip(null,true)
		and WheelPhysics.surface_grip(null,true)<WheelPhysics.surface_grip(null,false),"Sand and wet asphalt reduce traction")
	surface.free()
	var navigation := Navigation.new()
	var path := navigation.route(Vector3(-3.5,0,120),Road.DESTINATIONS[2][1])
	check(path.size()>6 and path[0].is_equal_approx(Vector3(-3.5,0,120))
		and path[-1].is_equal_approx(Road.DESTINATIONS[2][1]),"GPS connects Colombo to the highland")
	var progress := Progress.new()
	progress.start(1)
	check(progress.target()==0 and not progress.arrive(0).is_empty() and progress.target()==4,
		"Delivery switches from cargo pickup to its destination")
	var file := "user://v07-test-progress.cfg"
	progress.vehicle=2
	progress.wheels=1
	progress.paint=3
	progress.fuel[2]=17.5
	check(progress.save_to(file)==OK,"Progress writes an offline save")
	var restored := Progress.new()
	restored.load_from(file)
	check(restored.target()==4 and restored.vehicle==2 and restored.wheels==1 and restored.paint==3
		and is_equal_approx(restored.fuel[2],17.5),"Save reload restores vehicle, appearance, fuel and active delivery")
	var credits := restored.credits
	restored.arrive(4)
	check(restored.completed.has(1) and restored.credits>credits and restored.mission==-1
		and "First mission" in restored.achievements,"Delivery awards credits, achievement and free roam")
	check(restored.save_to(file)==OK,"Atomic save replaces the previous save")
	DirAccess.remove_absolute(file)

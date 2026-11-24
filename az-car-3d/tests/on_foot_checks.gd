extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool,message: String) -> void:
	if not condition:
		failures+=1
		push_error(message)

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in range(45): await physics_frame
	var mobility = scene.on_foot
	check(mobility.driving() and scene.car.controls_enabled,"Driving starts with existing controls")
	scene.car.linear_velocity=Vector3(8,0,0)
	mobility.toggle(false)
	check(not mobility.walking and not mobility.busy,"Moving vehicle rejects exit")
	scene.car.linear_velocity=Vector3.ZERO
	await mobility.toggle(false)
	check(mobility.walking and mobility.person.live and not scene.car.controls_enabled,"Safe exit activates the walking body")
	check(scene.landscape.player==mobility.person and scene.rear_view.suspended,"Terrain follows the pedestrian and reverse camera suspends")
	var person = mobility.person
	check(person.model.animations.has_animation("Sprint") and person.model.animations.has_animation("Sitting_Exit"),"Textured rig imports locomotion and seat clips")
	person.model.dress(1)
	check(person.model.animations.has_animation("Walk"),"Alternate adult rig imports walking animation")
	var origin: Vector3=person.global_position
	var start := InputEventKey.new()
	start.physical_keycode=KEY_W
	start.pressed=true
	Input.parse_input_event(start)
	for i in range(35): await physics_frame
	var stop := InputEventKey.new()
	stop.physical_keycode=KEY_W
	stop.pressed=false
	Input.parse_input_event(stop)
	check(person.global_position.distance_to(origin)>0.5,"Keyboard walking moves the rigid collision capsule")
	for i in range(18): await physics_frame
	var height: float=person.position.y
	person.jump=true
	for i in range(12): await physics_frame
	check(person.position.y>height+0.20,"Jump rises above the ground")
	person.position=scene.car.to_global(Vector3(-1.65,0.1,0.22))
	await mobility.toggle(true)
	check(not mobility.walking and not mobility.driving() and not scene.car.controls_enabled,"Passenger seat suppresses driver input")
	await mobility.toggle(false)
	check(mobility.walking and person.position.distance_to(scene.car.position)>1.2,"Passenger exits through the selected side")
	person.position=scene.car.to_global(Vector3(1.65,0.1,0.22))
	await mobility.toggle(false)
	check(mobility.driving() and scene.car.controls_enabled and not person.live,"Driver entry restores driving controls")
	scene.queue_free()
	await process_frame
	print("On-foot and vehicle transitions: ", "PASS" if failures==0 else "FAIL")
	quit(1 if failures else 0)

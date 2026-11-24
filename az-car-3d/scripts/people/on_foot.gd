extends Node

signal mode_changed(walking: bool)
signal interact_requested
const Geometry = preload("res://scripts/geometry.gd")
const Person = preload("res://scripts/people/person.gd")
const Joystick = preload("res://scripts/people/walk_controls.gd")
const DRIVER := Vector3(0.42,0.10,0.21)
const PASSENGER := Vector3(-0.42,0.10,0.21)
const EXIT_SPEED := 1.25

var person: CharacterBody3D
var car: VehicleBody3D
var camera: Camera3D
var layer: CanvasLayer
var joystick: Node2D
var buttons: Array[TouchScreenButton] = []
var prompt: Label
var notice := ""
var walking := false
var busy := false
var enabled := true
var model_index := 0
var hairstyle := -1
var sprint := false
var crouch := false
var swipe_finger := -1
var yaw := 0.0
var pitch := 0.20
var zoom := 4.0
var smooth_target := Vector3.ZERO
var seat := DRIVER
var passenger_occupied := false
var previous_handbrake := 0.0
var door: Node3D

func setup(ui: CanvasLayer, vehicle: VehicleBody3D, view: Camera3D) -> void:
	layer=ui
	car=vehicle
	camera=view
	person=Person.new()
	get_parent().add_child(person)
	person.hide()
	joystick=Joystick.new()
	joystick.position=Vector2(128,595)
	joystick.set_meta("base_position",joystick.position)
	layer.add_child(joystick)
	prompt=Label.new()
	prompt.position=Vector2(20,24)
	prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(prompt)
	_button("Walk / enter",Vector2(1080,376),func(): toggle(false))
	_button("Passenger",Vector2(1080,438),func(): toggle(true))
	_button("Interact",Vector2(1080,500),func(): interact_requested.emit())
	_button("Jump",Vector2(1135,562),func(): person.jump=true)
	_button("Crouch",Vector2(1028,562),func(): crouch=not crouch)
	var sprint_button := _button("Sprint",Vector2(1080,622),func(): sprint=true)
	sprint_button.released.connect(func(): sprint=false)

func _button(label: String, point: Vector2, callback: Callable) -> TouchScreenButton:
	var button := TouchScreenButton.new()
	var area := RectangleShape2D.new()
	area.size=Vector2(130,49)
	button.shape=area
	button.shape_centered=false
	button.position=point
	button.set_meta("base_position",point)
	var face := Label.new()
	face.position=-area.size/2
	face.size=area.size
	face.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	face.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var backing := StyleBoxFlat.new()
	backing.bg_color=Color(0.06,0.09,0.12,0.83)
	backing.set_corner_radius_all(10)
	face.add_theme_stylebox_override("normal",backing)
	face.text=label
	button.add_child(face)
	layer.add_child(button)
	button.pressed.connect(func():
		if enabled and not busy: callback.call())
	buttons.append(button)
	return button

func toggle(passenger: bool) -> void:
	if busy or not enabled: return
	if car.linear_velocity.length()>EXIT_SPEED:
		notice="Stop the vehicle first"
		return
	if walking:
		if passenger and passenger_occupied:
			notice="The passenger seat is occupied"
			return
		if person.global_position.distance_to(car.global_position)>3.1:
			notice="Move closer to the vehicle"
			return
		var destination := PASSENGER if passenger else DRIVER
		var door_point := car.to_global(Vector3(signf(destination.x)*1.15,0.1,0.25))
		if person.global_position.distance_to(door_point)>2.4:
			notice="Approach the selected door"
			return
		seat=destination
		await _transition(false,door_point)
	else:
		var point := exit_position(seat.x)
		if point==Vector3.INF:
			notice="Exit blocked"
			return
		await _transition(true,point)

func exit_position(side: float) -> Vector3:
	var space := car.get_world_3d().direct_space_state
	for distance in [1.45,1.83]:
		var side_point := car.to_global(Vector3(signf(side)*distance,0.35,0.22))
		var ray := PhysicsRayQueryParameters3D.create(side_point+Vector3.UP,side_point-Vector3.UP*1.35,1)
		ray.exclude=[car.get_rid(),person.get_rid()]
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y<0.62: continue
		var feet: Vector3=hit.position+Vector3.UP*0.06
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape=person.capsule
		query.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*(person.capsule.height*0.5))
		query.collision_mask=11
		query.exclude=[person.get_rid()]
		if space.intersect_shape(query,1).is_empty(): return feet
	return Vector3.INF

func _transition(leaving: bool, door_point: Vector3) -> void:
	busy=true
	notice=""
	clear_input()
	if leaving:
		previous_handbrake=car.handbrake
		car.handbrake=1.0
	car.release_controls()
	if person.model.animations==null: person.model.dress(model_index,Color.WHITE,hairstyle)
	person.set_live(false)
	person.show()
	person.model.rotation.y=car.global_rotation.y
	if leaving: person.global_position=car.to_global(seat)
	var destination := door_point if leaving else car.to_global(seat)
	walking=true
	person.locked=true
	smooth_target=person.position+Vector3.UP
	if leaving: yaw=car.global_rotation.y+PI
	mode_changed.emit(true)
	person.model.play("Sitting_Exit" if leaving else "Sitting_Enter",0.06)
	var motion := create_tween()
	var side := signf(seat.x)
	door=_make_door(side)
	motion.tween_property(door,"rotation:y",-side*0.92,0.18)
	motion.parallel().tween_property(person,"global_position",destination,0.58).set_trans(Tween.TRANS_SINE)
	motion.tween_property(door,"rotation:y",0.0,0.20)
	await motion.finished
	door.queue_free()
	door=null
	person.locked=false
	walking=leaving
	busy=false
	if leaving:
		person.set_live(true)
		person.model.play("Idle_Loop")
	else:
		person.model.play("Driving_Loop" if seat==DRIVER else "Sitting_Idle_Loop")
		car.handbrake=previous_handbrake if seat==DRIVER else 1.0
	mode_changed.emit(walking)

func _make_door(side: float) -> Node3D:
	var pivot := Node3D.new()
	car.add_child(pivot)
	pivot.position=Vector3(side*0.94,0.82,0.94)
	var paint: Material=car.paint_material
	var panel := Geometry.box(pivot,Vector3(0,-0.07,-0.53),Vector3(0.055,0.45,1.05),paint)
	panel.layers=4
	var trim := Geometry.material("",Color(0.10,0.12,0.14))
	Geometry.box(pivot,Vector3(side*0.04,0.055,-0.92),Vector3(0.05,0.035,0.18),trim).layers=4
	return pivot

func driving() -> bool:
	return not walking and not busy and seat==DRIVER

func clear_input() -> void:
	person.walk_input=Vector2.ZERO
	person.jump=false
	joystick.clear()
	sprint=false
	swipe_finger=-1

func input_event(event: InputEvent) -> bool:
	if not enabled: return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_T:
			toggle(event.shift_pressed)
			return true
		if walking and event.keycode==KEY_SPACE:
			person.jump=true
			return true
		if walking and event.keycode==KEY_C:
			crouch=not crouch
			return true
	if not walking: return false
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x>290 and event.position.y<550 and event.position.x<1000:
			if swipe_finger<0: swipe_finger=event.index
		elif not event.pressed and event.index==swipe_finger: swipe_finger=-1
	elif event is InputEventScreenDrag and event.index==swipe_finger:
		_rotate(event.relative)
		return true
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		_rotate(event.relative)
		return true
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_UP]:
		zoom=clampf(zoom+(0.4 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -0.4),2.1,6.3)
		return true
	return false

func _rotate(relative: Vector2) -> void:
	yaw-=relative.x*0.006
	pitch=clampf(pitch+relative.y*0.005,-0.32,0.76)

func update(delta: float, mobile: bool) -> void:
	var near_car := walking and person.global_position.distance_to(car.global_position)<=3.1
	buttons[0].visible=mobile and enabled and not busy and (not walking or near_car)
	buttons[1].visible=mobile and enabled and not busy and near_car and not passenger_occupied
	for i in range(2,buttons.size()): buttons[i].visible=mobile and enabled and walking and not busy
	joystick.visible=mobile and enabled and walking and not busy
	joystick.enabled=joystick.visible
	prompt.visible=(walking or not driving()) and enabled
	prompt.text=("T · Exit passenger seat" if not walking else ("T · Driver | Shift+T · Passenger | G · Interact" if near_car else "On foot · G to interact")) if notice.is_empty() else notice
	if not walking:
		if person.visible:
			person.global_position=car.to_global(seat)
			person.model.rotation.y=car.global_rotation.y
		return
	var keyboard := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	person.walk_input=(joystick.stick+keyboard*(0.62 if Input.is_physical_key_pressed(KEY_ALT) else 1.0)).limit_length() if enabled and not busy else Vector2.ZERO
	person.camera_yaw=yaw
	person.sprint=sprint or Input.is_physical_key_pressed(KEY_SHIFT)
	person.crouch=crouch
	var focus: Vector3=person.global_position+Vector3.UP*(0.95 if crouch else 1.35)
	smooth_target=smooth_target.lerp(focus,1.0-exp(-delta*16.0))
	var direction := Vector3(0,sin(pitch),cos(pitch)).rotated(Vector3.UP,yaw)
	var goal := smooth_target+direction*zoom
	var ray := PhysicsRayQueryParameters3D.create(smooth_target,goal,3)
	ray.exclude=[person.get_rid()]
	var hit := car.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): goal=hit.position-direction*0.21
	camera.global_position=goal
	camera.look_at(smooth_target)
	camera.cull_mask=7

extends Node3D
const G = preload("res://scripts/geometry.gd")
var car: VehicleBody3D
var camera: Camera3D
var hud: Label
var cockpit := false
var low_quality := true
var touch_buttons: Array[TouchScreenButton] = []
var sun: DirectionalLight3D
var held := {}
var interior: Node3D
var wheel: MeshInstance3D
var shifter: Node2D

func _ready() -> void:
	var world := Node3D.new()
	world.set_script(preload("res://scripts/world.gd"))
	add_child(world)
	car=VehicleBody3D.new()
	car.set_script(preload("res://scripts/car.gd"))
	add_child(car)
	car.reset()
	sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-42,-28,0)
	sun.light_color=Color(1.0,0.92,0.79)
	sun.light_energy=1.1
	sun.shadow_enabled=false
	sun.directional_shadow_max_distance=75
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode=Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color(0.26,0.48,0.70)
	sky_mat.sky_horizon_color=Color(0.78,0.83,0.83)
	sky.sky_material=sky_mat
	e.sky=sky
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color(0.72,0.80,0.87)
	e.ambient_light_energy=0.65
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.environment=e
	add_child(env)
	camera=Camera3D.new()
	camera.far=260
	camera.fov=68
	add_child(camera)
	camera.current=true
	interior=Node3D.new()
	camera.add_child(interior)
	G.box(interior,Vector3(0,-0.55,-0.8),Vector3(1.8,0.24,0.6),G.material("",Color(0.045,0.06,0.07)))
	wheel=MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius=0.16
	ring.outer_radius=0.20
	ring.rings=16
	ring.ring_segments=12
	wheel.mesh=ring
	wheel.position=Vector3(0,-0.34,-0.64)
	wheel.rotation.x=PI/2
	wheel.material_override=G.material("",Color(0.045,0.045,0.05))
	interior.add_child(wheel)
	G.box(interior,Vector3(-0.57,-0.4,-0.68),Vector3(0.13,0.23,0.1),G.material("",Color(0.13,0.14,0.15)))
	interior.visible=false
	_hud()
	Engine.max_fps=30

func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var backing := ColorRect.new()
	backing.position=Vector2(12,10)
	backing.size=Vector2(650,64)
	backing.color=Color(0.035,0.07,0.09,0.80)
	backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(backing)
	hud=Label.new()
	hud.position=Vector2(22,15)
	hud.size=Vector2(630,57)
	hud.clip_text=true
	hud.add_theme_font_size_override("font_size",14)
	layer.add_child(hud)
	_touch(layer,Vector2(24,560),Vector2(96,96),"left")
	_touch(layer,Vector2(134,560),Vector2(96,96),"right")
	_touch(layer,Vector2(79,444),Vector2(96,96),"clutch")
	_touch(layer,Vector2(990,560),Vector2(104,104),"brake")
	_touch(layer,Vector2(1120,560),Vector2(104,104),"gas")
	shifter=Node2D.new()
	shifter.set_script(preload("res://scripts/ui/h_shifter.gd"))
	shifter.position=Vector2(1042,422)
	shifter.vehicle=car
	layer.add_child(shifter)
	for i in range(4):
		_touch(layer,Vector2(948+i*66,470),Vector2(58,64),"auto"+["P","R","N","D"][i])
	for i in range(4):
		_touch(layer,Vector2(1190,16+i*66),Vector2(60,60),["mode","camera","reset","start"][i])
	_touch(layer,Vector2(24,100),Vector2(58,58),"quality")
	_touch(layer,Vector2(94,100),Vector2(58,58),"regions")

func _touch(parent: Node, pos: Vector2, size: Vector2, id: String) -> void:
	var button := TouchScreenButton.new()
	var image := Image.create(int(size.x),int(size.y),false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	button.texture_normal=ImageTexture.create_from_image(image)
	var shape := RectangleShape2D.new()
	shape.size=size
	button.shape=shape
	button.shape_centered=true
	button.position=pos
	button.set_meta("id",id)
	parent.add_child(button)
	if id.begins_with("auto"):
		var label := Label.new()
		label.text=id.trim_prefix("auto")
		label.size=size
		label.add_theme_font_size_override("font_size",24)
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var backing := ColorRect.new()
		backing.size=size
		backing.color=Color(0.035,0.075,0.11,0.9)
		backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(backing)
		button.add_child(label)
	else:
		var symbol := Node2D.new()
		symbol.set_script(preload("res://scripts/ui/control_symbol.gd"))
		symbol.kind=id
		symbol.extent=size
		button.add_child(symbol)
		button.pressed.connect(func(): symbol.active=true)
		button.released.connect(func(): symbol.active=false)
	button.pressed.connect(func(): _press(id,true))
	button.released.connect(func(): _press(id,false))
	touch_buttons.append(button)

func _press(id: String, down: bool) -> void:
	held[id]=down
	car.gas=float(held.get("gas",false))
	car.pedal_brake=float(held.get("brake",false))
	car.clutch_pedal=float(held.get("clutch",false))
	car.turn=float(held.get("left",false))-float(held.get("right",false))
	if not down: return
	if id.begins_with("gear"): car.transmission.shift(int(id.trim_prefix("gear")),car.signed_speed)
	elif id.begins_with("auto"): car.transmission.select(id.trim_prefix("auto"),car.signed_speed,maxf(car.pedal_brake,float(Input.is_key_pressed(KEY_S))))
	elif id=="mode": car.transmission.toggle(car.signed_speed)
	elif id=="start": car.transmission.restart()
	elif id=="reset": car.reset()
	elif id=="camera": cockpit=not cockpit
	elif id=="quality":
		low_quality=not low_quality
		sun.shadow_enabled=not low_quality
		Engine.max_fps=30 if low_quality else 60
	elif id=="regions": car.transmission.message="Playable: Colombo • Planned: Kandy hills / Galle coast / rural villages"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var t = car.transmission
		if event.keycode==KEY_M: t.toggle(car.signed_speed)
		elif event.keycode==KEY_V: cockpit=not cockpit
		elif event.keycode==KEY_E: t.restart()
		elif event.keycode==KEY_P: t.select("P",car.signed_speed,float(Input.is_key_pressed(KEY_S)))
		elif event.keycode==KEY_R:
			if t.mode==0: t.shift(-1,car.signed_speed)
			else: t.select("R",car.signed_speed,float(Input.is_key_pressed(KEY_S)))
		elif event.keycode==KEY_N:
			if t.mode==0: t.shift(0,car.signed_speed)
			else: t.select("N",car.signed_speed,0)
		elif event.keycode==KEY_F: t.select("D",car.signed_speed,float(Input.is_key_pressed(KEY_S)))
		elif event.keycode>=KEY_1 and event.keycode<=KEY_5: t.shift(event.keycode-KEY_0,car.signed_speed)

func _process(delta: float) -> void:
	interior.visible=cockpit
	wheel.rotation.z=-car.steering*2.5
	if cockpit:
		camera.global_position=car.to_global(Vector3(-0.42,1.58,0.5))
		camera.look_at(camera.global_position+car.global_basis.z*10,car.global_basis.y)
		car.visual.visible=false
	else:
		car.visual.visible=true
		var desired := car.to_global(Vector3(0,4.1,-8.5))
		var target := car.global_position+Vector3(0,1.2,0)
		var query := PhysicsRayQueryParameters3D.create(target,desired)
		query.exclude=[car.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): desired=hit.position+(target-hit.position).normalized()*0.5
		camera.global_position=camera.global_position.lerp(desired,minf(1,delta*7))
		camera.look_at(target)
	var t = car.transmission
	hud.text="%s  ·  %d km/h  ·  %d RPM  ·  %d FPS\nClutch %d%%  ·  %s  ·  Keep left\n%s" % [t.display(),roundi(absf(car.signed_speed)*3.6),roundi(t.rpm),Engine.get_frames_per_second(),roundi(t.clutch*100),"LOW" if low_quality else "HIGH",t.message]
	shifter.visible=t.mode==0
	for button in touch_buttons:
		var id: String=button.get_meta("id")
		if id.begins_with("gear") or id=="clutch": button.visible=t.mode==0
		if id.begins_with("auto"): button.visible=t.mode==1

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(car):
		held.clear()
		if is_instance_valid(shifter): shifter.cancel()
		car.release_controls()
		get_tree().paused=true
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN: get_tree().paused=false

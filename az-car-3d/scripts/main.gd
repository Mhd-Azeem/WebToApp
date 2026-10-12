extends Node3D
const G = preload("res://scripts/geometry.gd")
var car: VehicleBody3D
var camera: Camera3D
var hud: Label
var cockpit := false
var camera_mode := 0
var gauges: Node2D
var low_quality := true
var touch_buttons: Array[TouchScreenButton] = []
var sun: DirectionalLight3D
var held := {}
var interior: Node3D
var wheel: MeshInstance3D
var shifter: Node2D
var traffic: Node3D
var settings: PanelContainer
var rear_view: Node
var pedals := {}
var desktop_mode := false
var desktop_help: Label

func _ready() -> void:
	var world := Node3D.new()
	world.set_script(preload("res://scripts/world.gd"))
	add_child(world)
	car=VehicleBody3D.new()
	car.set_script(preload("res://scripts/car.gd"))
	add_child(car)
	car.reset()
	traffic=Node3D.new()
	traffic.set_script(preload("res://scripts/traffic.gd"))
	traffic.player=car
	add_child(traffic)
	var engine_audio := Node.new()
	engine_audio.set_script(preload("res://scripts/engine_audio.gd"))
	engine_audio.car=car
	add_child(engine_audio)
	sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-42,-28,0)
	sun.light_color=Color(1.0,0.92,0.79)
	sun.light_energy=1.1
	sun.shadow_enabled=false
	sun.directional_shadow_max_distance=75
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.fog_enabled=true
	e.fog_mode=Environment.FOG_MODE_DEPTH
	e.fog_density=1.0
	e.fog_sky_affect=0.0
	e.fog_light_color=Color(0.48,0.58,0.62)
	e.fog_light_energy=0.8
	e.fog_depth_begin=130
	e.fog_depth_end=185
	e.background_mode=Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color(0.26,0.48,0.70)
	sky_mat.sky_horizon_color=Color(0.78,0.83,0.83)
	sky_mat.ground_horizon_color=sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color=Color(0.24,0.31,0.23)
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
	_build_desktop_cockpit()
	interior.visible=false
	_hud()
	traffic.set_enabled(settings.traffic_toggle.button_pressed)
	_apply_quality(settings.quality_toggle.button_pressed)
	if settings.saved.get_value("driving","automatic",false): car.transmission.toggle(0)
	settings.transmission_selector.select(car.transmission.mode)

func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	settings=PanelContainer.new()
	settings.set_script(preload("res://scripts/ui/driving_settings.gd"))
	layer.add_child(settings)
	settings.traffic_changed.connect(func(value: bool): traffic.set_enabled(value))
	settings.quality_changed.connect(_apply_quality)
	settings.visibility_changed.connect(_settings_visibility)
	settings.transmission_changed.connect(func(mode: int):
		if mode!=car.transmission.mode and car.transmission.toggle(car.signed_speed):
			settings._save("automatic",mode==1)
		settings.transmission_selector.select(car.transmission.mode))
	rear_view=Node.new()
	rear_view.set_script(preload("res://scripts/rear_camera.gd"))
	add_child(rear_view)
	rear_view.setup(layer,car)
	var backing := ColorRect.new()
	backing.position=Vector2(12,10)
	backing.size=Vector2(650,64)
	backing.color=Color(0.035,0.07,0.09,0.80)
	backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(backing)
	gauges=Node2D.new()
	gauges.set_script(preload("res://scripts/ui/hood_gauges.gd"))
	gauges.vehicle=car
	gauges.position=Vector2(640,580)
	layer.add_child(gauges)
	hud=Label.new()
	hud.position=Vector2(22,15)
	hud.size=Vector2(630,57)
	hud.clip_text=true
	hud.add_theme_font_size_override("font_size",14)
	layer.add_child(hud)
	_touch(layer,Vector2(24,560),Vector2(96,96),"left")
	_touch(layer,Vector2(134,560),Vector2(96,96),"right")
	_analog(layer,Vector2(79,444),Vector2(96,96),"clutch")
	_analog(layer,Vector2(990,560),Vector2(104,104),"brake")
	_analog(layer,Vector2(1120,560),Vector2(104,104),"gas")
	_touch(layer,Vector2(900,585),Vector2(72,72),"handbrake")
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
	_touch(layer,Vector2(164,100),Vector2(58,58),"horn")
	_touch(layer,Vector2(234,100),Vector2(58,58),"settings")
	if desktop_mode:
		for button in touch_buttons: button.visible=false
		for pedal in pedals.values(): pedal.visible=false
		shifter.visible=false
		_desktop_controls(layer)
	# Settings stays above all driving overlays when opened.
	layer.move_child(settings,layer.get_child_count()-1)

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

func _analog(parent: Node,pos: Vector2,size: Vector2,id: String) -> void:
	var pedal := Node2D.new()
	pedal.set_script(preload("res://scripts/ui/analog_pedal.gd"))
	pedal.kind=id
	pedal.extent=size
	pedal.position=pos
	parent.add_child(pedal)
	pedal.changed.connect(func(value: float): _pedal(id,value))
	pedals[id]=pedal

func _pedal(id: String,value: float) -> void:
	match id:
		"gas": car.gas=value
		"brake": car.pedal_brake=value
		"clutch": car.clutch_pedal=value

func _settings_visibility() -> void:
	car.controls_enabled=not settings.visible
	for pedal in pedals.values():
		pedal.enabled=not settings.visible
		if settings.visible: pedal.cancel()
	if settings.visible:
		held.clear()
		car.release_controls()
		shifter.cancel()

func _press(id: String, down: bool) -> void:
	if settings.visible and id!="settings": return
	held[id]=down
	car.horn=float(held.get("horn",false))
	if id in ["gas","brake","clutch"]: _pedal(id,float(down))
	car.turn=float(held.get("left",false))-float(held.get("right",false))
	if not down: return
	if id.begins_with("gear"): car.transmission.shift(int(id.trim_prefix("gear")),car.signed_speed)
	elif id.begins_with("auto"): car.transmission.select(id.trim_prefix("auto"),car.signed_speed,maxf(car.pedal_brake,float(Input.is_key_pressed(KEY_S))))
	elif id=="mode":
		car.transmission.toggle(car.signed_speed)
		settings.transmission_selector.select(car.transmission.mode)
	elif id=="handbrake": car.handbrake=1-car.handbrake
	elif id=="start": car.transmission.start_stop()
	elif id=="reset": car.reset()
	elif id=="camera": camera_mode=(camera_mode+1)%3
	elif id=="settings":
		settings.visible=not settings.visible
		held.clear()
		car.release_controls()
		shifter.cancel()
	elif id=="quality":
		settings.quality_toggle.button_pressed=not low_quality
	elif id=="regions": car.transmission.message="Playable: Colombo • Planned: Kandy hills / Galle coast / rural villages"

func _input(event: InputEvent) -> void:
	if settings.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		var t = car.transmission
		if event.keycode==KEY_M: t.toggle(car.signed_speed)
		elif event.keycode==KEY_C or event.keycode==KEY_V: camera_mode=(camera_mode+1)%3
		elif event.keycode==KEY_E: t.start_stop()
		elif event.keycode==KEY_SPACE: car.handbrake=1-car.handbrake
		elif event.keycode==KEY_ESCAPE: settings.visible=not settings.visible
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
	cockpit=camera_mode==1
	gauges.visible=camera_mode in [1,2]
	interior.visible=cockpit
	wheel.rotation.z=-car.steering*2.5
	if cockpit:
		camera.global_position=car.to_global(Vector3(-0.42,1.58,0.5))
		camera.look_at(camera.global_position+car.global_basis.z*10,car.global_basis.y)
		car.visual.visible=false
	elif camera_mode==2:
		car.visual.visible=true
		camera.global_position=car.to_global(Vector3(0,1.32,1.15))
		camera.look_at(camera.global_position+car.global_basis.z*20,car.global_basis.y)
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
	var lug := clampf((car.transmission.config.idle_rpm-t.rpm)/300,0,1) if t.running else 0.0
	camera.global_position+=car.global_basis.y*sin(t.engine.clock*70)*lug*0.012
	hud.text="%s · %d km/h · %d RPM · %s · %d FPS\nClutch %d%% · Load %d%% · %s\n%s" % [t.display(),roundi(car.linear_velocity.length()*3.6),roundi(t.rpm),t.engine.status(),Engine.get_frames_per_second(),roundi(t.clutch*100),roundi(absf(t.engine.load)*100),"HANDBRAKE" if car.handbrake>0 else ("LOW" if low_quality else "HIGH"),t.message]
	shifter.visible=t.mode==0 and not desktop_mode
	if t.mode!=0 and pedals.clutch.visible: pedals.clutch.cancel()
	pedals.clutch.visible=t.mode==0 and not desktop_mode
	settings.transmission_selector.select(t.mode)
	for button in touch_buttons:
		var id: String=button.get_meta("id")
		if id.begins_with("gear") or id=="clutch": button.visible=t.mode==0
		if id.begins_with("auto"): button.visible=t.mode==1
		if id in ["handbrake","start"]:
			button.get_child(0).active=car.handbrake>0 if id=="handbrake" else (t.running or t.engine.state==1)

func _apply_quality(low: bool) -> void:
	low_quality=low
	sun.shadow_enabled=not low
	Engine.max_fps=30 if low else 60
	camera.far=190 if low else 260
	get_world_3d().environment.fog_depth_end=185 if low else 255
	get_world_3d().environment.fog_depth_begin=130 if low else 185
	get_viewport().msaa_3d=Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(car):
		held.clear()
		if is_instance_valid(shifter): shifter.cancel()
		car.release_controls()
		for pedal in pedals.values(): pedal.cancel()
		get_tree().paused=true
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN: get_tree().paused=false


func _desktop_controls(layer: CanvasLayer) -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bar.position=Vector2(865,14)
	layer.add_child(bar)
	var transmission_button := Button.new()
	transmission_button.text="Manual / Automatic (M)"
	bar.add_child(transmission_button)
	transmission_button.pressed.connect(func():
		if car.transmission.toggle(car.signed_speed):
			settings._save("automatic",car.transmission.mode==1)
		settings.transmission_selector.select(car.transmission.mode))
	var settings_button := Button.new()
	settings_button.text="Settings (Esc)"
	bar.add_child(settings_button)
	settings_button.pressed.connect(func(): settings.visible=not settings.visible)
	desktop_help=Label.new()
	desktop_help.position=Vector2(18,682)
	desktop_help.add_theme_font_size_override("font_size",13)
	desktop_help.add_theme_color_override("font_color",Color(0.94,0.97,1))
	layer.add_child(desktop_help)

func _build_desktop_cockpit() -> void:
	if not desktop_mode: return
	var dark := G.material("",Color(0.045,0.052,0.065))
	var trim := G.material("",Color(0.23,0.26,0.29))
	var leather := G.material("",Color(0.08,0.085,0.09))
	# Camera-space interior: dashboard, windshield surround, door panels and center stack.
	G.box(interior,Vector3(0,-0.55,-1.05),Vector3(2.8,0.28,0.72),dark)
	G.box(interior,Vector3(0,-0.38,-1.24),Vector3(2.8,0.045,0.18),trim)
	G.box(interior,Vector3(-1.26,0.22,-1.05),Vector3(0.14,1.55,0.19),dark)
	G.box(interior,Vector3(1.26,0.22,-1.05),Vector3(0.14,1.55,0.19),dark)
	G.box(interior,Vector3(0,0.97,-1.06),Vector3(2.5,0.13,0.22),dark)
	G.box(interior,Vector3(-1.04,-0.61,-0.59),Vector3(0.52,0.46,0.68),leather)
	G.box(interior,Vector3(1.04,-0.61,-0.59),Vector3(0.52,0.46,0.68),leather)
	G.box(interior,Vector3(0.80,-0.52,-0.74),Vector3(0.55,0.39,0.11),trim)
	G.box(interior,Vector3(0.80,-0.52,-0.67),Vector3(0.47,0.31,0.025),dark)
	G.box(interior,Vector3(0,-0.32,-0.63),Vector3(0.27,0.22,0.10),leather)
	for x in [-0.31,0.31]:
		G.box(interior,Vector3(x,-0.34,-0.64),Vector3(0.31,0.055,0.06),trim)
	for x in [-0.88,0.88]:
		G.box(interior,Vector3(x,-0.42,-0.72),Vector3(0.36,0.10,0.09),trim)

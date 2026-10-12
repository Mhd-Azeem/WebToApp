extends Node3D
const G = preload("res://scripts/geometry.gd")
var car: VehicleBody3D
var camera: Camera3D
var hud: Label
var cockpit := false
var camera_mode := 1
var gauges: Node2D
var low_quality := true
var touch_buttons: Array[TouchScreenButton] = []
var sun: DirectionalLight3D
var held := {}
var interior: Node3D
var wheel: Node3D
var shifter: Node2D
var traffic: Node3D
var settings: PanelContainer
var rear_view: Node
var pedals := {}
var desktop_mode := false
var desktop_help: Label
var cockpit_overlay: Control
var headlamps: Array[SpotLight3D] = []
var wiper_parts: Array[Node3D] = []
var wipers_on := false
var wiper_phase := 0.0

func _ready() -> void:
	desktop_mode=OS.has_feature("windows") or OS.has_feature("linux") or OS.has_feature("macos")
	var world := Node3D.new()
	world.set_script(_world_script())
	add_child(world)
	car=VehicleBody3D.new()
	car.set_script(preload("res://scripts/car.gd"))
	add_child(car)
	for mesh in car.visual.find_children("*","GeometryInstance3D",true,false): mesh.layers=4
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
	interior.set_script(preload("res://scripts/cockpit.gd"))
	interior.vehicle=car
	interior.view_camera=camera
	camera.add_child(interior)
	wheel=interior.wheel
	interior.visible=false
	_hud()
	traffic.set_enabled(settings.traffic_toggle.button_pressed)
	_apply_quality(settings.quality_toggle.button_pressed)
	if settings.saved.get_value("driving","automatic",false): car.transmission.toggle(0)
	settings.transmission_selector.select(car.transmission.mode)

func _world_script() -> Script:
	return preload("res://scripts/world.gd")

func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	settings=PanelContainer.new()
	settings.set_script(preload("res://scripts/ui/driving_settings.gd"))
	layer.add_child(settings)
	settings.traffic_changed.connect(func(value: bool): traffic.set_enabled(value))
	settings.quality_changed.connect(_apply_quality)
	settings.visibility_changed.connect(_settings_visibility)
	settings.throttle_travel_changed.connect(func(value: float):
		if pedals.has("gas"): pedals.gas.travel=value)
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
	if id=="gas": pedal.travel=settings.throttle_travel
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
		interior.cancel()

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
	elif id=="regions": car.transmission.message="Playable: Colombo â€¢ Planned: Kandy hills / Galle coast / rural villages"

func _input(event: InputEvent) -> void:
	if settings.visible and not (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE): return
	if event is InputEventKey and event.keycode==KEY_H and not event.pressed: car.horn=0.0
	if event is InputEventKey and event.pressed and not event.echo:
		var t = car.transmission
		if event.keycode==KEY_M: t.toggle(car.signed_speed)
		elif event.keycode==KEY_Q: car.turn_signal=0 if car.turn_signal==-1 else -1
		elif event.keycode==KEY_Z: car.turn_signal=0 if car.turn_signal==1 else 1
		elif event.keycode==KEY_X: car.hazards=not car.hazards
		elif event.keycode==KEY_B: car.high_beams=not car.high_beams
		elif event.keycode==KEY_C or event.keycode==KEY_V: camera_mode=(camera_mode+1)%3
		elif event.keycode==KEY_E: t.start_stop()
		elif event.keycode==KEY_H: car.horn=1.0
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
	gauges.visible=camera_mode==2
	interior.visible=cockpit
	if cockpit:
		camera.global_position=car.to_global(Vector3(0.42,1.58,0.5))
		camera.look_at(camera.global_position+car.global_basis.z*10,car.global_basis.y)
		car.visual.visible=true
		camera.cull_mask=3
	elif camera_mode==2:
		camera.cull_mask=7
		car.visual.visible=true
		camera.global_position=car.to_global(Vector3(0,1.32,1.15))
		camera.look_at(camera.global_position+car.global_basis.z*20,car.global_basis.y)
	else:
		camera.cull_mask=7
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
	hud.text="%s Â· %d km/h Â· %d RPM Â· %s Â· %d FPS\nClutch %d%% Â· Load %d%% Â· %s\n%s" % [t.display(),roundi(car.linear_velocity.length()*3.6),roundi(t.rpm),t.engine.status(),Engine.get_frames_per_second(),roundi(t.clutch*100),roundi(absf(t.engine.load)*100),"HANDBRAKE" if car.handbrake>0 else ("LOW" if low_quality else "HIGH"),t.message]
	shifter.visible=t.mode==0 and not desktop_mode
	if is_instance_valid(cockpit_overlay): cockpit_overlay.visible=cockpit and not settings.visible
	if t.mode!=0 and pedals.clutch.visible: pedals.clutch.cancel()
	pedals.clutch.visible=t.mode==0 and not desktop_mode
	settings.transmission_selector.select(t.mode)
	for button in touch_buttons:
		var id: String=button.get_meta("id")
		if desktop_mode:
			button.visible=false
			continue
		if id.begins_with("gear") or id=="clutch": button.visible=t.mode==0
		if id.begins_with("auto"): button.visible=t.mode==1
		if id in ["handbrake","start"]:
			button.get_child(0).active=car.handbrake>0 if id=="handbrake" else (t.running or t.engine.state==1)

func _apply_quality(low: bool) -> void:
	low_quality=low
	if is_instance_valid(interior): interior.set_quality(low)
	sun.shadow_enabled=not low and settings.shadow_toggle.button_pressed
	Engine.max_fps=30 if low else 60
	camera.far=190 if low else 260
	get_world_3d().environment.fog_depth_end=185 if low else 255
	get_world_3d().environment.fog_depth_begin=130 if low else 185
	get_viewport().msaa_3d=Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(car):
		held.clear()
		if is_instance_valid(shifter): shifter.cancel()
		car.release_controls()
		for pedal in pedals.values(): pedal.cancel()
		get_tree().paused=true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]: get_tree().paused=false


func _desktop_controls(layer: CanvasLayer) -> void:
	var bar := HBoxContainer.new()
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


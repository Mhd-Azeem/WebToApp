extends Node3D
const G = preload("res://scripts/geometry.gd")
var landscape: Node3D
var car: VehicleBody3D
var camera: Camera3D
var hud: Label
var cockpit := false
var camera_mode := 1
var gauges: Node2D
const Graphics = preload("res://scripts/adaptive_graphics.gd")
var graphics := Graphics.new()
var performance_label: Label
var performance_elapsed := 1.0
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
var engine_audio: Node
var gameplay: Node
var steering_wheel: Node2D
var steering_selector: OptionButton
var steering_sensitivity: HSlider
var control_size: HSlider
var control_opacity: HSlider
var control_offset: HSlider
var tilt_calibration := 0.0
var rain: Control
var weather_selector: OptionButton
var day_cycle: CheckButton
var day_time := 0.25
var weather_elapsed := 0.0
var orbit_angle := 0.0
var orbit_finger := -1
var camera_initialized := false
var previous_camera_mode := -1
var on_foot: Node
var pedestrians: Node3D

func _ready() -> void:
	desktop_mode=OS.has_feature("windows") or OS.has_feature("linux") or OS.has_feature("macos")
	var world := Node3D.new()
	world.set_script(preload("res://scripts/world.gd"))
	add_child(world)
	car=VehicleBody3D.new()
	car.set_script(preload("res://scripts/car.gd"))
	add_child(car)
	for mesh in car.visual.find_children("*","GeometryInstance3D",true,false): mesh.layers=4
	car.reset()
	landscape = world.get_node("Landscape")
	landscape.player = car
	landscape.stream_at(car.position, true)
	traffic=Node3D.new()
	traffic.set_script(preload("res://scripts/traffic.gd"))
	traffic.player=car
	add_child(traffic)
	engine_audio = Node.new()
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
	_select_quality()
	if settings.saved.get_value("driving","automatic",false): car.transmission.toggle(0)
	settings.transmission_selector.select(car.transmission.mode)

func _hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	settings=PanelContainer.new()
	settings.set_script(preload("res://scripts/ui/driving_settings.gd"))
	layer.add_child(settings)
	steering_selector=settings.choice("Touch steering",["Arrows","Steering wheel","Tilt"],"steering_style",0)
	steering_selector.item_selected.connect(func(_index: int):
		car.turn=0
		steering_wheel.cancel()
		tilt_calibration=Input.get_gravity().x)
	steering_sensitivity=settings.slider("Steering sensitivity","steering_sensitivity",0.50,1.50,1.0)
	control_size=settings.slider("Touch control size","control_size",0.75,1.15,1.0)
	control_opacity=settings.slider("Touch control opacity","control_opacity",0.40,1.0,1.0)
	control_offset=settings.slider("Touch control vertical position","control_offset",-40.0,35.0,0.0)
	for slider in [control_size,control_opacity,control_offset]:
		slider.value_changed.connect(func(_value: float): _layout_controls())
	var abs_toggle: CheckButton=settings.toggle("ABS", "abs", false)
	var tcs_toggle: CheckButton=settings.toggle("Traction control", "tcs", false)
	var lsd_toggle: CheckButton=settings.toggle("Limited-slip differential", "lsd", false)
	var damage_toggle: CheckButton=settings.toggle("Vehicle damage", "damage", false)
	car.wheel_physics.abs_enabled=abs_toggle.button_pressed
	car.wheel_physics.traction_control=tcs_toggle.button_pressed
	car.wheel_physics.limited_slip=lsd_toggle.button_pressed
	car.damage_enabled=damage_toggle.button_pressed
	abs_toggle.toggled.connect(func(on: bool): car.wheel_physics.abs_enabled=on)
	tcs_toggle.toggled.connect(func(on: bool): car.wheel_physics.traction_control=on)
	lsd_toggle.toggled.connect(func(on: bool): car.wheel_physics.limited_slip=on)
	damage_toggle.toggled.connect(func(on: bool): car.damage_enabled=on)
	weather_selector=settings.choice("Weather",["Clear","Rain","Fog"],"weather",0)
	day_cycle=settings.toggle("Day / night cycle","day_cycle",false)
	day_cycle.toggled.connect(func(_on: bool):
		day_time=0.25
		_update_weather())
	weather_selector.item_selected.connect(func(_index: int): _update_weather())
	var engine_level: HSlider=settings.slider("Engine volume","engine_volume",0,1,1)
	var road_level: HSlider=settings.slider("Road and wind volume","road_volume",0,1,1)
	var effects_level: HSlider=settings.slider("Vehicle effects volume","effects_volume",0,1,1)
	var traffic_level: HSlider=settings.slider("Traffic volume","traffic_volume",0,1,0.65)
	engine_audio.engine_volume=engine_level.value
	engine_audio.road_volume=road_level.value
	engine_audio.effects_volume=effects_level.value
	traffic.sound_gain=traffic_level.value
	engine_level.value_changed.connect(func(value: float): engine_audio.engine_volume=value)
	road_level.value_changed.connect(func(value: float): engine_audio.road_volume=value)
	effects_level.value_changed.connect(func(value: float): engine_audio.effects_volume=value)
	traffic_level.value_changed.connect(func(value: float): traffic.sound_gain=value)
	rain=preload("res://scripts/ui/rain_overlay.gd").new()
	rain.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(rain)
	_update_weather()
	settings.traffic_changed.connect(func(value: bool): traffic.set_enabled(value))
	settings.quality_changed.connect(_select_quality)
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
	performance_label = Label.new()
	performance_label.position = Vector2(330, 86)
	performance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(performance_label)
	hud=Label.new()
	hud.position=Vector2(22,15)
	hud.size=Vector2(630,57)
	hud.clip_text=true
	hud.add_theme_font_size_override("font_size",14)
	layer.add_child(hud)
	steering_wheel=preload("res://scripts/ui/touch_wheel.gd").new()
	steering_wheel.position=Vector2(126,608)
	steering_wheel.set_meta("base_position",steering_wheel.position)
	steering_wheel.steered.connect(func(amount: float):
		if steering_selector.selected==1: car.turn=clampf(amount*steering_sensitivity.value,-1,1))
	layer.add_child(steering_wheel)
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
	shifter.set_meta("base_position",shifter.position)
	layer.add_child(shifter)
	for i in range(4):
		_touch(layer,Vector2(948+i*66,470),Vector2(58,64),"auto"+["P","R","N","D"][i])
	for i in range(4):
		_touch(layer,Vector2(1190,16+i*66),Vector2(60,60),["mode","camera","reset","start"][i])
	_touch(layer,Vector2(24,100),Vector2(58,58),"quality")
	_touch(layer,Vector2(94,100),Vector2(58,58),"regions")
	_touch(layer,Vector2(164,100),Vector2(58,58),"horn")
	_touch(layer,Vector2(234,100),Vector2(58,58),"settings")
	gameplay=preload("res://scripts/gameplay.gd").new()
	add_child(gameplay)
	gameplay.setup(layer,car)
	gameplay.panel.visibility_changed.connect(_settings_visibility)
	on_foot=preload("res://scripts/people/on_foot.gd").new()
	add_child(on_foot)
	on_foot.setup(layer,car,camera)
	var appearance: OptionButton=settings.choice("Playable character",["Man","Woman"],"person_model",0)
	on_foot.model_index=appearance.selected
	appearance.item_selected.connect(func(i: int):
		on_foot.model_index=i
		if on_foot.person.model.animations!=null: on_foot.person.model.dress(i))
	on_foot.mode_changed.connect(_mobility_changed)
	on_foot.interact_requested.connect(_walk_interact)
	pedestrians=preload("res://scripts/people/pedestrians.gd").new()
	add_child(pedestrians)
	pedestrians.setup(layer,car)
	pedestrians.panel.visibility_changed.connect(_settings_visibility)
	_layout_controls()
	get_viewport().size_changed.connect(_layout_controls)
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
	button.set_meta("base_position",pos)
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
	pedal.set_meta("base_position",pos)
	parent.add_child(pedal)
	pedal.changed.connect(func(value: float): _pedal(id,value))
	pedals[id]=pedal

func _pedal(id: String,value: float) -> void:
	match id:
		"gas": car.gas=value
		"brake": car.pedal_brake=value
		"clutch": car.clutch_pedal=value

func _settings_visibility() -> void:
	var available: bool = not settings.visible and not gameplay.panel.visible
	if is_instance_valid(pedestrians): available=available and not pedestrians.panel.visible
	if is_instance_valid(on_foot):
		on_foot.enabled=available
		if not available: on_foot.clear_input()
	car.controls_enabled=available and (not is_instance_valid(on_foot) or on_foot.driving())
	for pedal in pedals.values():
		pedal.enabled=car.controls_enabled
		if not car.controls_enabled: pedal.cancel()
	if not car.controls_enabled:
		held.clear()
		if is_instance_valid(steering_wheel): steering_wheel.cancel()
		car.release_controls()
		shifter.cancel()
		interior.cancel()

func _press(id: String, down: bool) -> void:
	if not car.controls_enabled and id not in ["settings","regions"]: return
	held[id]=down
	car.horn=float(held.get("horn",false))
	if id in ["gas","brake","clutch"]: _pedal(id,float(down))
	if steering_selector.selected==0:
		car.turn=(float(held.get("left",false))-float(held.get("right",false)))*steering_sensitivity.value
	if not down: return
	if id.begins_with("gear"): car.transmission.shift(int(id.trim_prefix("gear")),car.signed_speed)
	elif id.begins_with("auto"): car.transmission.select(id.trim_prefix("auto"),car.signed_speed,maxf(car.pedal_brake,float(Input.is_key_pressed(KEY_S))))
	elif id=="mode":
		car.transmission.toggle(car.signed_speed)
		settings.transmission_selector.select(car.transmission.mode)
	elif id=="handbrake": car.handbrake=1-car.handbrake
	elif id=="start" and not car.fuel_exhausted: car.transmission.start_stop()
	elif id=="reset": car.recover()
	elif id=="camera": camera_mode=(camera_mode+1)%4
	elif id=="settings":
		gameplay.panel.hide()
		settings.visible=not settings.visible
		held.clear()
		car.release_controls()
		shifter.cancel()
	elif id=="quality":
		var index: int = (settings.quality_selector.selected + 1) % Graphics.NAMES.size()
		settings.quality_selector.select(index)
		settings.quality_selector.item_selected.emit(index)
	elif id=="regions":
		settings.hide()
		gameplay.panel.visible=not gameplay.panel.visible

func _input(event: InputEvent) -> void:
	if not is_instance_valid(gameplay): return
	if is_instance_valid(pedestrians) and pedestrians.panel.visible:
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_G]: pedestrians.respond("Close")
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_TAB:
			_press("regions",true)
			get_viewport().set_input_as_handled()
			return
		if event.keycode==KEY_G and not settings.visible:
			_walk_interact()
			return
	if gameplay.panel.visible:
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: gameplay.panel.hide()
		return
	if settings.visible and not (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE): return
	if is_instance_valid(on_foot) and on_foot.input_event(event):
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(on_foot) and not on_foot.driving():
		if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: settings.show()
		return
	if camera_mode==3:
		if event is InputEventScreenTouch:
			if not event.pressed and orbit_finger==event.index: orbit_finger=-1
			elif event.pressed and Rect2(360,170,510,300).has_point(event.position): orbit_finger=event.index
		elif event is InputEventScreenDrag and event.index==orbit_finger:
			orbit_angle+=event.relative.x*0.008
		elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			orbit_angle+=event.relative.x*0.008
	if event is InputEventKey and event.keycode==KEY_H and not event.pressed: car.horn=0.0
	if event is InputEventKey and event.pressed and not event.echo:
		var t = car.transmission
		if event.keycode==KEY_M: t.toggle(car.signed_speed)
		elif event.keycode==KEY_Q: car.turn_signal=0 if car.turn_signal==-1 else -1
		elif event.keycode==KEY_Z: car.turn_signal=0 if car.turn_signal==1 else 1
		elif event.keycode==KEY_X: car.hazards=not car.hazards
		elif event.keycode==KEY_L: interior.set_headlights(not interior.headlights)
		elif event.keycode==KEY_B: car.high_beams=not car.high_beams
		elif event.keycode==KEY_V: camera_mode=(camera_mode+1)%4
		elif event.keycode==KEY_E and not car.fuel_exhausted: t.start_stop()
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
	steering_wheel.visible=not desktop_mode and steering_selector.selected==1 and on_foot.driving()
	steering_wheel.enabled=car.controls_enabled
	shifter.set_process_input(car.controls_enabled)
	if steering_selector.selected==2 and car.controls_enabled:
		var tilt := Input.get_gravity().x-tilt_calibration
		var target := 0.0 if absf(tilt)<0.25 else clampf(tilt*steering_sensitivity.value/4.2,-1,1)
		car.turn=lerpf(car.turn,target,1.0-exp(-delta*12.0))
	weather_elapsed+=delta
	if day_cycle.button_pressed:
		day_time=fposmod(day_time+delta/900.0,1.0)
		if weather_elapsed>0.25: _update_weather()
	var camera_changed := camera_mode!=previous_camera_mode
	previous_camera_mode=camera_mode
	var walking: bool=on_foot.walking
	cockpit=camera_mode==1 and not walking
	gauges.visible=camera_mode==2 and not walking
	interior.visible=cockpit
	if walking:
		camera_initialized=false
	elif cockpit:
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
		var desired := car.to_global(Vector3(0,4.1,-8.5).rotated(Vector3.UP,orbit_angle if camera_mode==3 else 0.0))
		var target := car.global_position+Vector3(0,1.2,0)
		if not camera_changed and camera_initialized:
			desired=camera.global_position.lerp(desired,1.0-exp(-delta*7.0))
		var query := PhysicsRayQueryParameters3D.create(target,desired)
		query.exclude=[car.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): desired=hit.position+(target-hit.position).normalized()*0.5
		camera.global_position=desired
		camera_initialized=true
		camera.look_at(target)
	var t = car.transmission
	var lug := clampf((car.transmission.config.idle_rpm-t.rpm)/300,0,1) if t.running else 0.0
	if not walking: camera.global_position+=car.global_basis.y*sin(t.engine.clock*70)*lug*0.012
	on_foot.update(delta,not desktop_mode)
	hud.visible=not walking
	if graphics.sample(delta): _apply_quality()
	performance_label.visible = settings.monitor_toggle.button_pressed
	performance_elapsed += delta
	if performance_label.visible and performance_elapsed >= 0.5:
		performance_elapsed = 0
		var fps := Engine.get_frames_per_second()
		performance_label.text = "%d FPS | %.1f ms | %d terrain chunks | %d draw calls" % [
			fps, 1000.0 / maxf(fps, 1), landscape.terrain_count,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	hud.text="%s · %d km/h · %d RPM · %s\nClutch %d%% · Load %d%% · %s\n%s" % [
		t.display(),roundi(car.linear_velocity.length()*3.6),roundi(t.rpm),t.engine.status(),
		roundi(t.clutch*100),roundi(absf(t.engine.load)*100),
		"HANDBRAKE" if car.handbrake>0 else Graphics.NAMES[graphics.tier],t.message]
	shifter.visible=t.mode==0 and not desktop_mode and on_foot.driving()
	if is_instance_valid(cockpit_overlay): cockpit_overlay.visible=cockpit and not settings.visible
	if t.mode!=0 and pedals.clutch.visible: pedals.clutch.cancel()
	pedals.clutch.visible=t.mode==0 and not desktop_mode and on_foot.driving()
	for pedal_name in ["gas","brake"]: pedals[pedal_name].visible=on_foot.driving() and not desktop_mode
	settings.transmission_selector.select(t.mode)
	for button in touch_buttons:
		var id: String=button.get_meta("id")
		if desktop_mode:
			button.visible=false
			continue
		button.visible=on_foot.driving() or id in ["settings","regions","quality"]
		if not on_foot.driving(): continue
		if id in ["left","right"]: button.visible=steering_selector.selected==0
		if id.begins_with("gear") or id=="clutch": button.visible=t.mode==0
		if id.begins_with("auto"): button.visible=t.mode==1
		if id in ["handbrake","start"]:
			button.get_child(0).active=car.handbrake>0 if id=="handbrake" else (t.running or t.engine.state==1)

func _select_quality() -> void:
	graphics.choose(settings.quality_selector.selected, 30 if settings.fps_selector.selected == 0 else 60)
	_apply_quality()

func _apply_quality() -> void:
	var tier := graphics.tier
	var low := tier <= Graphics.Preset.LOW
	if is_instance_valid(interior): interior.set_quality(low)
	sun.shadow_enabled = tier >= Graphics.Preset.MEDIUM and settings.shadow_toggle.button_pressed
	Engine.max_fps = graphics.target_fps if graphics.selected == Graphics.Preset.AUTO else (30 if low else 60)
	var distance: float = Graphics.DISTANCES[tier]
	camera.far = distance
	get_world_3d().environment.fog_depth_end = distance - 5
	get_world_3d().environment.fog_depth_begin = distance * 0.7
	var scale_limit := 0.75 if settings.render_scale_selector.selected == 0 else 1.0
	get_viewport().scaling_3d_scale = minf(Graphics.SCALES[tier], scale_limit)
	get_viewport().msaa_3d = Viewport.MSAA_2X if tier == Graphics.Preset.HIGH else Viewport.MSAA_DISABLED
	_update_weather()
	landscape.set_detail(distance + 35, Graphics.VEGETATION[tier])
	rear_view.set_quality(low)
	traffic.set_density(Graphics.TRAFFIC[tier])
	if is_instance_valid(pedestrians): pedestrians.graphics_tier=tier

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(car):
		held.clear()
		if is_instance_valid(shifter): shifter.cancel()
		car.release_controls()
		if is_instance_valid(steering_wheel): steering_wheel.cancel()
		orbit_finger=-1
		if is_instance_valid(on_foot): on_foot.clear_input()
		if is_instance_valid(gameplay): gameplay.save()
		for pedal in pedals.values(): pedal.cancel()
		get_tree().paused=true
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		graphics.reset_sample()
		get_tree().paused=false


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
	desktop_help.text="W/S pedals · A/D steering · C/Shift clutch · T walk/enter · V camera · Tab map & garage · G interact · L lights"
	desktop_help.add_theme_font_size_override("font_size",13)
	desktop_help.add_theme_color_override("font_color",Color(0.94,0.97,1))
	layer.add_child(desktop_help)


func _layout_controls() -> void:
	if not is_instance_valid(shifter) or not is_instance_valid(rain): return
	var margins := Vector2.ZERO
	if OS.has_feature("android"):
		var screen := DisplayServer.screen_get_size()
		var safe := DisplayServer.get_display_safe_area()
		if safe.has_area() and screen.x>0 and screen.y>0:
			var end := Vector2(screen-safe.end)
			margins=Vector2(maxi(safe.position.x,int(end.x)),maxi(safe.position.y,int(end.y))) / Vector2(screen) * Vector2(1280,720)
	var controls: Array[Node2D] = []
	controls.append_array(touch_buttons)
	controls.append_array(pedals.values())
	controls.append_array([shifter,steering_wheel])
	if is_instance_valid(on_foot):
		controls.append_array(on_foot.buttons)
		controls.append(on_foot.joystick)
	for control: Node2D in controls:
		var base: Vector2 = control.get_meta("base_position")
		var x := margins.x if base.x<640 else -margins.x
		var y := margins.y if base.y<360 else -margins.y
		var scale_value := 1.0
		if base.y>360:
			y+=control_offset.value
			scale_value=control_size.value
		control.position=base+Vector2(x,y)
		control.scale=Vector2.ONE*scale_value
		control.modulate.a=control_opacity.value

func _update_weather() -> void:
	weather_elapsed=0
	var weather := weather_selector.selected
	var night := clampf(sin(day_time*TAU)*0.8+0.2,0,1)
	if is_instance_valid(pedestrians):
		pedestrians.daylight=night
		pedestrians.raining=weather==1
	var env := get_world_3d().environment
	env.ambient_light_energy=lerpf(0.26,0.65,night)
	sun.light_energy=lerpf(0.10,1.1,night)*(0.70 if weather==1 else 1.0)
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color=Color(0.028,0.052,0.11).lerp(Color(0.26,0.48,0.70),night)
	sky.sky_horizon_color=Color(0.10,0.15,0.23).lerp(Color(0.78,0.83,0.83),night)
	sky.ground_horizon_color=sky.sky_horizon_color
	env.fog_light_color=Color(0.10,0.15,0.23).lerp(Color(0.48,0.58,0.62),night)
	var distance: float=Graphics.DISTANCES[graphics.tier]
	env.fog_depth_begin=distance*(0.25 if weather==2 else (0.52 if weather==1 else 0.70))
	env.fog_depth_end=distance*(0.63 if weather==2 else (0.85 if weather==1 else 0.98))
	rain.visible=weather==1
	rain.set_process(rain.visible)
	rain.drops=18 if graphics.tier<=Graphics.Preset.LOW else 38
	car.wheel_physics.wet_roads=weather==1

func _mobility_changed(walking: bool) -> void:
	landscape.player=on_foot.person if walking else car
	traffic.player=landscape.player
	if is_instance_valid(pedestrians): pedestrians.focus=landscape.player
	gameplay.walker=on_foot.person if walking else null
	rear_view.suspended=walking
	_settings_visibility()

func _walk_interact() -> void:
	if on_foot.walking and pedestrians.interact(): return
	gameplay.interact()

extends "res://scripts/main.gd"
## Alternate entry scene: all original cockpit, drivetrain and touch UI remain.
var akurana_world: Node3D
var below_terrain_time := 0.0
var town_traffic: Node3D

func _world_script() -> Script:
	return preload("res://scripts/akurana_world.gd")

func _settings_script() -> Script:
	return preload("res://scripts/ui/akurana_settings.gd")

func _ready() -> void:
	super._ready()
	akurana_world = get_child(0) as Node3D
	akurana_world.name = "AkuranaWorld"
	car.legacy_fall_recovery = false
	settings.graphics_changed.connect(_apply_graphics)
	_apply_graphics()
	for label in interior.find_children("*","Label3D",true,false):
		if label.text.contains("AZ CONNECT"): label.text=label.text.replace("COLOMBO","AKURANA")
	# The Colombo grid traffic generator does not follow Akurana GIS roads.
	traffic.set_enabled(false)
	_spawn_akurana()

func _apply_quality(_low: bool) -> void:
	# Base setup calls this before the Akurana world reference is initialized.
	if is_instance_valid(settings) and not settings.graphics.is_empty(): _apply_graphics()

func _apply_graphics() -> void:
	var quality: Dictionary=settings.graphics
	low_quality=int(quality.shadows)==0
	Engine.max_fps=int(quality.fps)
	get_viewport().scaling_3d_scale=float(quality.scale)
	var method:=RenderingServer.get_current_rendering_method()
	# Compatibility drivers can expose fewer samples than desktop Vulkan.
	get_viewport().msaa_3d=mini(int(quality.aa),Viewport.MSAA_4X) if method=="gl_compatibility" or OS.has_feature("android") else int(quality.aa)
	camera.far=float(quality.distance)+90.0
	sun.shadow_enabled=int(quality.shadows)>0
	sun.directional_shadow_max_distance=[40.,65.,100.,160.][int(quality.shadows)]
	var environment:=get_world_3d().environment
	environment.fog_depth_begin=float(quality.distance)*.65
	environment.fog_depth_end=float(quality.distance)
	environment.ambient_light_energy=.5
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled=method=="forward_plus" and int(quality.effects)>=1
	environment.ssr_enabled=method=="forward_plus" and int(quality.effects)>=2
	environment.volumetric_fog_enabled=method=="forward_plus" and int(quality.effects)>=2
	environment.volumetric_fog_density=.003
	interior.set_quality(int(quality.mirrors)==0)
	interior.mirror_update_hz=[10.,15.,20.,30.][int(quality.mirrors)]
	for vp in interior.mirrors:
		vp.size=[Vector2i(192,112),Vector2i(256,144),Vector2i(384,224),Vector2i(512,288)][int(quality.mirrors)]
	if is_instance_valid(akurana_world): akurana_world.apply_graphics(float(quality.distance),float(quality.vegetation),int(quality.textures))

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(akurana_world) or not is_instance_valid(camera) or not is_instance_valid(car):
		return
	# The base cockpit/chase cameras were tuned for flat Colombo. Akurana
	# slopes can intersect the virtual viewpoint and obscure roads entirely.
	var location := camera.global_position
	if camera_mode==1:
		# Right-hand driving position. The modeled dashboard stays in camera space.
		location=car.to_global(Vector3(-0.42,1.58,0.5))
	var ground: float = float(akurana_world.height_at(location.x,location.z))
	var floor_y: float = ground + (1.9 if camera_mode == 1 else 1.0)
	if camera_mode == 2:
		floor_y = ground + 1.6
	if location.y < floor_y:
		location.y = floor_y
		camera.global_position = location
	# Driver and hood views follow the chassis pitch/roll across hill slopes.
	# Do not flatten the camera using a world-horizontal forward/up vector.
	# Chase camera retains the parent scene's collision-aware look-at target.
	if camera_mode == 1 or camera_mode == 2:
		var forward: Vector3 = car.global_basis.z.normalized()
		var up: Vector3 = car.global_basis.y.normalized()
		camera.look_at(camera.global_position + forward * 25.0, up)
	camera.near = 0.08

func _physics_process(delta: float) -> void:
	if not is_instance_valid(car) or not is_instance_valid(akurana_world):
		return
	# Off-road driving is allowed. Never reset just because the body origin is
	# near/below local DEM height; suspension and road clearance vary on hills.
	# Recovery is reserved for a sustained true fall below terrain.
	var surface: float = float(akurana_world.height_at(car.global_position.x,car.global_position.z))
	if car.global_position.y < surface - 6.0:
		below_terrain_time += delta
		if below_terrain_time > 1.5:
			below_terrain_time = 0.0
			_spawn_akurana()
	else:
		below_terrain_time = 0.0

func _spawn_akurana() -> void:
	if not is_instance_valid(car) or not is_instance_valid(akurana_world):
		return
	var spawn: Dictionary = akurana_world.road_spawn_near(Vector2(-113.0, -25.0))
	if spawn.is_empty():
		push_error("Akurana spawn failed: no usable mapped road segments")
		return
	car.set("spawn_point", spawn["position"])
	car.reset()
	car.rotation = Vector3(0.0, float(spawn["yaw"]), 0.0)
	car.sleeping = false
	below_terrain_time = 0.0
	car.transmission.message = "Akurana: spawned on mapped road"

func _press(id: String, down: bool) -> void:
	if id=="quality" and down:
		if not settings.visible:
			var preset:=1 if low_quality else 0
			settings.selectors.preset.option.select(preset)
			settings.selectors.preset.option.item_selected.emit(preset)
		return
	super._press(id, down)
	if id == "reset" and down:
		_spawn_akurana()
	elif id == "regions" and down:
		car.transmission.message = "Akurana GIS preview - roads/terrain/buildings; Colombo available in original scene"

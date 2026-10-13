extends "res://scripts/main.gd"
## Alternate entry scene: all original cockpit, drivetrain and touch UI remain.
var akurana_world: Node3D
var below_terrain_time := 0.0

func _world_script() -> Script:
	return preload("res://scripts/akurana_world.gd")

func _ready() -> void:
	super._ready()
	akurana_world = get_child(0) as Node3D
	akurana_world.name = "AkuranaWorld"
	# The Colombo grid traffic generator does not follow Akurana GIS roads.
	traffic.set_enabled(false)
	_spawn_akurana()

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(akurana_world) or not is_instance_valid(camera) or not is_instance_valid(car):
		return
	# The base cockpit/chase cameras were tuned for flat Colombo. Akurana
	# slopes can intersect the virtual viewpoint and obscure roads entirely.
	var location := camera.global_position
	var ground: float = float(akurana_world.height_at(location.x,location.z))
	var floor_y: float = ground + (3.4 if camera_mode == 1 else 3.8)
	if camera_mode == 2:
		floor_y = ground + 2.6
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
	var spawn: Dictionary = akurana_world.road_spawn_near(Vector2(-113.0, 25.0))
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
	super._press(id, down)
	if id == "reset" and down:
		_spawn_akurana()
	elif id == "regions" and down:
		car.transmission.message = "Akurana GIS preview - roads/terrain/buildings; Colombo available in original scene"

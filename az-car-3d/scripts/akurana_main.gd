extends "res://scripts/main.gd"
## Alternate entry scene: all original cockpit, drivetrain and touch UI remain.
var akurana_world: Node3D

func _world_script() -> Script:
	return preload("res://scripts/akurana_world.gd")

func _ready() -> void:
	super._ready()
	akurana_world = get_child(0) as Node3D
	akurana_world.name = "AkuranaWorld"
	# The Colombo grid traffic generator does not follow Akurana GIS roads.
	traffic.set_enabled(false)
	_spawn_akurana()

func _physics_process(_delta: float) -> void:
	if is_instance_valid(car) and is_instance_valid(akurana_world):
		var surface := float(akurana_world.height_at(car.global_position.x, car.global_position.z))
		if car.global_position.y < surface - 4.0:
			_spawn_akurana()

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
	car.transmission.message = "Akurana: spawned on mapped road"

func _press(id: String, down: bool) -> void:
	super._press(id, down)
	if id == "reset" and down:
		_spawn_akurana()
	elif id == "regions" and down:
		car.transmission.message = "Akurana GIS preview - roads/terrain/buildings; Colombo available in original scene"

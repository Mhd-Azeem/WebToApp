extends "res://scripts/main.gd"
## Alternate entry scene: all original cockpit, drivetrain and touch UI remain.
var akurana_world: Node3D

func _ready() -> void:
	super._ready()
	var legacy_world := get_child(0)
	legacy_world.queue_free()
	akurana_world = Node3D.new()
	akurana_world.name = "AkuranaWorld"
	akurana_world.set_script(preload("res://scripts/akurana_world.gd"))
	add_child(akurana_world)
	move_child(akurana_world, 0)
	# The Colombo grid traffic generator does not follow Akurana GIS roads.
	traffic.set_enabled(false)
	_spawn_akurana()

func _spawn_akurana() -> void:
	if not is_instance_valid(car) or not is_instance_valid(akurana_world):
		return
	car.reset()
	car.position = Vector3(-113.0, akurana_world.height_at(-113.0, 25.0) + 1.6, 25.0)
	car.rotation = Vector3.ZERO
	car.sleeping = false

func _press(id: String, down: bool) -> void:
	super._press(id, down)
	if id == "reset" and down:
		_spawn_akurana()
	elif id == "regions" and down:
		car.transmission.message = "Akurana GIS preview - roads/terrain/buildings; Colombo available in original scene"

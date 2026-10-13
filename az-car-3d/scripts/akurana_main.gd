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

func _spawn_akurana() -> void:
	if not is_instance_valid(car) or not is_instance_valid(akurana_world):
		return
	var road_height := float(akurana_world.call("height_at", -113.0, 25.0))
	# First frame must already be directly over the visible A9 mesh.
	car.set("spawn_point", Vector3(-113.0, road_height + 0.95, 25.0))
	car.reset()
	car.rotation = Vector3.ZERO
	car.handbrake = 0.0
	# Immediate drive-away default on this Akurana preview. Manual mode,
	# clutch, ignition, and H-shifter remain selectable with M.
	if car.transmission.mode == 0:
		car.transmission.toggle(0.0)
	car.transmission.select("D", 0.0, 1.0)
	car.transmission.message = "Akurana A9: W / GAS to drive | M: manual | E: ignition"
	car.sleeping = false

func _press(id: String, down: bool) -> void:
	super._press(id, down)
	if id == "reset" and down:
		_spawn_akurana()
	elif id == "regions" and down:
		car.transmission.message = "Akurana GIS preview - roads/terrain/buildings; Colombo available in original scene"

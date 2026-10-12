extends SceneTree
## Non-destructive smoke checks for the Akurana alternate map.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var raw := FileAccess.get_file_as_string("res://data/akurana/preview.json")
	var data = JSON.parse_string(raw)
	if not data is Dictionary:
		push_error("Invalid Akurana geographic data")
		quit(1)
		return
	if data["roads"].size() < 20 or data["buildings"].size() < 20:
		push_error("Akurana map lacks roads or buildings")
		quit(1)
		return
	var scene = load("res://scenes/akurana.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var car = scene.get("car")
	var world = scene.get("akurana_world")
	if car == null or world == null:
		push_error("Akurana map or reusable driving car missing")
		quit(1)
		return
	var y := float(world.call("height_at", -113.0, 25.0))
	if y < 0.0 or y > 200.0 or car.position.distance_to(Vector3(-113.0, y + 1.6, 25.0)) > 15.0:
		push_error("Invalid terrain or car spawn")
		quit(1)
		return
	print("AKURANA PASS: geographic data, 3D scene and car spawn")
	quit(0)

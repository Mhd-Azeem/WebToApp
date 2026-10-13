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
	# At the starting road, the first ray hit must be pavement above terrain.
	var road_spawn: Dictionary = world.road_spawn_near(Vector2(-113.0,25.0))
	if road_spawn.is_empty():
		push_error("No usable Akurana road spawn")
		quit(1)
		return
	var road_pos: Vector3 = road_spawn["position"]
	var terrain_level: float = world.height_at(road_pos.x,road_pos.z)
	var ray := PhysicsRayQueryParameters3D.create(road_pos + Vector3(0,12,0),road_pos - Vector3(0,12,0))
	ray.exclude = [car.get_rid()]
	ray.collision_mask = 1
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or float(hit.position.y) < terrain_level + 0.30:
		push_error("Akurana mapped road is hidden below terrain at spawn")
		quit(1)
		return
	# Validate the actual gameplay camera against local GIS elevation.
	scene.camera_mode=1
	await process_frame
	var camera_pos: Vector3=scene.camera.global_position
	var camera_ground: float=world.height_at(camera_pos.x,camera_pos.z)
	if camera_pos.y < camera_ground+1.9:
		push_error("Akurana camera intersects terrain at start")
		quit(1)
		return
	if world.road_distance_at(car.global_position.x,car.global_position.z)>float(road_spawn["road_width"]):
		push_error("Akurana vehicle failed to spawn above visible mapped road")
		quit(1)
		return
	print("AKURANA PASS: geographic data, 3D scene and car spawn")
	quit(0)

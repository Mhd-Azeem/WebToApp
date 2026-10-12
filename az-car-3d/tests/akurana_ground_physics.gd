extends SceneTree
## Regression: verify actual PhysicsServer3D ground contact, not merely scene import.
func _initialize() -> void:
	call_deferred("_check_terrain")

func _fail(reason: String) -> void:
	push_error("AKURANA GROUND PHYSICS FAIL: " + reason)
	quit(1)

func _check_terrain() -> void:
	var scene = load("res://scenes/akurana.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var car: VehicleBody3D = scene.car
	var world: Node3D = scene.akurana_world
	if not is_instance_valid(car) or not is_instance_valid(world):
		_fail("scene did not initialize the car and terrain")
		return
	var ground_y := float(world.call("height_at", -113.0, 25.0))
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(-113.0, ground_y + 25.0, 25.0),
		Vector3(-113.0, ground_y - 25.0, 25.0)
	)
	query.exclude = [car.get_rid()]
	query.collision_mask = 1
	var hit := scene.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_fail("downward ray passed through both Akurana road and terrain")
		return
	if absf(float(hit.position.y) - ground_y) > 3.0:
		_fail("collider height differs from rendered terrain (hit %.2f, expected %.2f)" % [hit.position.y, ground_y])
		return
	# The car must settle under gravity with brakes applied; the old smoke
	# check only observed two frames, and missed the fall-through entirely.
	car.handbrake = 1.0
	for tick in range(180):
		await physics_frame
		var local_y := float(world.call("height_at", car.global_position.x, car.global_position.z))
		if car.global_position.y < local_y - 2.5:
			_fail("car penetrated the map at frame %d (car y=%.2f, ground y=%.2f)" % [tick, car.global_position.y, local_y])
			return
	var final_y := float(world.call("height_at", car.global_position.x, car.global_position.z))
	if car.global_position.y > final_y + 5.0:
		_fail("car did not settle on ground after 180 physics frames")
		return
	if car.position.y < 0.0:
		_fail("car fell below map and respawned unexpectedly")
		return
	print("AKURANA GROUND PHYSICS PASS: raycast hit %.2f, car settled at %.2f, surface %.2f" % [hit.position.y, car.global_position.y, final_y])
	quit(0)

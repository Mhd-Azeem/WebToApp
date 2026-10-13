extends SceneTree
## Regression: road surface must physically exist above terrain and car must drive.
func _initialize() -> void:
	call_deferred("_check")

func _fail(message: String) -> void:
	push_error("AKURANA VISIBLE ROAD FAIL: " + message)
	quit(1)

func _check() -> void:
	var scene = load("res://scenes/akurana.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var world: Node3D = scene.akurana_world
	var car: VehicleBody3D = scene.car
	if not world.has_node("AkuranaRoadSurface") or not world.has_node("AkuranaRoadCollision"):
		_fail("No road mesh or static road collider")
		return
	var asphalt: MeshInstance3D = world.get_node("AkuranaRoadSurface")
	if asphalt.mesh == null or not asphalt.visible or asphalt.mesh.get_surface_count() == 0:
		_fail("Road exists but is not a visible mesh")
		return
	var ground_y: float = float(world.call("height_at", -113.0, 25.0))
	var ray := PhysicsRayQueryParameters3D.create(
		Vector3(-113.0, ground_y + 12.0, 25.0),
		Vector3(-113.0, ground_y - 12.0, 25.0)
	)
	ray.exclude = [car.get_rid()]
	ray.collision_mask = 1
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit["collider"].name != "AkuranaRoadCollision":
		_fail("Spawn ray does not hit the road above green terrain")
		return
	if float(hit.position.y) - ground_y < 0.38:
		_fail("Road surface buried in terrain")
		return
	if car.transmission.mode != 1 or car.transmission.selector != "D":
		_fail("Default preview must start in automatic Drive")
		return
	if car.handbrake > 0.0:
		_fail("Handbrake must be released for drive-away preview")
		return
	for i in range(160):
		await physics_frame
	if not car.transmission.running:
		_fail("Engine stalled while waiting to drive")
		return
	var start: Vector3 = car.global_position
	car.gas = 1.0
	for i in range(240):
		await physics_frame
	car.gas = 0.0
	var distance: float = car.global_position.distance_to(start)
	if distance < 4.0 or car.global_position.z <= start.z + 1.0:
		_fail("Car failed drive-away test: displacement %.2fm, Z offset %.2fm" % [distance, car.global_position.z - start.z])
		return
	if not car.transmission.running:
		_fail("Engine stalled during automatic acceleration")
		return
	print("AKURANA ROADS DRIVE PASS: road above ground at %.2fm, powered displacement %.2fm" % [hit.position.y - ground_y, distance])
	quit(0)

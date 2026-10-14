extends SceneTree
## Regression: traffic must be enabled and physically present near game spawn.
func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var scene = load("res://scenes/akurana.tscn").instantiate()
	root.add_child(scene)
	for frame in range(3): await process_frame
	if not is_instance_valid(scene.town_traffic):
		push_error("Akurana traffic system missing")
		quit(1)
		return
	if scene.settings.traffic_toggle.disabled or not scene.settings.traffic_toggle.button_pressed:
		push_error("Akurana traffic is disabled by default")
		quit(1)
		return
	var ai = scene.town_traffic
	if not ai.enabled or ai.actors.size() < 4:
		push_error("Akurana generated fewer than four traffic vehicles")
		quit(1)
		return
	# Visual meshes alone are insufficient: every AI car must be a
	# physics body with a solid 3D hitbox the player's car can collide with.
	for actor in ai.actors:
		if not actor is AnimatableBody3D or actor.collision_layer & 2 == 0:
			push_error("Akurana traffic vehicle has no physical collision body")
			quit(1)
			return
		var found_shape:=false
		for child in actor.get_children():
			if child is CollisionShape3D and child.shape is BoxShape3D:
				found_shape=true
		if not found_shape:
			push_error("Akurana traffic vehicle missing collision shape")
			quit(1)
			return
	var nearby := 0
	for actor in ai.actors:
		if actor.global_position.distance_to(scene.car.global_position) < 280.0: nearby += 1
	if nearby < 2:
		push_error("Akurana vehicles are not visible near the player's start: %d within 280m" % nearby)
		quit(1)
		return
	if ai.walkers.is_empty():
		push_error("Akurana pedestrians missing")
		quit(1)
		return
	print("AKURANA TRAFFIC PASS: %d vehicles, %d near start, %d pedestrians" % [ai.actors.size(),nearby,ai.walkers.size()])
	quit(0)

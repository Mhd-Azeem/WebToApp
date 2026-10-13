extends SceneTree
## Requires active renderer; dummy RenderingServer cannot inspect MultiMesh data.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Instance acceptance requires active renderer")
		quit(1)
		return
	var scene=load("res://scenes/akurana.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await RenderingServer.frame_post_draw
	var checked:=0
	for node in scene.akurana_world.vegetation:
		var transform: Transform3D=node.multimesh.get_instance_transform(0)
		var world_position: Vector3=(node.global_transform*transform).origin
		if world_position.length()<1 or node.multimesh.get_aabb().size.length()<.01 or node.multimesh.buffer.size()!=node.multimesh.instance_count*12:
			push_error("Lost baked vegetation instance transforms")
			quit(1)
			return
		checked+=1
	for preset in range(4):
		scene.settings.graphics=scene.settings.PRESETS[preset].duplicate()
		scene._apply_graphics()
		await process_frame
		await RenderingServer.frame_post_draw
	print("AKURANA INSTANCES PASS: ",checked," rendered batches")
	quit(0)

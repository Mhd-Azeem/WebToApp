extends SceneTree
func _initialize() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/visual")
	var scene=load("res://scenes/akurana.tscn").instantiate()
	root.add_child(scene)
	scene.process_mode=Node.PROCESS_MODE_ALWAYS
	paused=false
	scene.car.controls_enabled=false
	scene.car.release_controls()
	scene.car.handbrake=1
	for i in range(100): await process_frame
	for mode in [0,1,2]:
		scene.camera_mode=mode
		for i in range(20):
			paused=false
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/visual/camera-%d.png" % mode)
	scene.settings.show()
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/visual/settings.png")
	scene.settings.hide()
	scene.set_process(false)
	scene.car.freeze=true
	scene.interior.hide()
	scene.gauges.hide()
	var views: Array=[Vector3(-100,55,-20),Vector3(100,80,-340),Vector3(-340,110,450)]
	for i in range(views.size()):
		var p: Vector3=views[i]
		p.y=scene.akurana_world.height_at(p.x,p.z)+30
		scene.camera.global_position=p
		scene.camera.look_at(p+Vector3(60,-20,90))
		for frame in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/visual/neighborhood-%d.png" % i)
	quit()

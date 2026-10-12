extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in range(120): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/chase.png")
	scene.camera_mode=1
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/cockpit.png")
	scene.camera_mode=2
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/hood.png")
	scene.car.transmission.gear=-1
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/reverse.png")
	scene._press("settings",true)
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/settings.png")
	scene.settings.hide()
	scene.camera_mode=0
	scene.car.reset()
	scene.car.freeze=true
	scene.traffic.set_enabled(true)
	scene.traffic.set_physics_process(false)
	for i in range(3):
		scene.traffic.vehicles[i].position=Vector3(-3.5 if i<2 else 3.5,0,108-i*9)
		scene.traffic.vehicles[i].rotation.y=PI if i<2 else 0
	for i in range(90): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/colored-coupes.png")
	scene.set_process(false)
	scene.gauges.visible=false
	scene.rear_view.display.visible=false
	scene.camera.global_position=Vector3(-105,13,520)
	scene.camera.look_at(Vector3(90,1,390))
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/landscape.png")
	quit()

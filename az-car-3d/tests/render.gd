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
	quit()

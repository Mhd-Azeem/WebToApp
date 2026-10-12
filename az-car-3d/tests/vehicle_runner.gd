extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var tests := preload("res://tests/vehicle_scenarios.gd").new()
	var result: int=await tests.run(scene)
	scene.queue_free()
	await process_frame
	quit(1 if result>0 else 0)

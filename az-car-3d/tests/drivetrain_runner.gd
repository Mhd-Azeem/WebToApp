extends SceneTree
const Tests = preload("res://tests/drivetrain_checks.gd")
func _initialize() -> void:
	var tests := Tests.new()
	quit(1 if tests.run()>0 else 0)

extends Node2D
signal changed(value: float)
var kind := "gas"
var extent := Vector2(104,104)
var value := 0.0
var finger := -1
var start_y := 0.0
var symbol: Node2D
var travel := 96.0
var enabled := true
func _ready() -> void:
	symbol=Node2D.new()
	symbol.set_script(preload("res://scripts/ui/control_symbol.gd"))
	symbol.kind=kind
	symbol.extent=extent
	add_child(symbol)
func _set_value(amount: float) -> void:
	value=clampf(amount,0,1)
	symbol.active=value>0
	changed.emit(value)
	queue_redraw()
func begin(point: Vector2,index: int) -> bool:
	if finger!=-1 or not enabled or not visible or not Rect2(Vector2.ZERO,extent).has_point(point): return false
	finger=index
	start_y=point.y
	_set_value(0.25 if kind=="gas" else 1.0)
	return true
func drag_to(point: Vector2) -> void:
	_set_value(clampf(0.25+(start_y-point.y)/maxf(travel,1.0)*0.75,0.25,1.0) if kind=="gas" else 1-(point.y-start_y)/maxf(travel,1.0))
func cancel() -> void:
	finger=-1
	_set_value(0)
func _input(event: InputEvent) -> void:
	if not visible or not enabled: return
	var inverse := get_global_transform_with_canvas().affine_inverse()
	if event is InputEventScreenTouch:
		if event.pressed:
			if begin(inverse*event.position,event.index): get_viewport().set_input_as_handled()
		elif event.index==finger:
			cancel()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==finger:
		drag_to(inverse*event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed: begin(inverse*event.position,-2)
		elif finger==-2: cancel()
	elif event is InputEventMouseMotion and finger==-2: drag_to(inverse*event.position)
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(symbol): cancel()
func _draw() -> void:
	if finger==-1: return
	draw_arc(extent*0.5,extent.x*0.46,-PI/2,-PI/2+TAU*value,32,Color(0.30,0.9,0.6),4,true)
	draw_string(ThemeDB.fallback_font,Vector2(extent.x*0.5-18,extent.y+14),str(roundi(value*100))+"%",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)

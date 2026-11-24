extends Node2D

signal steered(amount: float)
const RADIUS := 55.0
var finger := -1
var steering := 0.0
var enabled := false
var start_angle := 0.0

func _input(event: InputEvent) -> void:
	if not enabled or not visible: return
	if event is InputEventScreenTouch and event.pressed and finger<0:
		var point := make_input_local(event) as InputEventScreenTouch
		if point.position.length()>RADIUS*1.1: return
		finger=event.index
		start_angle=point.position.angle()
	elif event is InputEventScreenTouch and event.index==finger and not event.pressed:
		cancel()
	elif event is InputEventScreenDrag and event.index==finger:
		var point := make_input_local(event) as InputEventScreenDrag
		steering=clampf(-angle_difference(start_angle,point.position.angle())/1.3,-1,1)
		steered.emit(steering)
	else:
		return
	queue_redraw()
	get_viewport().set_input_as_handled()

func cancel() -> void:
	finger=-1
	steering=0
	steered.emit(0)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO,RADIUS,Color(0.025,0.06,0.085,0.82))
	draw_arc(Vector2.ZERO,RADIUS-4,0,TAU,40,Color(0.78,0.87,0.90),7,true)
	for i in range(3):
		var angle := PI*0.5+i*TAU/3.0-steering*1.3
		draw_line(Vector2.ZERO,Vector2.from_angle(angle)*(RADIUS-8),Color(0.58,0.71,0.76),4,true)
	draw_circle(Vector2.ZERO,12,Color(0.88,0.95,0.96))

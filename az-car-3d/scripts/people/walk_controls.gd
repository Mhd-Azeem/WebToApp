extends Node2D

var stick := Vector2.ZERO
var finger := -1
var radius := 57.0
var enabled := false

func clear() -> void:
	finger=-1
	stick=Vector2.ZERO
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not enabled or not visible: return
	if event is InputEventScreenTouch:
		if event.pressed and finger<0 and to_local(event.position).length()<=radius*1.35:
			finger=event.index
		elif not event.pressed and event.index==finger:
			clear()
			get_viewport().set_input_as_handled()
			return
	if finger>=0 and (event is InputEventScreenDrag or event is InputEventScreenTouch) and event.index==finger:
		stick=(to_local(event.position)/radius).limit_length()
		queue_redraw()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_circle(Vector2.ZERO,radius,Color(0.07,0.12,0.16,0.56))
	draw_arc(Vector2.ZERO,radius,0,TAU,32,Color(0.88,0.93,0.98,0.66),2.0,true)
	draw_circle(stick*radius*0.72,22,Color(0.86,0.92,0.97,0.72))

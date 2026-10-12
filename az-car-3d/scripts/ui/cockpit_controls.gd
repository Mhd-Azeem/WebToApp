extends Control
## Cockpit interaction overlay: draggable light/wiper stalks and steering horn.
signal headlights_changed(enabled: bool)
signal wipers_changed(enabled: bool)
signal horn_changed(pressed: bool)
var headlights := false
var wipers := false
var horn_held := false
var dragging := ""
var left_rect := Rect2()
var right_rect := Rect2()
var horn_rect := Rect2()
var wheel_center := Vector2.ZERO
var steering := 0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	wheel_center=Vector2(w*0.60,h*0.65)
	left_rect=Rect2(w*0.38,h*0.55,92,128)
	right_rect=Rect2(w*0.79,h*0.55,92,128)
	horn_rect=Rect2(wheel_center-Vector2(68,65),Vector2(136,130))
	_draw_stalk(left_rect,"LIGHTS",headlights)
	_draw_stalk(right_rect,"WIPERS",wipers)
	# Invisible horn hit target is aligned to the wheel center.
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(18,h-18),"Drag stalks UP / DOWN • Tap steering center for horn",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(0.94,0.95,0.98))

func _draw_stalk(rect: Rect2,title: String,active: bool) -> void:
	draw_rect(rect,Color(0.02,0.04,0.06,0.72),true)
	draw_rect(rect,Color(0.35,0.43,0.48),false,2.0)
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(8,24),title,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
	draw_line(rect.position+Vector2(46,40),rect.position+Vector2(46,105),Color(0.4,0.44,0.47),5)
	var knob := rect.position+Vector2(46,50 if active else 96)
	draw_circle(knob,13,Color(0.20,0.83,0.48) if active else Color(0.86,0.38,0.28))
	draw_string(ThemeDB.fallback_font,rect.position+Vector2(8,122),"ON" if active else "OFF",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(event.position)
		else:
			_end()
		if dragging!="": get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging!="":
		_drag(event.position)
		if dragging!="": get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed: _begin(event.position)
		else: _end()
		if dragging!="": get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and dragging!="":
		_drag(event.position)
		if dragging!="": get_viewport().set_input_as_handled()

func _begin(pos: Vector2) -> void:
	if left_rect.has_point(pos): dragging="lights"; _drag(pos)
	elif right_rect.has_point(pos): dragging="wipers"; _drag(pos)
	elif horn_rect.has_point(pos):
		dragging="horn"
		horn_held=true
		horn_changed.emit(true)


func _drag(pos: Vector2) -> void:
	if dragging=="lights":
		var state := pos.y < left_rect.position.y+left_rect.size.y*0.55
		if state!=headlights:
			headlights=state
			headlights_changed.emit(state)
	elif dragging=="wipers":
		var state := pos.y < right_rect.position.y+right_rect.size.y*0.55
		if state!=wipers:
			wipers=state
			wipers_changed.emit(state)

func _end() -> void:
	if horn_held:
		horn_held=false
		horn_changed.emit(false)
	dragging=""

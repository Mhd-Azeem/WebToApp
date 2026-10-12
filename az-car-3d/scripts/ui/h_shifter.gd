extends Node2D
# Reference layout: 1 3 5 / 2 4 R, with a neutral cross-gate.
# The reference stock illustration is not bundled; this is original drawn UI.
const X := [-52.0,0.0,52.0]
const LEG := 44.0
const KNOB_RADIUS := 18.0
var vehicle: VehicleBody3D
var knob := Vector2.ZERO
var finger := -1
var mouse_drag := false
var blocked_until := 0
var last_gear := 0

func gear_position(gear: int) -> Vector2:
	match gear:
		1: return Vector2(X[0],-LEG)
		2: return Vector2(X[0],LEG)
		3: return Vector2(X[1],-LEG)
		4: return Vector2(X[1],LEG)
		5: return Vector2(X[2],-LEG)
		-1: return Vector2(X[2],LEG)
	return Vector2.ZERO

func gate_gear(pos: Vector2) -> int:
	if absf(pos.y)<LEG*0.78: return 0
	var column := 0
	for i in range(3):
		if absf(pos.x-X[i])<absf(pos.x-X[column]): column=i
	return [1,3,5][column] if pos.y<0 else [2,4,-1][column]

func _manual_ready() -> bool:
	return is_instance_valid(vehicle) and vehicle.controls_enabled and vehicle.transmission.mode==0 and vehicle.transmission.clutch>=0.85

func begin(point: Vector2, index: int) -> bool:
	if finger!=-1 or point.distance_to(knob)>KNOB_RADIUS+16: return false
	if not _manual_ready():
		if is_instance_valid(vehicle): vehicle.transmission.reject_shift("Hold the clutch before dragging the gear lever")
		blocked_until=Time.get_ticks_msec()+600
		queue_redraw()
		return false
	blocked_until=0
	finger=index
	last_gear=vehicle.transmission.gear
	return true

func drag_to(point: Vector2) -> void:
	if finger==-1: return
	if not _manual_ready():
		cancel()
		return
	var destination := Vector2(clampf(point.x,X[0],X[2]),clampf(point.y,-LEG,LEG))
	var next := Vector2.ZERO
	# A lever inside a vertical slot cannot hop sideways into another slot.
	if absf(knob.y)>10:
		if signf(destination.y)==signf(knob.y) and absf(destination.y)>10:
			next=Vector2(knob.x,destination.y)
		else:
			next=Vector2(destination.x,0)
	else:
		next=Vector2(destination.x,0)
		for column in X:
			if absf(destination.x-column)<17:
				next=Vector2(column,destination.y)
				break
	var requested := gate_gear(next)
	if requested!=vehicle.transmission.gear:
		if not vehicle.transmission.shift(requested,vehicle.signed_speed):
			blocked_until=Time.get_ticks_msec()+600
			knob=gear_position(vehicle.transmission.gear)
			queue_redraw()
			return
	knob=next
	last_gear=vehicle.transmission.gear
	queue_redraw()

func finish() -> void:
	finger=-1
	mouse_drag=false
	if is_instance_valid(vehicle): knob=gear_position(vehicle.transmission.gear)
	queue_redraw()

func cancel() -> void:
	finish()

func _input(event: InputEvent) -> void:
	if not visible or not is_instance_valid(vehicle) or vehicle.transmission.mode!=0: return
	var inverse := get_global_transform_with_canvas().affine_inverse()
	if event is InputEventScreenTouch:
		var point: Vector2=inverse*event.position
		if event.pressed:
			if begin(point,event.index): get_viewport().set_input_as_handled()
		elif event.index==finger:
			finish()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==finger:
		drag_to(inverse*event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_drag=begin(inverse*event.position,-2)
		elif mouse_drag: finish()
	elif event is InputEventMouseMotion and mouse_drag: drag_to(inverse*event.position)

func _process(_delta: float) -> void:
	if not is_instance_valid(vehicle): return
	if finger!=-1 and not _manual_ready(): cancel()
	if finger==-1 and last_gear!=vehicle.transmission.gear:
		knob=gear_position(vehicle.transmission.gear)
		last_gear=vehicle.transmission.gear
	queue_redraw()

func _draw() -> void:
	# Fixed compact round base above the brake; only its small lever knob moves.
	draw_circle(Vector2.ZERO,98,Color(0.025,0.05,0.075,0.90))
	draw_arc(Vector2.ZERO,97,0,TAU,64,Color(0.43,0.56,0.64),2,true)
	draw_circle(Vector2.ZERO,87,Color(0.15,0.20,0.24,0.86))
	var track := Color(0.035,0.055,0.07)
	draw_line(Vector2(X[0],0),Vector2(X[2],0),track,12,true)
	for column in X: draw_line(Vector2(column,-LEG),Vector2(column,LEG),track,12,true)
	var font := ThemeDB.fallback_font
	for column in range(3):
		var top: String=["1","3","5"][column]
		var bottom: String=["2","4","R"][column]
		draw_string(font,Vector2(X[column]-7,-60),top,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(0.92,0.94,0.95))
		draw_string(font,Vector2(X[column]-7,78),bottom,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(0.92,0.94,0.95))
	draw_string(font,Vector2(66,7),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(0.63,0.70,0.76))
	var rejected := Time.get_ticks_msec()<blocked_until
	draw_circle(knob+Vector2(2,3),KNOB_RADIUS+2,Color(0,0,0,0.5))
	draw_circle(knob,KNOB_RADIUS,Color(0.89,0.36,0.26) if rejected else Color(0.75,0.85,0.91))
	draw_arc(knob,KNOB_RADIUS,0,TAU,32,Color(0.91,0.96,1),2,true)
	draw_circle(knob-Vector2(5,5),4,Color(0.97,0.99,1,0.75))

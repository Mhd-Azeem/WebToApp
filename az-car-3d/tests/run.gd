extends SceneTree
const T = preload("res://scripts/transmission.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	var t := T.new()
	check(not t.shift(1,0),"Shift without clutch must fail")
	t.clutch=1
	for gear in range(1,6): check(t.shift(gear,0),"Forward gear must engage")
	check(not t.shift(-1,2),"Reverse while moving rejected")
	check(t.shift(-1,0),"Reverse at rest allowed")
	check(t.ratio(0)<0,"Reverse force negative")
	check(not t.shift(6,0),"Invalid gear rejected")
	t.shift(0,0)
	check(is_zero_approx(t.update(0.1,0,1)),"Neutral has no drive")
	t.toggle(0)
	check(not t.select("D",0,0),"Automatic selection requires brake")
	check(t.select("D",0,1),"D allowed at rest with brake")
	check(t.update(0.1,0,1)>0,"D drives forward")
	check(not t.select("R",5,1),"Moving direction change blocked")
	check(t.select("R",0,1),"R allowed stopped")
	check(t.update(0.1,0,1)<0,"R drives backward")
	t.select("P",0,1)
	check(is_zero_approx(t.update(0.1,0,1)),"P has no drive")
	check(not t.select("P",2,1),"Moving park rejected")
	t.toggle(0)
	t.clutch=1
	t.shift(1,0)
	check(is_zero_approx(t.update(0.1,0,1)),"Fully pressed clutch disconnects engine")
	t.clutch=0
	t.rpm=850
	for i in range(120): t.update(1.0/60.0,0,0)
	check(not t.running,"Manual release at idle can stall")
	t.clutch=1
	t.restart()
	check(t.running,"Clutch permits engine restart")
	print("Transmission checks: ","PASS" if failures==0 else "FAIL")
	call_deferred("world_test")
func world_test() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	check(scene.car.wheels.size()==4,"Four physics wheels")
	check(scene.car.global_position.x<0,"Car facing -Z starts on driver-left lane (-X)")
	check(scene.shifter.position.y<560 and scene.shifter.position.x>990,"Shifter fixed above brake")
	check(not scene.shifter.begin(Vector2.ZERO,4),"H shifter requires clutch")
	# Native multitouch: three pedals/steering held independently.
	for pos in [Vector2(1170,610),Vector2(70,600),Vector2(127,490)]:
		var touch := InputEventScreenTouch.new()
		touch.index=2 if pos.y<550 else (1 if pos.x<200 else 3)
		touch.position=pos
		touch.pressed=true
		root.push_input(touch,true)
	await process_frame
	check(scene.car.gas==1 and scene.car.turn==1 and scene.car.clutch_pedal==1,"Simultaneous native touches")
	var release := InputEventScreenTouch.new()
	release.index=1
	release.position=Vector2(70,600)
	release.pressed=false
	root.push_input(release,true)
	await process_frame
	check(scene.car.turn==0 and scene.car.gas==1,"Releasing steer keeps gas held")
	# Keep gas and clutch held while a fourth independent finger moves the lever.
	for i in range(24): await physics_frame
	var h = scene.shifter
	var gear_touch := InputEventScreenTouch.new()
	gear_touch.index=4
	gear_touch.pressed=true
	gear_touch.position=h.position
	root.push_input(gear_touch,true)
	check(h.finger==4,"H lever owns its touch independently")
	var drag := InputEventScreenDrag.new()
	drag.index=4
	drag.position=h.position+Vector2(-52,-44)
	root.push_input(drag,true)
	check(scene.car.transmission.gear==1,"Dragging left-up engages first")
	check(scene.car.gas==1 and scene.car.clutch_pedal==1,"Pedals remain held while shifting")
	# Sideways hopping across occupied vertical slots is impossible.
	h.drag_to(Vector2(52,-44))
	check(scene.car.transmission.gear==1 and h.knob.x==-52,"Must leave vertical slot through neutral")
	for gear in [2,3,4,5,-1]:
		h.drag_to(Vector2(h.knob.x,0))
		check(scene.car.transmission.gear==0,"Cross gate disconnects drive")
		h.drag_to(h.gear_position(gear))
		check(scene.car.transmission.gear==gear,"Reference H pattern gear "+str(gear))
	h.drag_to(Vector2(52,0))
	scene.car.signed_speed=3
	h.drag_to(Vector2(52,44))
	check(scene.car.transmission.gear==0,"Moving reverse rejected by draggable lever")
	scene.car.signed_speed=0
	gear_touch.pressed=false
	root.push_input(gear_touch,true)
	check(h.finger==-1 and h.knob==Vector2.ZERO,"Release snaps to actual neutral")
	print("H-pattern / multitouch checks: ","PASS" if failures==0 else "FAIL")
	for index in [2,3]:
		release=InputEventScreenTouch.new()
		release.index=index
		release.pressed=false
		root.push_input(release,true)
	scene.car.release_controls()
	scene.car.reset()
	scene.held.clear()
	# Let suspension settle, then accelerate in automatic D.
	for i in range(180): await physics_frame
	scene.car.transmission.toggle(0)
	scene.car.transmission.select("D",0,1)
	scene.car.gas=1
	var start: Vector3=scene.car.position
	for i in range(240): await physics_frame
	check(scene.car.position.distance_to(start)>5,"Car must travel under engine power")
	check(scene.car.position.z<start.z,"Southbound D must travel toward negative Z")
	check(scene.car.position.y>-1,"Road collision supports car")
	print("Powered vehicle displacement: ",scene.car.position.distance_to(start),"m")
	# Solid obstacle directly ahead; car must not pass through it.
	scene.car.reset()
	for i in range(120): await physics_frame
	var g = load("res://scripts/geometry.gd")
	g.box(scene,Vector3(-3.5,1,110),Vector3(8,2,1),g.material("concrete"),true)
	scene.car.transmission.toggle(0)
	scene.car.transmission.select("D",0,1)
	scene.car.gas=1
	for i in range(240): await physics_frame
	check(scene.car.position.z>109,"Physical barrier blocks vehicle")
	print("Scene / vehicle checks: ","PASS" if failures==0 else "FAIL")
	quit(1 if failures else 0)

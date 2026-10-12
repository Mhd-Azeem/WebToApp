extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.desktop_mode=false
	scene.settings.hide()
	scene.camera_mode=1
	for i in range(4): await process_frame
	var c = scene.interior
	check(c.wheel.get_child_count()>=5,"Wheel is a complete assembly")
	check(scene.car.to_local(scene.camera.global_position).x>0,"Left-hand driver in +Z vehicle coordinates")
	var pos: Vector2=scene.camera.unproject_position(c.horn_target.global_position)
	check(c.begin(pos,7) and scene.car.horn==1,"Projected horn press")
	var unrelated := InputEventScreenTouch.new()
	unrelated.index=8
	unrelated.pressed=false
	root.push_input(unrelated,true)
	check(c.owner_finger==7 and scene.car.horn==1,"Unrelated finger cannot release horn")
	c.cancel()
	check(scene.car.horn==0,"Horn release")
	pos=scene.camera.unproject_position(c.light_stalk.to_global(Vector3(-0.18,0,0)))
	check(c.begin(pos,3) and c.headlights,"Physical light stalk toggles")
	for lamp in c.lamps: check(lamp.visible,"Real headlamp follows stalk")
	c.cancel()
	pos=scene.camera.unproject_position(c.wiper_stalk.to_global(Vector3(0.18,0,0)))
	for mode in [1,2,3,0]:
		check(c.begin(pos,4) and c.wiper_mode==mode,"Four wiper modes")
		c.cancel()
	c.wiper_mode=3
	c._process(0.25)
	check(c.sweep>0,"Wipers sweep")
	c.wiper_mode=0
	for i in range(200): c._process(0.01)
	check(c.sweep==0 and absf(c.blades[0].rotation.z+PI/2)<0.01,"Wipers park after shutdown")
	c.set_quality(true)
	for vp in c.mirrors: check(vp.size==Vector2i(192,112),"Android mirror budget")
	c.visible=false
	c._process(0.2)
	for vp in c.mirrors: check(vp.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Hidden mirrors stop rendering")
	for cam in c.mirror_cameras: check(cam.cull_mask==5,"Mirrors exclude cockpit surfaces and retain vehicle body")
	var p = scene.pedals.gas
	p.visible=true
	check(p.begin(Vector2(40,40),5) and scene.car.gas==0.25,"Gas initial 25 percent")
	p.drag_to(Vector2(40,-56))
	check(scene.car.gas==1,"Gas reaches 100 percent")
	p.drag_to(Vector2(40,40))
	check(scene.car.gas==0.25,"Gas returns to 25 percent")
	p.drag_to(Vector2(40,100))
	check(scene.car.gas==0.25,"Held gas lower clamp")
	p.cancel()
	check(scene.car.gas==0,"Release gas zero")
	print("Cockpit / progressive accelerator: ","PASS" if failures==0 else "FAIL")
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)

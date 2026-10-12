extends SceneTree
const T = preload("res://scripts/transmission.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	var mechanical := preload("res://tests/drivetrain_checks.gd").new()
	failures+=mechanical.run()
	call_deferred("world_test")
func world_test() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	scene.desktop_mode=false
	for pedal in scene.pedals.values(): pedal.visible=true
	for button in scene.touch_buttons: button.visible=true
	scene.car.transmission.mode=T.Mode.MANUAL
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
	check(scene.car.gas==0.25 and scene.car.turn==1 and scene.car.clutch_pedal==1,"Simultaneous native touches")
	var pedal_drag := InputEventScreenDrag.new()
	pedal_drag.index=3
	pedal_drag.position=Vector2(1170,578)
	root.push_input(pedal_drag,true)
	check(absf(scene.car.gas-0.5)<0.01 and scene.car.clutch_pedal==1,"Progressive gas drag independently reaches 50 percent")
	pedal_drag.position=Vector2(1170,610)
	root.push_input(pedal_drag,true)
	var brake_touch := InputEventScreenTouch.new()
	brake_touch.index=5
	brake_touch.position=Vector2(1040,610)
	brake_touch.pressed=true
	root.push_input(brake_touch,true)
	pedal_drag.index=5
	pedal_drag.position=Vector2(1040,682)
	root.push_input(pedal_drag,true)
	check(absf(scene.car.pedal_brake-0.25)<0.01 and scene.car.gas==0.25,"Analog brake at 25 percent with gas held")
	brake_touch.pressed=false
	root.push_input(brake_touch,true)
	pedal_drag.index=2
	pedal_drag.position=Vector2(127,538)
	root.push_input(pedal_drag,true)
	check(absf(scene.car.clutch_pedal-0.5)<0.01,"Analog clutch reaches bite range")
	pedal_drag.position=Vector2(127,490)
	root.push_input(pedal_drag,true)
	var release := InputEventScreenTouch.new()
	release.index=1
	release.position=Vector2(70,600)
	release.pressed=false
	root.push_input(release,true)
	await process_frame
	check(scene.car.turn==0 and scene.car.gas==0.25,"Releasing steer keeps gas held")
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
	check(scene.car.gas==0.25 and scene.car.clutch_pedal==1,"Pedals remain held while shifting")
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
	scene.car.transmission.mode=T.Mode.AUTOMATIC
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
	var obstacle = g.box(scene,Vector3(-3.5,1,110),Vector3(8,2,1),g.material("concrete"),true)
	scene.car.transmission.mode=T.Mode.AUTOMATIC
	scene.car.transmission.select("D",0,1)
	scene.car.gas=1
	for i in range(240): await physics_frame
	check(scene.car.position.z>109,"Physical barrier blocks vehicle")
	obstacle.queue_free()
	await physics_frame
	print("Scene / vehicle checks: ","PASS" if failures==0 else "FAIL")
	# Surfaces and clear passage at every former boundary, seam and outer loop.
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	for x in [-96.0,0.0,96.0,160.0]:
		for z in [-960.0,-640.0,-320.0,-188.0,-180.0,-160.0,160.0,180.0,188.0,320.0,640.0,960.0]:
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x,3,z),Vector3(x,-1,z))
			ray.exclude=[scene.car.get_rid()]
			var hit: Dictionary = space.intersect_ray(ray)
			check(not hit.is_empty() and hit.position.y<0.3,"Continuous road surface at %s / %s" % [x,z])
		for side in [-1.0,1.0]:
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x,0.7,side*170),Vector3(x,0.7,side*220))
			ray.exclude=[scene.car.get_rid()]
			check(space.intersect_ray(ray).is_empty(),"City exit has no blocking wall")
	for z in [-960.0,-640.0,-320.0,320.0,640.0,960.0]:
		for x in [-96.0,-48.0,0.0,48.0,96.0]:
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x,3,z),Vector3(x,-1,z))
			check(not space.intersect_ray(ray).is_empty(),"Cross-road loop collision")
	scene.camera_mode=0 # Camera cycle test starts from chase, independent of cockpit-first startup.
	scene._press("camera",true)
	check(scene.camera_mode==1,"Cockpit retained in camera cycle")
	scene._press("camera",true)
	await process_frame
	await process_frame
	check(scene.camera_mode==2 and scene.gauges.visible and scene.car.visual.visible,"Hood camera has gauges and visible hood")
	scene._press("horn",true)
	check(scene.car.horn==1,"Touch horn pressed")
	scene._press("horn",false)
	check(scene.car.horn==0,"Touch horn released")
	print("Road connectivity / hood / horn checks: ","PASS" if failures==0 else "FAIL")
	scene.car.reset()
	scene.car.position=Vector3(-3.5,1,-165)
	for i in range(120): await physics_frame
	scene.car.transmission.mode=T.Mode.AUTOMATIC
	scene.car.transmission.select("D",0,1)
	scene.car.gas=1
	for i in range(600): await physics_frame
	check(scene.car.position.z < -250 and scene.car.position.y > -1,"Powered car crosses city boundary onto extended road")
	print("Extended-road powered drive: ",scene.car.position)
	scene.car.release_controls()
	scene.settings.traffic_toggle.button_pressed=true
	await physics_frame
	await physics_frame
	check(scene.traffic.enabled and scene.traffic.vehicles.size()==8,"Settings enables bounded traffic")
	var colors := {}
	for body in scene.traffic.vehicles:
		var models: Array = body.get_children().filter(func(child: Node): return child.has_meta("coupe"))
		check(models.size()==1,"Traffic uses shared player coupe artwork")
		if models.size()==1:
			colors[str(models[0].get_meta("paint"))]=true
			check(models[0].find_children("*","MeshInstance3D",true,false).size()<20,"Detailed traffic model merged for bounded draw calls")
			var painted := 0
			for mesh_node in models[0].find_children("*","MeshInstance3D",true,false):
				if mesh_node.has_meta("body_paint"):
					painted+=1
					var mat: StandardMaterial3D=mesh_node.material_override if mesh_node.material_override!=null else mesh_node.mesh.surface_get_material(0)
					check(mat.albedo_color.is_equal_approx(models[0].get_meta("paint")),"Shared traffic geometry retains individual paint color")
			check(painted==1,"One merged paint surface per traffic coupe")
	check(colors.size()==8,"Eight different traffic paint colors")
	var before: Vector3=scene.traffic.vehicles[0].position
	for i in range(60): await physics_frame
	check(scene.traffic.vehicles[0].position.distance_to(before)>0.1,"Traffic moves along connected roads")
	scene.settings.traffic_toggle.button_pressed=false
	await physics_frame
	before=scene.traffic.vehicles[0].position
	for i in range(10): await physics_frame
	check(scene.traffic.vehicles[0].position==before and scene.traffic.vehicles[0].collision_layer==0,"Traffic off stops work and removes collision")
	scene.car.transmission.mode=T.Mode.MANUAL
	scene.car.transmission.gear=-1
	await process_frame
	await process_frame
	check(scene.rear_view.active and scene.rear_view.display.visible,"Manual reverse enables second display")
	scene.car.transmission.mode=T.Mode.AUTOMATIC
	scene.car.transmission.selector="R"
	await process_frame
	await process_frame
	check(scene.rear_view.active,"Automatic reverse enables second display")
	scene.car.transmission.selector="N"
	await process_frame
	await process_frame
	check(not scene.rear_view.active and scene.rear_view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Rear rendering disabled outside reverse")
	scene._press("settings",true)
	check(scene.settings.visible and not scene.car.controls_enabled,"Settings stops driving inputs")
	scene.settings.hide()
	check(scene.car.controls_enabled,"Closing settings restores control")
	print("Traffic / settings / reverse camera: ","PASS" if failures==0 else "FAIL")
	scene.car.reset()
	scene.car.position=Vector3(-3.5,1,850)
	scene.car.transmission.mode=T.Mode.AUTOMATIC
	scene.car.transmission.auto_gear=1
	for i in range(120): await physics_frame
	scene.car.transmission.select("D",0,1)
	scene.car.gas=1
	var max_kph := 0.0
	for i in range(6000):
		await physics_frame
		max_kph=maxf(max_kph,absf(scene.car.signed_speed)*3.6)
		if scene.car.position.z< -800: scene.car.position.z=850
		if max_kph>200 and i>120: break
	check(max_kph>200,"Powered fifth gear physically exceeds 200 km/h")
	check(scene.car.position.y>-1,"High-speed road collision supports car")
	print("High-speed drive peak: ",max_kph," km/h, gear ",scene.car.transmission.auto_gear,", position ",scene.car.position)
	var landscape = scene.find_child("Landscape",true,false)
	check(landscape!=null and landscape.tree_count>100 and landscape.terrain_count>150,"Trees and terrain cover extended world")
	var hill: Vector3=Vector3(305.2,0,507.3)
	hill.y=landscape.height_at(hill.x,hill.z)
	var terrain_hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(hill+Vector3(0,15,0),hill-Vector3(0,5,0)))
	check(not terrain_hit.is_empty(),"Off-road terrain has collision")
	# Measure steering response under real physics, with parking holding position.
	scene.car.reset()
	scene.car.transmission.mode=T.Mode.AUTOMATIC
	scene.car.transmission.selector="P"
	scene.car.gas=0
	scene.car.turn=1
	for i in range(6): await physics_frame
	check(scene.car.steering>0.25,"Steering responds within 100 ms")
	scene.car.turn=0
	for i in range(12): await physics_frame
	check(absf(scene.car.steering)<0.05,"Steering returns promptly to center")
	print("Shared coupe / landscape / steering checks: ","PASS" if failures==0 else "FAIL")
	var physical := preload("res://tests/vehicle_scenarios.gd").new()
	failures+=await physical.run(scene)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)


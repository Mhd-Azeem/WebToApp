extends SceneTree
var failures:=0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func run() -> void:
	var scene=load("res://scenes/akurana.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	var car=scene.car
	var world=scene.akurana_world
	for location in [Vector2(-130,200),Vector2(-95,-180),Vector2(-290,-390)]:
		var spawn: Dictionary=world.road_spawn_near(location)
		car.spawn_point=spawn.position
		car.reset()
		car.rotation.y=spawn.yaw
		car.handbrake=1
		car.sleeping=false
		for i in range(150): await physics_frame
		var contact_count:=0
		for wheel in car.wheels:
			if wheel.is_in_contact(): contact_count+=1
		check(contact_count>=2,"Hill suspension must retain ground contact")
		check(absf(car.global_position.y-world.height_at(car.global_position.x,car.global_position.z))<3,"Hill chassis follows ground")
		scene.camera_mode=1
		scene._process(.016)
		check(scene.camera.global_basis.y.dot(car.global_basis.y)>.97,"Camera follows hill pitch/roll")
		var start: Vector3=car.global_position
		car.handbrake=0
		if car.transmission.mode==0: car.transmission.toggle(0)
		car.transmission.select("D",0,1)
		car.gas=.7
		for i in range(180): await physics_frame
		check(car.global_position.distance_to(start)>1.,"Automatic drivetrain must move on mapped hill road")
		check(Vector2(car.global_position.x,car.global_position.z).distance_to(Vector2(start.x,start.z))<100.,"Hill driving must not unexpectedly recover to default spawn")
		car.gas=0
	# Choose an actual mapped narrow street with a long, modest-grade segment.
	var narrow: Dictionary={}
	for road in world.mapped_roads:
		if float(road.width)>3.6: continue
		var path: Array=road.path
		for i in range(path.size()-1):
			var a:=Vector2(float(path[i][0]),float(path[i][1]))
			var b:=Vector2(float(path[i+1][0]),float(path[i+1][1]))
			if a.distance_to(b)<40: continue
			if absf(world.height_at(a.x,a.y)-world.height_at(b.x,b.y))/a.distance_to(b)>.08: continue
			var p:=a.lerp(b,.5)
			var direction:=b-a
			if str(road.oneway)=="-1": direction=-direction
			narrow={"position":Vector3(p.x,world.road_surface_at(p.x,p.y)+1.5,p.y),"yaw":atan2(direction.x,direction.y),"width":road.width}
			break
		if not narrow.is_empty(): break
	check(not narrow.is_empty(),"Mapped narrow-street driving fixture exists")
	if not narrow.is_empty():
		car.spawn_point=narrow.position
		car.reset()
		car.rotation.y=narrow.yaw
		car.handbrake=1
		car.sleeping=false
		for i in range(120): await physics_frame
		car.handbrake=0
		car.transmission.select("D",0,1)
		car.gas=.45
		var start: Vector3=car.global_position
		for i in range(180): await physics_frame
		check(car.global_position.distance_to(start)>1,"Car can travel through a mapped narrow street")
		check(world.road_distance_at(car.global_position.x,car.global_position.z)<float(narrow.width)*.5+.5,"Narrow street retains navigable lane")
		car.gas=0
	# A real sustained fall should recover; ordinary off-road driving is checked
	# separately by akurana_ground_physics.gd.
	car.global_position=Vector3(320,world.height_at(320,320)-12,320)
	car.linear_velocity=Vector3.ZERO
	car.angular_velocity=Vector3.ZERO
	car.sleeping=false
	for i in range(130): await physics_frame
	check(car.global_position.y>world.height_at(car.global_position.x,car.global_position.z)-3,"Sustained fall recovery")
	print("AKURANA HILL DRIVING: failures ",failures)
	quit(1 if failures else 0)

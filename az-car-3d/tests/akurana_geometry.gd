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
	await physics_frame
	var world=scene.akurana_world
	check(world.terrain_count==400,"Terrain chunk count")
	check(world.building_count>500,"Mapped buildings remain visible")
	var surface_count:=0
	for node in world.render_meshes:
		if not node is MeshInstance3D: continue
		if str(node.name).begins_with("Road") or str(node.name).begins_with("Terrain"):
			surface_count+=1
			var arrays: Array=node.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			check(normals[0].y>0,"Drivable surface front face must point upward: "+str(node.name))
	check(surface_count>=600,"Road/terrain tiles must survive the bake")
	var rays_checked:=0
	for road in world.mapped_roads:
		var path: Array=road.path
		for i in range(path.size()-1):
			var a:=Vector2(float(path[i][0]),float(path[i][1]))
			var b:=Vector2(float(path[i+1][0]),float(path[i+1][1]))
			if a.distance_to(b)<.1: continue
			var point:=a.lerp(b,.5)
			var y:=float(world.road_surface_at(point.x,point.y))
			var query:=PhysicsRayQueryParameters3D.create(Vector3(point.x,y+3,point.y),Vector3(point.x,y-3,point.y))
			query.exclude=[scene.car.get_rid()]
			var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty(),"Road collider continuity")
			if not hit.is_empty(): check(absf(hit.position.y-y)<.03,"Road/terrain elevation consistency")
			rays_checked+=1
	# All chassis dimensions and settings state remain the playable game.
	check(not scene.car.legacy_fall_recovery,"Akurana must use terrain-aware sustained recovery")
	check(scene.car.wheels.size()==4,"Suspension wheels preserved")
	for mode in [0,1,2]:
		scene.camera_mode=mode
		for frame in range(20): scene._process(.1)
		var camera_query:=PhysicsShapeQueryParameters3D.new()
		var sphere:=SphereShape3D.new()
		sphere.radius=.08
		camera_query.shape=sphere
		camera_query.transform=Transform3D(Basis.IDENTITY,scene.camera.global_position)
		camera_query.exclude=[scene.car.get_rid()]
		check(scene.get_world_3d().direct_space_state.intersect_shape(camera_query).is_empty(),"Gameplay camera collider clearance")
	for preset in range(4):
		scene.settings.graphics=scene.settings.PRESETS[preset].duplicate()
		scene._apply_graphics()
		check(scene.camera.far>float(scene.settings.graphics.distance),"Quality view distance")
		check(Engine.max_fps==int(scene.settings.graphics.fps),"Quality frame limit")
	print("AKURANA GEOMETRY: ",rays_checked," collider rays; ",surface_count," surface tiles; failures ",failures)
	quit(1 if failures else 0)

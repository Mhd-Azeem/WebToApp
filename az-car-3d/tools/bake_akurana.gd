extends SceneTree
## Offline bake: merge render batches, generate decorative LODs, retain colliders.
func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Bake needs an active renderer to serialize MultiMesh buffers; use xvfb-run in CI")
		quit(1)
		return
	var world:=Node3D.new()
	world.set_script(load("res://scripts/akurana_world.gd"))
	root.add_child(world)
	var groups: Dictionary={}
	for child in world.get_children():
		if not child is MeshInstance3D: continue
		var center: Vector3=child.to_global(child.get_aabb().get_center())
		var kind: String=child.name
		# Terrain/road topology stays fixed at every tile edge: no LOD cracks.
		if kind.begins_with("Terrain") or kind.begins_with("Road") or kind.begins_with("Shoulder") or kind.begins_with("Marking"): continue
		var key: String="%d:%d:%d" % [floori(center.x/128),floori(center.z/128),child.material_override.get_instance_id()]
		if not groups.has(key): groups[key]=[]
		groups[key].append(child)
	for nodes in groups.values():
		var tool:=SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for node in nodes: tool.append_from(node.mesh,0,node.transform)
		tool.index()
		var mesh:=tool.commit()
		var center:=mesh.get_aabb().get_center()
		var local_tool:=SurfaceTool.new()
		local_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		local_tool.append_from(mesh,0,Transform3D(Basis.IDENTITY,-center))
		local_tool.index()
		mesh=local_tool.commit()
		var importer:=ImporterMesh.new()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0))
		importer.generate_lods(25,60,[])
		var instance:=MeshInstance3D.new()
		instance.name="BuildingTile"
		instance.mesh=importer.get_mesh()
		instance.position=center
		instance.material_override=nodes[0].material_override
		instance.visibility_range_end=600
		world.add_child(instance,true)
		for node in nodes:
			world.remove_child(node)
			node.free()
	# Combine static concave colliders within 64m tiles, preserving every face.
	var collision_groups: Dictionary={}
	var old_bodies: Array=[]
	for body in world.get_children():
		if not body is StaticBody3D: continue
		var shape: CollisionShape3D=body.get_child(0)
		if not shape.shape is ConcavePolygonShape3D: continue
		var faces: PackedVector3Array=shape.shape.get_faces()
		if faces.is_empty(): continue
		var bounds:=AABB(faces[0],Vector3.ZERO)
		for p in faces: bounds=bounds.expand(p)
		var center:=bounds.get_center()
		var key: String="%d:%d" % [floori(center.x/64),floori(center.z/64)]
		if not collision_groups.has(key): collision_groups[key]=PackedVector3Array()
		var group: PackedVector3Array=collision_groups[key]
		group.append_array(faces)
		collision_groups[key]=group
		old_bodies.append(body)
	for faces in collision_groups.values():
		var body:=StaticBody3D.new()
		body.name="CollisionTile"
		var shape:=CollisionShape3D.new()
		var resource:=ConcavePolygonShape3D.new()
		resource.set_faces(faces)
		resource.backface_collision=true
		shape.shape=resource
		body.add_child(shape)
		world.add_child(body,true)
	for body in old_bodies:
		world.remove_child(body)
		body.free()
	world.set_meta("terrain_count",world.terrain_count)
	world.set_meta("building_count",world.building_count)
	for node in world.find_children("*","",true,false): node.owner=world
	# RenderingServer must upload instance buffers before ResourceSaver reads them.
	await process_frame
	await RenderingServer.frame_post_draw
	world.set_script(null)
	var packed:=PackedScene.new()
	var error:=packed.pack(world)
	if error==OK: error=ResourceSaver.save(packed,"res://data/akurana/environment.scn",ResourceSaver.FLAG_COMPRESS)
	print("Akurana bake: ",error)
	quit(0 if error==OK else 1)

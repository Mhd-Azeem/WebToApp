extends RefCounted
static var traffic_template: PackedScene

static func traffic_model(parent: Node3D,color: Color) -> Node3D:
	if traffic_template!=null:
		var copy := traffic_template.instantiate() as Node3D
		parent.add_child(copy)
		var paint := G.material("",color)
		paint.metallic=0.65
		paint.roughness=0.25
		for node in copy.find_children("*","MeshInstance3D",true,false):
			if node.has_meta("body_paint"): node.material_override=paint
		return copy
	var model := build(parent,color)
	for x in [-0.94,0.94]:
		for z in [-1.3,1.3]:
			var wheel_root := Node3D.new()
			model.add_child(wheel_root)
			wheel_root.position=Vector3(x,0.45,z)
			wheel(wheel_root,x)
	merge_static(model)
	for node in model.find_children("*","",true,false): node.owner=model
	traffic_template=PackedScene.new()
	traffic_template.pack(model)
	return model

static func merge_static(root: Node3D) -> void:
	# Traffic shares the detailed coupe without hundreds of separate draw calls.
	var groups := {}
	for n in root.find_children("*","MeshInstance3D",true,false):
		var node := n as MeshInstance3D
		var mat := node.material_override
		var key := mat.get_instance_id()
		if not groups.has(key): groups[key]=[]
		groups[key].append(node)
	for key in groups:
		var nodes: Array=groups[key]
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.set_material(nodes[0].material_override)
		for n in nodes:
			var node := n as MeshInstance3D
			var transform := root.global_transform.affine_inverse()*node.global_transform
			for surface in range(node.mesh.get_surface_count()):
				var arrays := node.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
				var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
				for index in range(indices.size() if not indices.is_empty() else vertices.size()):
					var v := indices[index] if not indices.is_empty() else index
					builder.set_normal((transform.basis*normals[v]).normalized())
					builder.set_uv(uv[v] if uv.size()>v else Vector2.ZERO)
					builder.add_vertex(transform*vertices[v])
			node.free()
		builder.index()
		var merged := MeshInstance3D.new()
		merged.mesh=builder.commit()
		# SurfaceTool retains the material after the source nodes are freed.
		if merged.mesh.surface_get_material(0)==root.get_meta("paint_material"):
			merged.set_meta("body_paint",true)
		merged.visibility_range_end=180
		root.add_child(merged)
# Shared original coupe artwork for player and traffic.
const G = preload("res://scripts/geometry.gd")
static func build(parent: Node3D, color: Color) -> Node3D:
	var visual := Node3D.new()
	parent.add_child(visual)
	# Original performance-coupe geometry: long sculpted hood, sloped glass,
	# broad haunches, rear diffuser, spoiler, split grille and detailed alloy wheels.
	var paint := G.material("",color)
	visual.set_meta("paint_material",paint)
	paint.metallic=0.65
	paint.roughness=0.25
	var trim := G.material("",Color(0.025,0.035,0.045))
	var chrome := G.material("",Color(0.53,0.60,0.66))
	chrome.metallic=0.85
	chrome.roughness=0.27
	G.profile_mesh(visual,[[-2.17,0.79,0.48,0.75],[-1.98,0.98,0.47,0.96],[-1.40,1.0,0.44,1.02],[-0.70,0.94,0.46,1.04],[0.5,0.94,0.46,1.03],[1.20,1.0,0.44,0.98],[1.85,0.93,0.47,0.85],[2.22,0.82,0.49,0.77]],paint)
	var glass := G.material("",Color(0.055,0.10,0.135))
	glass.metallic=0.2
	glass.roughness=0.16
	G.profile_mesh(visual,[[-1.39,0.81,1.00,1.08],[-0.86,0.70,1.01,1.43],[0.10,0.71,1.01,1.44],[0.99,0.83,1.0,1.08]],glass)
	G.profile_mesh(visual,[[-0.89,0.69,1.41,1.47],[-0.67,0.70,1.42,1.48],[-0.08,0.70,1.42,1.48],[0.16,0.68,1.41,1.47]],paint)
	for side in [-1.0,1.0]:
		G.box(visual,Vector3(side*0.94,0.51,-0.1),Vector3(0.12,0.09,2.65),trim)
		G.box(visual,Vector3(side*0.83,1.24,-0.60),Vector3(0.055,0.43,0.08),paint)
		G.box(visual,Vector3(side*0.89,1.05,0),Vector3(0.045,0.05,2),chrome)
		G.box(visual,Vector3(side*1.04,1.05,0.63),Vector3(0.26,0.13,0.21),paint)
		G.box(visual,Vector3(side*0.965,0.99,-0.28),Vector3(0.035,0.035,0.17),chrome)
		# Paired slim LED headlights and sculpted front intake / split grille.
		G.box(visual,Vector3(side*0.65,0.81,2.12),Vector3(0.46,0.10,0.10),trim)
		var led := G.material("",Color(0.84,0.93,1))
		led.emission_enabled=true
		led.emission=Color(0.40,0.59,0.78)
		G.box(visual,Vector3(side*0.65,0.83,2.18),Vector3(0.42,0.022,0.022),led)
		G.box(visual,Vector3(side*0.21,0.66,2.21),Vector3(0.32,0.25,0.032),trim)
		for bar in range(4): G.box(visual,Vector3(side*0.21-0.10+bar*0.065,0.66,2.24),Vector3(0.014,0.21,0.018),chrome)
		G.box(visual,Vector3(side*0.69,0.53,2.11),Vector3(0.27,0.13,0.08),trim)
		# Continuous rear-light sections, diffuser and four exhaust tips.
		G.box(visual,Vector3(side*0.65,0.86,-2.06),Vector3(0.50,0.09,0.06),G.material("",Color(0.72,0.025,0.035)))
		for offset in [-0.07,0.07]:
			var exhaust := MeshInstance3D.new()
			var pipe := CylinderMesh.new()
			pipe.top_radius=0.06
			pipe.bottom_radius=0.06
			pipe.height=0.16
			pipe.radial_segments=12
			exhaust.mesh=pipe
			exhaust.position=Vector3(side*0.68+offset,0.43,-2.14)
			exhaust.rotation.x=PI/2
			exhaust.material_override=chrome
			visual.add_child(exhaust)
	G.box(visual,Vector3(0,0.43,-2.10),Vector3(1.45,0.11,0.24),trim)
	for x in [-0.55,-0.25,0.25,0.55]: G.box(visual,Vector3(x,0.41,-2.17),Vector3(0.035,0.15,0.23),trim)
	G.box(visual,Vector3(0,0.46,2.15),Vector3(1.62,0.06,0.28),trim)
	G.box(visual,Vector3(0,0.69,-2.20),Vector3(0.42,0.13,0.025),G.material("",Color(0.9,0.93,0.94)))
	var plate := G.label(visual,"AZ 003",Vector3(0,0.70,-2.225),12)
	plate.pixel_size=0.006
	plate.rotation.y=PI
	plate.modulate=Color(0.05,0.08,0.11)
	# Rear boot lip / modest wing, two supports.
	G.box(visual,Vector3(0,1.10,-1.87),Vector3(1.76,0.06,0.30),paint)
	for x in [-0.55,0.55]: G.box(visual,Vector3(x,1.02,-1.87),Vector3(0.06,0.15,0.12),trim)
	# VehicleBody3D forward is local +Z. Driver sits on local -X (right).
	G.box(visual,Vector3(-0.42,1.15,0.6),Vector3(0.28,0.08,0.28),G.material("",Color(0.05,0.05,0.05)))

	return visual

static func wheel(w: Node3D,x: float) -> void:
	var trim := G.material("",Color(0.025,0.035,0.045))
	var chrome := G.material("",Color(0.53,0.60,0.66))
	var tire := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius=0.34
	cylinder.bottom_radius=0.34
	cylinder.height=0.22
	cylinder.radial_segments=16
	tire.mesh=cylinder
	tire.rotation.z=PI/2
	tire.material_override=G.material("",Color(0.03,0.035,0.038))
	w.add_child(tire)
	var rim := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius=0.245
	disc.bottom_radius=0.245
	disc.height=0.235
	disc.radial_segments=16
	rim.mesh=disc
	rim.rotation.z=PI/2
	rim.material_override=trim
	w.add_child(rim)
	for spoke in range(5):
		var angle := spoke*TAU/5.0
		var arm := G.box(w,Vector3(signf(x)*0.128,sin(angle)*0.12,cos(angle)*0.12),Vector3(0.025,0.035,0.22),chrome)
		arm.rotation.x=-angle
	var hub := G.box(w,Vector3(signf(x)*0.143,0,0),Vector3(0.03,0.07,0.07),chrome)
	hub.rotation.x=PI/4


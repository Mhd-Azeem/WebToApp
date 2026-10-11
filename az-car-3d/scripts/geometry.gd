extends RefCounted
class_name SriGeometry
static var materials := {}

static func material(name: String, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var key := name + str(tint)
	if materials.has(key): return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.88
	var path := "res://assets/textures/" + name + ".png"
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	materials[key] = m
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	n.visibility_range_end = 230.0
	parent.add_child(n)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var resource := BoxShape3D.new()
		resource.size = size
		shape.shape = resource
		body.add_child(shape)
		n.add_child(body)
	return n

static func label(parent: Node3D, text: String, pos: Vector3, size := 38) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.04
	l.outline_size = 5
	l.no_depth_test = false
	l.visibility_range_end = 100.0
	parent.add_child(l)
	return l

static func profile_mesh(parent: Node3D, sections: Array, mat: Material) -> MeshInstance3D:
	# Eight-corner cross sections form a bevelled, tapered vehicle hull.
	var rings: Array = []
	for section in sections:
		var z: float=section[0]
		var w: float=section[1]
		var low: float=section[2]
		var high: float=section[3]
		rings.append([Vector3(-w*0.82,low,z),Vector3(w*0.82,low,z),Vector3(w,low+0.08,z),Vector3(w,high-0.08,z),Vector3(w*0.82,high,z),Vector3(-w*0.82,high,z),Vector3(-w,high-0.08,z),Vector3(-w,low+0.08,z)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rings.size()-1):
		for j in range(8):
			var k := (j+1)%8
			for v in [rings[i][j],rings[i+1][j],rings[i+1][k],rings[i][j],rings[i+1][k],rings[i][k]]: st.add_vertex(v)
	for end in [0,rings.size()-1]:
		var center := Vector3(0,(sections[end][2]+sections[end][3])/2.0,sections[end][0])
		for j in range(8):
			st.add_vertex(center)
			st.add_vertex(rings[end][j if end==0 else (j+1)%8])
			st.add_vertex(rings[end][(j+1)%8 if end==0 else j])
	st.generate_normals()
	var n := MeshInstance3D.new()
	n.mesh=st.commit()
	n.material_override=mat
	parent.add_child(n)
	return n

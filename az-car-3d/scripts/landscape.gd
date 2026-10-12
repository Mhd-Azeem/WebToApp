extends Node3D
const G = preload("res://scripts/geometry.gd")
const SIZE := 80
const STEP := 10
var noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var tree_count := 0
var terrain_count := 0
var batches := {}
var trunk_mesh: CylinderMesh
var crown_mesh: SphereMesh
var trunk_mat: Material
var leaves: Array[Material] = []

func _ready() -> void:
	noise.seed=20261012
	noise.frequency=0.009
	rng.seed=20261012
	trunk_mesh=CylinderMesh.new()
	trunk_mesh.top_radius=0.16
	trunk_mesh.bottom_radius=0.28
	trunk_mesh.height=4.6
	trunk_mesh.radial_segments=6
	crown_mesh=SphereMesh.new()
	crown_mesh.radius=2.5
	crown_mesh.height=5.0
	crown_mesh.radial_segments=8
	crown_mesh.rings=4
	trunk_mat=G.material("",Color(0.30,0.21,0.12))
	for color in [Color(0.13,0.29,0.09),Color(0.20,0.38,0.12),Color(0.29,0.43,0.14)]: leaves.append(G.material("",color))
	for x in range(-140,420,SIZE):
		for z in range(-1120,1120,SIZE): _terrain(x,z)
	# Seafront, beach and distant eastern hills provide a varied horizon.
	G.box(self,Vector3(-250,-0.30,0),Vector3(220,0.1,2320),G.material("",Color(0.06,0.32,0.42))).visibility_range_end=0
	for z in range(-1000,1001,80):
		for x in [-120.0,-67.0,-29.0,29.0,62.0,123.0,195.0,250.0,325.0,385.0]:
			var p := Vector3(x+rng.randf_range(-6,6),0,z+rng.randf_range(-18,18))
			if absf(p.z)<215: continue
			if _road_distance(p.x,p.z)<18: continue
			# Keep sparse fringe buildings clear too.
			if _near_building(p): continue
			_tree(p,rng.randf_range(0.85,1.45),tree_count%3)
	# Green pockets fit between the existing city building rows.
	for road in [-96.0,0.0,96.0]:
		for z in [-120.0,-40.0,40.0,120.0]:
			for side in [-1.0,1.0]: _tree(Vector3(road+side*9,0,z),0.85,tree_count%3)
	for x in [-49.0,47.0]:
		for z in [-120.0,-40.0,40.0,120.0]:
			G.box(self,Vector3(x,-0.06,z),Vector3(40,0.08,12),G.material("",Color(0.30,0.43,0.19)))
			G.box(self,Vector3(x,0.01,z),Vector3(3,0.03,12),G.material("concrete"))
			for side in [-1.0,1.0]:
				_tree(Vector3(x+side*11,0,z),0.82,tree_count%3)
				G.box(self,Vector3(x+side*4,0.48,z),Vector3(2.3,0.14,0.7),G.material("",Color(0.39,0.25,0.12)))
				for leg in [-0.8,0.8]: G.box(self,Vector3(x+side*4+leg,0.24,z),Vector3(0.12,0.48,0.6),trunk_mat)
	_flush_trees()

func _road_distance(x: float,z: float) -> float:
	var d := minf(minf(absf(x+96),absf(x)),minf(absf(x-96),absf(x-160)))
	if x>=-112 and x<=177:
		for cross in [-960.0,-640.0,-320.0,320.0,640.0,960.0]: d=minf(d,absf(z-cross))
	return d

func height_at(x: float,z: float) -> float:
	if absf(z)<215 and x<185: return -0.18
	if _near_building(Vector3(x,0,z)): return -0.18
	var road_blend := clampf((_road_distance(x,z)-14.0)/32.0,0,1)
	var coast_blend := clampf((x+140)/25.0,0,1)
	var hills := 6.0+maxf(0,x-175)*0.13
	return -0.18+maxf(0,noise.get_noise_2d(x,z)+0.45)*hills*road_blend*coast_blend

func _terrain(x: int,z: int) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix in range(SIZE/STEP):
		for iz in range(SIZE/STEP):
			var corners: Array[Vector2]=[Vector2(x+ix*STEP,z+iz*STEP),Vector2(x+(ix+1)*STEP,z+iz*STEP),Vector2(x+ix*STEP,z+(iz+1)*STEP),Vector2(x+(ix+1)*STEP,z+(iz+1)*STEP)]
			for index in [0,1,2,1,3,2]:
				var p := corners[index]
				var h := height_at(p.x,p.y)
				var shade := noise.get_noise_2d(p.x*2,p.y*2)*0.1
				var grass := Color(0.31+shade,0.43+shade,0.18+shade)
				if p.x<-118: grass=Color(0.69,0.64,0.43)
				if h>9: grass=grass.lerp(Color(0.40,0.39,0.29),clampf((h-9)/12,0,0.6))
				surface.set_color(grass)
				surface.add_vertex(Vector3(p.x-x,h,p.y-z))
	surface.generate_normals()
	surface.index()
	var instance := MeshInstance3D.new()
	instance.mesh=surface.commit()
	instance.position=Vector3(x,0,z)
	var mat := G.material("landscape_vertex")
	mat.vertex_color_use_as_albedo=true
	mat.vertex_color_is_srgb=true
	instance.material_override=mat
	instance.visibility_range_end=310
	add_child(instance)
	# Mesh collision makes the varied off-road surface driveable as well.
	instance.create_trimesh_collision()
	terrain_count+=1

func _near_building(p: Vector3) -> bool:
	for road in [-96.0,0.0,96.0,160.0]:
		for side in [-1.0,1.0]:
			if absf(p.x-(road+side*26))<11:
				var local_z := fposmod(p.z-35+80,160)-80
				if absf(local_z)<15: return true
	return false

func _tree(p: Vector3,scale_factor: float,variant: int) -> void:
	p.y=height_at(p.x,p.z)
	var key := str(floori(p.x/160))+":"+str(floori(p.z/160))+":"+str(variant)
	if not batches.has(key): batches[key]={"trunk":[],"crown":[],"rock":[],"variant":variant}
	var basis := Basis.IDENTITY.scaled(Vector3(scale_factor,scale_factor,scale_factor))
	batches[key].trunk.append(Transform3D(basis,p+Vector3(0,2.3*scale_factor,0)))
	# Overlapping irregular lobes avoid identical spherical tree silhouettes.
	for offset in [Vector3(-1.1,4.7,0.4),Vector3(1.0,5.0,-0.6),Vector3(0,6.0,0)]:
		var crown_basis := basis.scaled(Vector3(0.78,rng.randf_range(0.7,0.95),0.80))
		batches[key].crown.append(Transform3D(crown_basis,p+offset*scale_factor))
	if absf(p.z)>215:
		for side in [-1.0,1.0]:
			var shrub := p+Vector3(side*3.4,0,1.5)
			shrub.y=height_at(shrub.x,shrub.z)+0.4
			batches[key].crown.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.45,0.18,0.4)),shrub))
		if tree_count%2==0:
			var rock := p+Vector3(2.8,0,-2.2)
			rock.y=height_at(rock.x,rock.z)+0.35
			batches[key].rock.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.4,0.2,0.35)),rock))
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var trunk := CylinderShape3D.new()
	trunk.radius=0.28*scale_factor
	trunk.height=4.6*scale_factor
	shape.shape=trunk
	body.position=p+Vector3(0,2.3*scale_factor,0)
	body.add_child(shape)
	add_child(body)
	tree_count+=1

func _flush_trees() -> void:
	for key in batches:
		var group: Dictionary=batches[key]
		for part in ["trunk","crown","rock"]:
			var mm := MultiMesh.new()
			mm.transform_format=MultiMesh.TRANSFORM_3D
			mm.mesh=trunk_mesh if part=="trunk" else crown_mesh
			var transforms: Array=group[part]
			if transforms.is_empty(): continue
			mm.instance_count=transforms.size()
			for i in range(transforms.size()): mm.set_instance_transform(i,transforms[i])
			var instance := MultiMeshInstance3D.new()
			instance.multimesh=mm
			instance.material_override=trunk_mat if part=="trunk" else (G.material("",Color(0.43,0.43,0.38)) if part=="rock" else leaves[group.variant])
			instance.visibility_range_end=230
			add_child(instance)

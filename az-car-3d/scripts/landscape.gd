extends Node3D
const G = preload("res://scripts/geometry.gd")
const SIZE := 80
const STEP := 10
const GRID_ORIGIN := Vector2(-140, -1120)
const GRID_SIZE := Vector2i(11, 28)
const Region = preload("res://scripts/regional_road.gd")
var player: Node3D
var vegetation_density := 1.0
var stream_radius := 270.0
var chunks := {}
var stream_elapsed := 0.0
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
	# The sea and city parks are small persistent landmarks.
	G.box(self, Vector3(-250,-0.30,0), Vector3(220,0.1,2320), G.material("",Color(0.06,0.32,0.42))).visibility_range_end=0
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

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player): return
	stream_elapsed += delta
	if stream_elapsed < 0.13: return
	stream_elapsed = 0.0
	stream_at(player.position)

func stream_at(position_3d: Vector3, immediate := false) -> void:
	var focus := Vector2(position_3d.x, position_3d.z)
	var center := Vector2i(((focus - GRID_ORIGIN) / SIZE).floor())
	var reach := ceili((stream_radius + SIZE) / SIZE)
	var candidates: Array[Vector2i] = []
	for x in range(maxi(0, center.x - reach), mini(GRID_SIZE.x, center.x + reach + 1)):
		for z in range(maxi(0, center.y - reach), mini(GRID_SIZE.y, center.y + reach + 1)):
			var key := Vector2i(x, z)
			if not chunks.has(key) and _distance(key, focus) <= stream_radius:
				candidates.append(key)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i): return _distance(a, focus) < _distance(b, focus))
	for i in range(candidates.size() if immediate else mini(candidates.size(), 3)):
		var key := candidates[i]
		var origin := GRID_ORIGIN + Vector2(key) * SIZE
		chunks[key] = _terrain(int(origin.x), int(origin.y))
	for key: Vector2i in chunks.keys():
		if _distance(key, focus) > stream_radius + SIZE:
			chunks[key].queue_free()
			chunks.erase(key)
	terrain_count = chunks.size()

func _distance(key: Vector2i, focus: Vector2) -> float:
	var origin := GRID_ORIGIN + Vector2(key) * SIZE
	var closest := Vector2(clampf(focus.x, origin.x, origin.x + SIZE), clampf(focus.y, origin.y, origin.y + SIZE))
	return focus.distance_to(closest)

func set_detail(radius: float, density: float) -> void:
	stream_radius = radius
	vegetation_density = density
	for chunk: Node3D in chunks.values():
		_apply_vegetation_detail(chunk)

func _apply_vegetation_detail(chunk: Node3D) -> void:
	for batch in chunk.get_node("Vegetation").get_children():
		if not batch is MultiMeshInstance3D: continue
		# Cull decorative detail while keeping all solid trunks visible.
		if batch.get_meta("decorative"):
			batch.multimesh.visible_instance_count = ceili(batch.multimesh.instance_count * vegetation_density)
		batch.visibility_range_end = maxf(140, stream_radius - 30)

func _road_distance(x: float,z: float) -> float:
	var d := minf(minf(absf(x+96),absf(x)),minf(absf(x-96),absf(x-160)))
	if x>=-112 and x<=177:
		for cross in [-960.0,-640.0,-320.0,320.0,640.0,960.0]: d=minf(d,absf(z-cross))
	return minf(d, Region.nearest(Vector2(x,z)).x) if x > 173 else d

func height_at(x: float,z: float) -> float:
	if absf(z)<215 and x<185: return -0.18
	if _near_building(Vector3(x,0,z)): return -0.18
	var road_blend := clampf((_road_distance(x,z)-14.0)/32.0,0,1)
	var coast_blend := clampf((x+140)/25.0,0,1)
	var hills := 6.0+maxf(0,x-175)*0.09
	var height := -0.18+maxf(0,noise.get_noise_2d(x,z)+0.45)*hills*road_blend*coast_blend
	if x > 173:
		var road := Region.nearest(Vector2(x,z))
		var ravine := road.y - 8.0 if absf(z - (350.0 + (x-420)*0.32)) < 32 else road.y - 0.35
		height = lerpf(ravine, height, smoothstep(10, 36, road.x))
	return height

func _terrain(x: int,z: int) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heights := {}
	var shades := {}
	for vx in range(x, x + SIZE + 1, STEP):
		for vz in range(z, z + SIZE + 1, STEP):
			var point := Vector2(vx, vz)
			heights[point] = height_at(vx, vz)
			shades[point] = noise.get_noise_2d(vx * 2, vz * 2) * 0.1
	for ix in range(SIZE/STEP):
		for iz in range(SIZE/STEP):
			var corners: Array[Vector2]=[Vector2(x+ix*STEP,z+iz*STEP),Vector2(x+(ix+1)*STEP,z+iz*STEP),Vector2(x+ix*STEP,z+(iz+1)*STEP),Vector2(x+(ix+1)*STEP,z+(iz+1)*STEP)]
			for index in [0,1,2,1,3,2]:
				var p := corners[index]
				var h: float = heights[p]
				var shade: float = shades[p]
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
	var terrain_body := instance.get_child(0)
	terrain_body.set_meta("surface", "sand" if x + SIZE <= -118 else "grass")
	var vegetation := Node3D.new()
	vegetation.name = "Vegetation"
	instance.add_child(vegetation)
	vegetation.position = -instance.position
	if absf(z + SIZE * 0.5) > 215:
		rng.seed = hash(Vector2i(x,z))
		for i in range(7):
			var p := Vector3(x + rng.randf_range(5, SIZE - 5), 0, z + rng.randf_range(5, SIZE - 5))
			if _road_distance(p.x, p.z) >= 18 and not _near_building(p):
				_tree(p, rng.randf_range(0.85, 1.45), i % 3, vegetation)
		_flush_trees(vegetation)
	_apply_vegetation_detail(instance)
	return instance

func _near_building(p: Vector3) -> bool:
	for road in [-96.0,0.0,96.0,160.0]:
		for side in [-1.0,1.0]:
			if absf(p.x-(road+side*26))<11:
				var local_z := fposmod(p.z-35+80,160)-80
				if absf(local_z)<15: return true
	return false

func _tree(p: Vector3,scale_factor: float,variant: int, parent: Node3D = self) -> void:
	p.y=height_at(p.x,p.z)
	var key := str(floori(p.x/160))+":"+str(floori(p.z/160))+":"+str(variant)
	if not batches.has(key): batches[key]={"trunk":[],"crown":[],"canopy":[],"rock":[],"variant":variant}
	var basis := Basis.IDENTITY.scaled(Vector3(scale_factor,scale_factor,scale_factor))
	batches[key].trunk.append(Transform3D(basis,p+Vector3(0,2.3*scale_factor,0)))
	# Overlapping irregular lobes avoid identical spherical tree silhouettes.
	batches[key].canopy.append(Transform3D(basis, p + Vector3(0, 5, 0)*scale_factor))
	for offset in [Vector3(-1.1,4.7,0.4),Vector3(1.0,5.0,-0.6)]:
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
	parent.add_child(body)
	if parent == self: tree_count += 1

func _flush_trees(parent: Node3D = self) -> void:
	for key in batches:
		var group: Dictionary=batches[key]
		for part in ["trunk","canopy","crown","rock"]:
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
			instance.set_meta("decorative", part in ["crown", "rock"])
			parent.add_child(instance)
	batches.clear()

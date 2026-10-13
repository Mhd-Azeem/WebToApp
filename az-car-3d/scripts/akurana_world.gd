extends Node3D
## Akurana early-access GIS preview. Coordinates were clipped/projected from OSM,
## heights sampled from Copernicus GLO-30 DSM. Do not use for navigation.
const G = preload("res://scripts/geometry.gd")
const DATA = "res://data/akurana/preview.json"
const GRID_SIZE = 25
const HALF_SIZE = 640.0
# Each GIS height sample spans ~53 m. Subdivision is essential: otherwise
# the physics/visible triangle surface diverges sharply from height_at().
const TERRAIN_SUBDIVISIONS = 8
const ROAD_CLEARANCE = 0.65
var heights: PackedByteArray = PackedByteArray()
var mapped_roads: Array = []

func _ready() -> void:
	var raw := FileAccess.get_file_as_string(DATA)
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary:
		push_error("Akurana map data missing or invalid")
		return
	heights = Marshalls.base64_to_raw(str(parsed.get("grid", "")))
	if heights.size() != GRID_SIZE * GRID_SIZE:
		push_error("Invalid Akurana height grid")
		return
	_generate_terrain()
	mapped_roads = parsed.get("roads", [])
	_generate_roads(mapped_roads)
	_generate_buildings(parsed.get("buildings", []))
	G.label(self, "AKURANA - SRI LANKA", Vector3(-150, 37, 40), 24)


func road_spawn_near(point: Vector2 = Vector2(-113.0, 25.0)) -> Dictionary:
	# Project onto the nearest mapped road segment instead of spawning in a field.
	var best_distance := INF
	var best_point := Vector2.ZERO
	var best_heading := 0.0
	var best_width := 0.0
	for feature in mapped_roads:
		if not feature is Array or feature.size() < 2: continue
		var width := float(feature[0])
		var path: Array = feature[1]
		for i in range(path.size() - 1):
			var a := Vector2(float(path[i][0]),float(path[i][1]))
			var b := Vector2(float(path[i + 1][0]),float(path[i + 1][1]))
			var ab := b - a
			if ab.length_squared() < 1.0: continue
			var fraction := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var nearest := a + ab * fraction
			var distance := nearest.distance_to(point)
			if distance < best_distance:
				best_distance = distance
				best_point = nearest
				best_heading = atan2(ab.x, ab.y)
				best_width = width
	if not is_finite(best_distance):
		return {}
	# A modest lift gives suspension time to settle onto the road collision.
	return {"position": Vector3(best_point.x, height_at(best_point.x, best_point.y) + 1.65, best_point.y),
		"yaw": best_heading, "distance": best_distance, "road_width": best_width}

func height_at(x: float, z: float) -> float:
	if heights.size() != GRID_SIZE * GRID_SIZE:
		return 20.0
	var u := clampf((x + HALF_SIZE) / (HALF_SIZE * 2.0) * float(GRID_SIZE - 1), 0.0, float(GRID_SIZE - 1))
	var v := clampf((z + HALF_SIZE) / (HALF_SIZE * 2.0) * float(GRID_SIZE - 1), 0.0, float(GRID_SIZE - 1))
	var ix := mini(int(floor(u)), GRID_SIZE - 2)
	var iz := mini(int(floor(v)), GRID_SIZE - 2)
	var fx := u - float(ix)
	var fz := v - float(iz)
	var a := lerpf(float(heights[iz * GRID_SIZE + ix]), float(heights[iz * GRID_SIZE + ix + 1]), fx)
	var b := lerpf(float(heights[(iz + 1) * GRID_SIZE + ix]), float(heights[(iz + 1) * GRID_SIZE + ix + 1]), fx)
	return lerpf(a, b, fz)

func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)

func _finish(tool: SurfaceTool, material: Material, solid: bool) -> void:
	tool.generate_normals()
	var mesh: ArrayMesh = tool.commit()
	if mesh == null:
		return
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		body.name = "TerrainOrRoadCollision"
		var shape := CollisionShape3D.new()
		# Collision is intentionally two-sided: the 30 m DSM terrain mesh is a
		# thin surface, and raycast vehicle wheels must hit it from above.
		var collision_mesh := mesh.create_trimesh_shape()
		collision_mesh.backface_collision = true
		shape.shape = collision_mesh
		body.collision_layer = 1
		body.collision_mask = 1
		body.add_child(shape)
		# Keep physics geometry directly in the world tree and independent of
		# the render mesh's visibility distance/LOD.
		add_child(body)

func _generate_terrain() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Tessellate the DEM to follow the same bilinear height function used by
	# road geometry and building foundations, preventing overhead land sheets.
	var cells := (GRID_SIZE - 1) * TERRAIN_SUBDIVISIONS
	var step := (HALF_SIZE * 2.0) / float(cells)
	for z in range(cells):
		for x in range(cells):
			var x0 := -HALF_SIZE + float(x) * step
			var x1 := x0 + step
			var z0 := -HALF_SIZE + float(z) * step
			var z1 := z0 + step
			var p00 := Vector3(x0,height_at(x0,z0),z0)
			var p01 := Vector3(x0,height_at(x0,z1),z1)
			var p10 := Vector3(x1,height_at(x1,z0),z0)
			var p11 := Vector3(x1,height_at(x1,z1),z1)
			_triangle(tool,p00,p01,p10)
			_triangle(tool,p10,p01,p11)
	var material := G.material("",Color(0.28,0.43,0.22))
	_finish(tool,material,true)

func _generate_roads(roads: Array) -> void:
	# Subdivide centerlines so they closely follow the terrain raster.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var generated := 0
	for feature in roads:
		if not feature is Array or feature.size() < 2:
			continue
		var width: float = float(feature[0])
		var path: Array = feature[1]
		for i in range(path.size() - 1):
			var a := Vector2(float(path[i][0]), float(path[i][1]))
			var b := Vector2(float(path[i + 1][0]), float(path[i + 1][1]))
			if a.distance_to(b) < 0.1:
				continue
			var normal := Vector2(-(b - a).normalized().y, (b - a).normalized().x) * width * 0.5
			var parts := maxi(1, ceili(a.distance_to(b) / 3.0))
			for s in range(parts):
				var p := a.lerp(b, float(s) / float(parts))
				var q := a.lerp(b, float(s + 1) / float(parts))
				var al := Vector3(p.x + normal.x, height_at(p.x + normal.x, p.y + normal.y) + ROAD_CLEARANCE, p.y + normal.y)
				var ar := Vector3(p.x - normal.x, height_at(p.x - normal.x, p.y - normal.y) + ROAD_CLEARANCE, p.y - normal.y)
				var bl := Vector3(q.x + normal.x, height_at(q.x + normal.x, q.y + normal.y) + ROAD_CLEARANCE, q.y + normal.y)
				var br := Vector3(q.x - normal.x, height_at(q.x - normal.x, q.y - normal.y) + ROAD_CLEARANCE, q.y - normal.y)
				_triangle(tool, al, bl, ar)
				_triangle(tool, bl, br, ar)
				generated += 1
	if generated > 0:
		var road_mat := G.material("", Color(0.19, 0.20, 0.22)) # Clearly distinguish paved roads from grass.
		_finish(tool, road_mat, true)

func _generate_buildings(buildings: Array) -> void:
	var wall_mats := [
		G.material("plaster", Color(0.84, 0.77, 0.66)),
		G.material("concrete", Color(0.65, 0.71, 0.67)),
		G.material("facade0", Color(0.92, 0.86, 0.72))
	]
	for i in range(buildings.size()):
		var b: Array = buildings[i]
		if b.size() != 4:
			continue
		var x := float(b[0])
		var z := float(b[1])
		var w := float(b[2])
		var d := float(b[3])
		var height := float(5 + (i * 7) % 3 * 3)
		var y := height_at(x, z)
		G.box(self, Vector3(x, y + height * 0.5, z), Vector3(w, height, d), wall_mats[i % wall_mats.size()], true)

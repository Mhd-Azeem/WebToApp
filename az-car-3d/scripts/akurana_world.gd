extends Node3D
## Akurana early-access GIS preview. Coordinates were clipped/projected from OSM,
## heights sampled from Copernicus GLO-30 DSM. Do not use for navigation.
const G = preload("res://scripts/geometry.gd")
const DATA = "res://data/akurana/preview.json"
const GRID_SIZE = 25
const HALF_SIZE = 640.0
var heights: PackedByteArray = PackedByteArray()

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
	_generate_roads(parsed.get("roads", []))
	_generate_buildings(parsed.get("buildings", []))
	G.label(self, "AKURANA - SRI LANKA", Vector3(-150, 37, 40), 24)

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
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		instance.add_child(body)

func _generate_terrain() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(GRID_SIZE - 1):
		for x in range(GRID_SIZE - 1):
			var x0 := -HALF_SIZE + float(x) * 2.0 * HALF_SIZE / float(GRID_SIZE - 1)
			var x1 := -HALF_SIZE + float(x + 1) * 2.0 * HALF_SIZE / float(GRID_SIZE - 1)
			var z0 := -HALF_SIZE + float(z) * 2.0 * HALF_SIZE / float(GRID_SIZE - 1)
			var z1 := -HALF_SIZE + float(z + 1) * 2.0 * HALF_SIZE / float(GRID_SIZE - 1)
			var p00 := Vector3(x0, height_at(x0, z0), z0)
			var p01 := Vector3(x0, height_at(x0, z1), z1)
			var p10 := Vector3(x1, height_at(x1, z0), z0)
			var p11 := Vector3(x1, height_at(x1, z1), z1)
			_triangle(tool, p00, p01, p10)
			_triangle(tool, p10, p01, p11)
	var material := G.material("", Color(0.28, 0.43, 0.22))
	_finish(tool, material, true)

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
			var parts := maxi(1, ceili(a.distance_to(b) / 10.0))
			for s in range(parts):
				var p := a.lerp(b, float(s) / float(parts))
				var q := a.lerp(b, float(s + 1) / float(parts))
				var al := Vector3(p.x + normal.x, height_at(p.x + normal.x, p.y + normal.y) + 0.22, p.y + normal.y)
				var ar := Vector3(p.x - normal.x, height_at(p.x - normal.x, p.y - normal.y) + 0.22, p.y - normal.y)
				var bl := Vector3(q.x + normal.x, height_at(q.x + normal.x, q.y + normal.y) + 0.22, q.y + normal.y)
				var br := Vector3(q.x - normal.x, height_at(q.x - normal.x, q.y - normal.y) + 0.22, q.y - normal.y)
				_triangle(tool, al, bl, ar)
				_triangle(tool, bl, br, ar)
				generated += 1
	if generated > 0:
		var road_mat := G.material("asphalt", Color(0.78, 0.78, 0.78))
		road_mat.uv1_triplanar = true
		road_mat.uv1_scale = Vector3(0.18, 0.18, 0.18)
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

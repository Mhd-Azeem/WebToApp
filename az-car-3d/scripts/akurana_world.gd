extends Node3D
## Akurana early-access GIS preview. Coordinates were clipped/projected from OSM,
## heights sampled from Copernicus GLO-30 DSM. Do not use for navigation.
const G = preload("res://scripts/geometry.gd")
const DATA = "res://data/akurana/preview.json"
const GRID_SIZE = 25
const HALF_SIZE = 640.0
# Each GIS height sample spans ~53 m. Subdivision is essential: otherwise
# the physics/visible triangle surface diverges sharply from height_at().
const TERRAIN_SUBDIVISIONS = 12
const ROAD_CLEARANCE = 0.13
const TWO_WAY_MIN_WIDTH = 6.8
const SHOULDER_WIDTH = 1.6
var heights: PackedByteArray = PackedByteArray()
var mapped_roads: Array = []
var terrain_texture: ImageTexture

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
		var width := maxf(TWO_WAY_MIN_WIDTH,float(feature[0]))
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
	return {"position": Vector3(best_point.x, road_surface_at(best_point.x, best_point.y) + 1.5, best_point.y),
		"yaw": best_heading, "distance": best_distance, "road_width": best_width}

func road_surface_at(x: float, z: float) -> float:
	# Road mesh is lifted over terrain; use the same number for spawn/camera checks.
	return height_at(x, z) + ROAD_CLEARANCE

func road_distance_at(x: float, z: float) -> float:
	var probe := Vector2(x,z)
	var best := INF
	for feature in mapped_roads:
		if not feature is Array or feature.size() < 2: continue
		var path: Array = feature[1]
		for i in range(path.size() - 1):
			var a := Vector2(float(path[i][0]),float(path[i][1]))
			var b := Vector2(float(path[i+1][0]),float(path[i+1][1]))
			var ab := b-a
			if ab.length_squared() < 0.01: continue
			var t := clampf((probe-a).dot(ab)/ab.length_squared(),0.0,1.0)
			best=minf(best,probe.distance_to(a+ab*t))
	return best

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

func _grass_material() -> StandardMaterial3D:
	# Small deterministic tile texture adds vegetation/soil variation without
	# requiring downloads. Keep mobile RAM/draw overhead modest.
	var noise := FastNoiseLite.new()
	noise.seed = 27419
	noise.frequency = 0.055
	noise.fractal_octaves = 3
	var img := Image.create(128,128,false,Image.FORMAT_RGB8)
	for z in range(128):
		for x in range(128):
			var n := noise.get_noise_2d(float(x),float(z))
			var d := noise.get_noise_2d(float(x+500),float(z+500))
			var grass := Color(0.30,0.43,0.23).lerp(Color(0.49,0.55,0.29),clampf(0.48+n*0.85,0.0,1.0))
			grass = grass.lerp(Color(0.40,0.35,0.25),clampf((d-0.28)*0.65,0.0,0.23))
			img.set_pixel(x,z,grass)
	terrain_texture = ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = terrain_texture
	mat.roughness = 1.0
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.11,0.11,0.11)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

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
	var material := _grass_material()
	_finish(tool,material,true)

func _road_vertex(point: Vector2, normal: Vector2, lateral: float, rise: float) -> Vector3:
	var offset := point + normal * lateral
	return Vector3(offset.x, height_at(offset.x,offset.y) + rise, offset.y)

func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(tool,a,b,c)
	_triangle(tool,c,b,d)

func _road_join(path: Array, index: int) -> Vector2:
	# Shared miter at polyline vertices. Unlike per-segment perpendiculars,
	# both neighboring road pieces now use exactly the same edge coordinates.
	var point := Vector2(float(path[index][0]),float(path[index][1]))
	var before := point
	var after := point
	if index > 0:
		before = Vector2(float(path[index-1][0]),float(path[index-1][1]))
	if index+1 < path.size():
		after = Vector2(float(path[index+1][0]),float(path[index+1][1]))
	var incoming := (point-before).normalized()
	var outgoing := (after-point).normalized()
	if incoming.length_squared() < 0.01: incoming=outgoing
	if outgoing.length_squared() < 0.01: outgoing=incoming
	var forward := (incoming+outgoing).normalized()
	if forward.length_squared() < 0.01: forward=outgoing
	var perpendicular := Vector2(-forward.y,forward.x)
	var side := Vector2(-outgoing.y,outgoing.x)
	# Restrict long spikes at extremely sharp bends.
	var denominator := maxf(0.55,absf(perpendicular.dot(side)))
	return perpendicular / denominator

func _generate_roads(roads: Array) -> void:
	# Continuous strips share mitered cross-sections at every mapped vertex.
	# This avoids the triangular grass gaps left by independent segment quads.
	var pavement := SurfaceTool.new()
	var shoulders := SurfaceTool.new()
	var center_lines := SurfaceTool.new()
	var edge_lines := SurfaceTool.new()
	for tool in [pavement,shoulders,center_lines,edge_lines]:
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var generated := 0
	for feature in roads:
		if not feature is Array or feature.size() < 2:
			continue
		var width: float = maxf(TWO_WAY_MIN_WIDTH,float(feature[0]))
		var path: Array = feature[1]
		if path.size() < 2: continue
		var progress := 0.0
		for i in range(path.size()-1):
			var a := Vector2(float(path[i][0]),float(path[i][1]))
			var b := Vector2(float(path[i+1][0]),float(path[i+1][1]))
			var length := a.distance_to(b)
			if length < 0.1: continue
			var start_join := _road_join(path,i)
			var end_join := _road_join(path,i+1)
			var parts := maxi(1,ceili(length/1.0))
			for section in range(parts):
				var t0 := float(section)/float(parts)
				var t1 := float(section+1)/float(parts)
				var p := a.lerp(b,t0)
				var q := a.lerp(b,t1)
				var pn := start_join.lerp(end_join,t0)
				var qn := start_join.lerp(end_join,t1)
				var half: float=width*0.5
				_quad(pavement,_road_vertex(p,pn,half,ROAD_CLEARANCE),_road_vertex(p,pn,-half,ROAD_CLEARANCE),_road_vertex(q,qn,half,ROAD_CLEARANCE),_road_vertex(q,qn,-half,ROAD_CLEARANCE))
				for sign in [-1.0,1.0]:
					_quad(shoulders,_road_vertex(p,pn,sign*half,ROAD_CLEARANCE),_road_vertex(p,pn,sign*(half+SHOULDER_WIDTH),0.015),_road_vertex(q,qn,sign*half,ROAD_CLEARANCE),_road_vertex(q,qn,sign*(half+SHOULDER_WIDTH),0.015))
					_quad(edge_lines,_road_vertex(p,pn,sign*(half-0.22),ROAD_CLEARANCE+0.02),_road_vertex(p,pn,sign*(half-0.11),ROAD_CLEARANCE+0.02),_road_vertex(q,qn,sign*(half-0.22),ROAD_CLEARANCE+0.02),_road_vertex(q,qn,sign*(half-0.11),ROAD_CLEARANCE+0.02))
				var midpoint := progress+length*(t0+t1)*0.5
				if fmod(midpoint,10.0)<5.0:
					_quad(center_lines,_road_vertex(p,pn,0.075,ROAD_CLEARANCE+0.023),_road_vertex(p,pn,-0.075,ROAD_CLEARANCE+0.023),_road_vertex(q,qn,0.075,ROAD_CLEARANCE+0.023),_road_vertex(q,qn,-0.075,ROAD_CLEARANCE+0.023))
				generated+=1
			progress+=length
	if generated==0:
		push_error("Akurana mapped roads contain no usable segments")
		return
	var road_mat := G.material("asphalt",Color(0.78,0.78,0.78))
	road_mat.uv1_triplanar=true
	road_mat.uv1_scale=Vector3(0.15,0.15,0.15)
	road_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	_finish(pavement,road_mat,true)
	var shoulder_mat := G.material("concrete",Color(0.52,0.48,0.41))
	shoulder_mat.uv1_triplanar=true
	shoulder_mat.uv1_scale=Vector3(0.19,0.19,0.19)
	shoulder_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	_finish(shoulders,shoulder_mat,true)
	var center_mat := G.material("",Color(0.92,0.75,0.25))
	center_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	_finish(center_lines,center_mat,false)
	var edge_mat := G.material("",Color(0.94,0.93,0.86))
	edge_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	_finish(edge_lines,edge_mat,false)

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
		var min_y: float = minf(minf(height_at(x-w*0.5,z-d*0.5),height_at(x+w*0.5,z-d*0.5)),minf(height_at(x-w*0.5,z+d*0.5),height_at(x+w*0.5,z+d*0.5)))
		var max_y: float = maxf(maxf(height_at(x-w*0.5,z-d*0.5),height_at(x+w*0.5,z-d*0.5)),maxf(height_at(x-w*0.5,z+d*0.5),height_at(x+w*0.5,z+d*0.5)))
		# Terrain slope support: building floor sits above all footprint corners;
		# a shallow concrete foundation extends down into the hillside.
		var foundation_height: float = maxf(0.8,max_y-min_y+0.75)
		G.box(self,Vector3(x,max_y-foundation_height*0.5,z),Vector3(w+0.25,foundation_height,d+0.25),G.material("concrete",Color(0.72,0.72,0.71)),true)
		G.box(self, Vector3(x,max_y+height*0.5,z), Vector3(w,height,d), wall_mats[i % wall_mats.size()], true)

extends RefCounted

const Region = preload("res://scripts/regional_road.gd")
const STREET_X := [-96.0,0.0,96.0,160.0]
const STREET_Z := [-960.0,-640.0,-320.0,-160.0,-80.0,0.0,80.0,160.0,320.0,640.0,960.0]

var points := PackedVector3Array()
var links: Array[Vector2i] = []

func _init() -> void:
	for x in STREET_X:
		for z in STREET_Z: points.append(Vector3(x,0,z))
	var count := STREET_Z.size()
	for i in range(STREET_X.size()):
		for j in range(count):
			var id := i*count+j
			if j+1<count: links.append(Vector2i(id,id+1))
			if i<2 or (i==2 and STREET_Z[j] in [-960.0,-640.0,-160.0,-80.0,0.0,80.0,160.0,640.0,960.0]):
				links.append(Vector2i(id,id+count))
	var size := points.size()
	for i in range(Region.LINE.size()):
		points.append(Region.LINE[i])
		if i>0: links.append(Vector2i(size+i-1,size+i))
	links.append(Vector2i(3*count+1,size))
	links.append(Vector2i(3*count+9,points.size()-1))

func route(origin: Vector3, destination: Vector3) -> PackedVector3Array:
	var from := _nearest(origin)
	var to := _nearest(destination)
	var first: Vector2i = from.edge
	var last: Vector2i = to.edge
	if first == last:
		return PackedVector3Array([origin, from.point, to.point, destination])
	var distances := {}
	distances[first.x] = from.point.distance_to(points[first.x])
	distances[first.y] = from.point.distance_to(points[first.y])
	var previous := {}
	var visited := {}
	while true:
		var current := -1
		var cost := INF
		for id: int in distances:
			if not visited.has(id) and distances[id]<cost:
				current=id
				cost=distances[id]
		if current<0: break
		visited[current]=true
		for edge in links:
			var neighbor := edge.y if edge.x==current else (edge.x if edge.y==current else -1)
			if neighbor<0 or visited.has(neighbor): continue
			var next_cost := cost+points[current].distance_to(points[neighbor])
			if next_cost<float(distances.get(neighbor,INF)):
				distances[neighbor]=next_cost
				previous[neighbor]=current
	var destination_a: float = float(distances.get(last.x,INF)) + to.point.distance_to(points[last.x])
	var destination_b: float = float(distances.get(last.y,INF)) + to.point.distance_to(points[last.y])
	var id := last.x if destination_a < destination_b else last.y
	var result := PackedVector3Array([destination,to.point])
	while id>=0:
		result.append(points[id])
		id=previous.get(id,-1)
	result.append(from.point)
	result.append(origin)
	result.reverse()
	return result

func _nearest(position_3d: Vector3) -> Dictionary:
	var best := INF
	var result := {}
	for link in links:
		var point := Geometry3D.get_closest_point_to_segment(position_3d,points[link.x],points[link.y])
		var distance := point.distance_squared_to(position_3d)
		if distance<best:
			result={"edge":link,"point":point}
			best=distance
	return result

func recovery_pose(origin: Vector3, space: PhysicsDirectSpaceState3D, exclude: RID) -> Dictionary:
	var nearest := _nearest(origin)
	var edge: Vector2i=nearest.edge
	var direction := (points[edge.y]-points[edge.x]).normalized()
	var side := Vector3(direction.z,0,-direction.x).normalized()
	for shift in [0.0, 9.0, -9.0, 18.0, -18.0]:
		for lane in [1.0,-1.0]:
			var point: Vector3=nearest.point+side*(3.4*lane)+direction*shift
			var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*3.0,point-Vector3.UP*2.0,1)
			query.exclude=[exclude]
			var hit:=space.intersect_ray(query)
			if hit.is_empty() or hit.collider.get_meta("surface","")!="asphalt": continue
			var hull:=BoxShape3D.new()
			hull.size=Vector3(2.2,1.8,4.8)
			var angle:=atan2(direction.x*lane,direction.z*lane)
			var clearance:=PhysicsShapeQueryParameters3D.new()
			clearance.shape=hull
			clearance.transform=Transform3D(Basis(Vector3.UP,angle),hit.position+Vector3.UP*1.25)
			clearance.collision_mask=3
			clearance.exclude=[exclude]
			if space.intersect_shape(clearance,1).is_empty():
				return {"point":hit.position+Vector3.UP*0.9,"heading":angle}
	return {}

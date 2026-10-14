extends Node3D
## Lightweight road-following Sri Lankan town traffic for Android and Windows.
## Stylized generated actors; routes are taken from Akurana OSM centerlines.
const Coupe = preload("res://scripts/coupe_visual.gd")
const G = preload("res://scripts/geometry.gd")
var world: Node3D
var player: VehicleBody3D
var actors: Array[Node3D] = []
var routes: Array = []
var travel: Array[float] = []
var speed: Array[float] = []
var kinds: Array[String] = []
var walkers: Array[Node3D] = []
var walker_anchors: Array[Vector3] = []
var walker_clock := 0.0
var enabled := true

func configure(map: Node3D, driver: VehicleBody3D) -> void:
	world=map
	player=driver
	_build()

func set_enabled(value: bool) -> void:
	enabled=value
	visible=value
	set_process(value)

func _build() -> void:
	if not is_instance_valid(world): return
	# Pick roads long enough for safe travel; vehicles drive on the left.
	var candidates: Array = []
	for road in world.mapped_roads:
		var path: Array=road.get("path",[])
		if path.size()<2 or float(road.get("width",0))<4.8: continue
		var distance:=0.0
		for i in range(path.size()-1):
			distance+=Vector2(float(path[i][0]),float(path[i][1])).distance_to(Vector2(float(path[i+1][0]),float(path[i+1][1])))
		if distance>32.0:
			var close: float=INF
			var player_2d:=Vector2(player.global_position.x,player.global_position.z)
			for segment in range(path.size()-1):
				var a:=Vector2(float(path[segment][0]),float(path[segment][1]))
				var b:=Vector2(float(path[segment+1][0]),float(path[segment+1][1]))
				close=minf(close,player_2d.distance_to(Geometry2D.get_closest_point_to_segment(player_2d,a,b)))
			candidates.append({"path":path,"distance":close})
	if candidates.is_empty():
		push_warning("No Akurana traffic routes found near the player")
		return
	candidates.sort_custom(func(a: Dictionary,b: Dictionary): return float(a.distance)<float(b.distance))
	var names: Array[String]=["sedan","hatchback","van","bus","lorry","van","sedan","bus","lorry","suv","bus","hatchback"]
	var count:=mini(12,candidates.size()*2)
	for i in range(count):
		var path: Array=candidates[i%candidates.size()].path
		var direction:=1 if i%2==0 else -1
		var route: Array[Vector3]=[]
		for j in range(path.size()):
			var index: int=j if direction==1 else path.size()-1-j
			var p:=Vector2(float(path[index][0]),float(path[index][1]))
			var next_index: int=mini(index+1,path.size()-1) if direction==1 else maxi(index-1,0)
			var other:=Vector2(float(path[next_index][0]),float(path[next_index][1]))
			var tangent: Vector2=(other-p).normalized()
			if tangent.length_squared()<0.1: tangent=Vector2(0,1)
			var left:=Vector2(tangent.y,-tangent.x)*1.4
			var at:=p+left
			route.append(Vector3(at.x,world.road_surface_at(at.x,at.y)+0.11,at.y))
		if route.size()<2: continue
		var kind:String=names[i%names.size()]
		var body:=Node3D.new()
		body.name="AkuranaTraffic"+str(i)
		add_child(body)
		var colors: Array[Color]=[Color(.82,.84,.82),Color(.16,.32,.48),Color(.70,.18,.18),Color(.85,.72,.25),Color(.31,.37,.38)]
		Coupe.traffic_model(body,colors[i%colors.size()],"van" if kind=="lorry" else kind)
		if kind=="bus": _bus_detail(body)
		if kind=="lorry": _lorry_detail(body)
		if kind=="van": _van_detail(body)
		actors.append(body)
		routes.append(route)
		# Initialize vehicles at the closest point along the selected route.
		# Starting each path at its first OSM node previously put every actor
		# hundreds of metres away, despite roads passing near the car.
		var nearest_progress:=0.0
		var nearest_distance:=INF
		var accumulated:=0.0
		var driver_2d:=Vector2(player.global_position.x,player.global_position.z)
		for segment in range(route.size()-1):
			var a2:=Vector2(route[segment].x,route[segment].z)
			var b2:=Vector2(route[segment+1].x,route[segment+1].z)
			var ab:=b2-a2
			var length:=ab.length()
			if length<.01: continue
			var fraction:=clampf((driver_2d-a2).dot(ab)/(length*length),0.0,1.0)
			var distance_to_driver:=driver_2d.distance_to(a2+ab*fraction)
			if distance_to_driver<nearest_distance:
				nearest_distance=distance_to_driver
				nearest_progress=accumulated+fraction*length
			accumulated+=length
		travel.append(clampf(nearest_progress+float(i%4)*13.0,0.0,maxf(0.0,accumulated-1.0)))
		speed.append(4.5 if kind=="bus" else (5.5 if kind=="van" else 7.0))
		kinds.append(kind)
	for i in range(12):
		var spot:=_pedestrian_spot(i)
		if spot==Vector3.INF: continue
		var person:=Node3D.new()
		person.name="Pedestrian"+str(i)
		add_child(person)
		_build_person(person,i)
		person.position=spot
		walkers.append(person)
		walker_anchors.append(spot)
	# Put actors on route immediately; do not leave them at world origin.
	_update_positions(0.0)
	set_process(true)

func _bus_detail(body: Node3D) -> void:
	var blue:=G.material("",Color(.12,.27,.65))
	var white:=G.material("",Color(.87,.87,.79))
	G.box(body,Vector3(0,2.2,0),Vector3(2.12,.38,5.7),white)
	G.box(body,Vector3(0,1.15,0),Vector3(2.18,.26,5.8),blue)

func _lorry_detail(body: Node3D) -> void:
	# Distinct tall cargo box and undercarriage from the van-based cab mesh.
	var cargo:=G.material("",Color(.72,.72,.68))
	var rails:=G.material("",Color(.23,.27,.31))
	G.box(body,Vector3(0,1.86,-1.45),Vector3(2.06,2.12,3.25),cargo)
	for side in [-1.0,1.0]:
		G.box(body,Vector3(side*1.04,1.86,-1.45),Vector3(.055,1.98,3.18),rails)

func _van_detail(body: Node3D) -> void:
	var trim:=G.material("",Color(.72,.76,.77))
	G.box(body,Vector3(0,1.45,0),Vector3(1.78,.12,3.45),trim)

func _pedestrian_spot(i: int) -> Vector3:
	var roads: Array=world.mapped_roads
	if roads.is_empty(): return Vector3.INF
	for attempt in range(roads.size()):
		var road: Dictionary=roads[(i*7+attempt)%roads.size()]
		var path: Array=road.get("path",[])
		if path.size()<2: continue
		var index: int=mini((i+attempt)%path.size(),path.size()-2)
		var a:=Vector2(float(path[index][0]),float(path[index][1]))
		var b:=Vector2(float(path[index+1][0]),float(path[index+1][1]))
		var d: Vector2=(b-a).normalized()
		if d.length_squared()<.2: continue
		var side: float=1.0 if i%2==0 else -1.0
		var p: Vector2=a.lerp(b,.5)+Vector2(-d.y,d.x)*side*(float(road.get("width",6.0))*.5+2.2)
		if p.distance_to(Vector2(-113,-25))>220: continue
		return Vector3(p.x,world.height_at(p.x,p.y),p.y)
	return Vector3.INF

func _build_person(person: Node3D,i: int) -> void:
	var cloth: Array[Color]=[Color(.16,.34,.56),Color(.77,.69,.52),Color(.52,.15,.23),Color(.23,.41,.32)]
	var shirt:=G.material("",cloth[i%cloth.size()])
	var skin:=G.material("",Color(.46,.29,.20))
	var pants:=G.material("",Color(.12,.15,.18))
	G.box(person,Vector3(0,1.18,0),Vector3(.44,.75,.26),shirt)
	G.box(person,Vector3(0,1.74,0),Vector3(.25,.29,.24),skin)
	for side in [-1.0,1.0]:
		G.box(person,Vector3(side*.13,.44,0),Vector3(.17,.80,.19),pants)
		G.box(person,Vector3(side*.30,1.16,0),Vector3(.13,.67,.17),skin)

func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(player): return
	_update_positions(delta)

func _update_positions(delta: float) -> void:
	for i in range(actors.size()):
		var actor: Node3D=actors[i]
		var route: Array[Vector3]=routes[i]
		if route.size()<2: continue
		var max_distance: float=0.0
		for k in range(route.size()-1): max_distance+=route[k].distance_to(route[k+1])
		if max_distance<1: continue
		var pace: float=speed[i]
		if delta>0.0 and actor.global_position.distance_to(player.global_position)<10.0: pace=0.0
		travel[i]=fmod(travel[i]+pace*delta,max_distance)
		var remaining: float=travel[i]
		for j in range(route.size()-1):
			var length: float=route[j].distance_to(route[j+1])
			if remaining<=length:
				var position: Vector3=route[j].lerp(route[j+1],remaining/maxf(length,.01))
				actor.position=position
				var heading: Vector3=(route[j+1]-route[j]).normalized()
				actor.rotation.y=atan2(heading.x,heading.z)
				break
			remaining-=length
	for i in range(walkers.size()):
		var actor:=walkers[i]
		var origin: Vector3=walker_anchors[i]
		walker_clock+=delta*.06
		actor.position=origin+Vector3(sin(walker_clock+float(i))*.9,0,cos(walker_clock+float(i))*.5)

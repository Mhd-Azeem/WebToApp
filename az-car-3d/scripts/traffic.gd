extends Node3D
const G = preload("res://scripts/geometry.gd")
const ROUTE: Array[Vector3] = [Vector3(-99.5,0,-963.5),Vector3(99.5,0,-963.5),Vector3(99.5,0,963.5),Vector3(-99.5,0,963.5)]
var player: VehicleBody3D
var enabled := false
var vehicles: Array[CharacterBody3D] = []
var targets: Array[int] = []
var speeds: Array[float] = []
var cruise: Array[float] = []
func set_enabled(value: bool) -> void:
	enabled=value
	if value and vehicles.is_empty(): _spawn()
	for body in vehicles:
		body.visible=value
		body.collision_layer=2 if value else 0
	set_physics_process(value)
func _ready() -> void:
	set_physics_process(false)
func _spawn() -> void:
	for i in range(8):
		var body := CharacterBody3D.new()
		body.collision_layer=2
		body.collision_mask=3
		add_child(body)
		var segment := i%4
		body.position=ROUTE[segment].lerp(ROUTE[(segment+1)%4],0.15+0.45*float(i/4))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size=Vector3(1.8,1.3,4.1)
		shape.shape=box
		shape.position.y=0.85
		body.add_child(shape)
		var paint := G.material("",Color.from_hsv(float(i)/8,0.4,0.7))
		G.box(body,Vector3(0,0.65,0),Vector3(1.8,0.7,4.1),paint)
		G.box(body,Vector3(0,1.15,-0.1),Vector3(1.5,0.6,2.0),G.material("",Color(0.07,0.13,0.18)))
		for x in [-0.95,0.95]:
			for z in [-1.3,1.3]: G.box(body,Vector3(x,0.3,z),Vector3(0.18,0.6,0.6),G.material("",Color(0.025,0.025,0.025)))
		vehicles.append(body)
		targets.append((segment+1)%4)
		speeds.append(0.0)
		cruise.append(10.0+float(i%3))
func _physics_process(delta: float) -> void:
	for i in range(vehicles.size()):
		var body := vehicles[i]
		var target := ROUTE[targets[i]]
		var offset := target-body.position
		offset.y=0
		if offset.length()<1.0:
			targets[i]=(targets[i]+1)%4
			offset=ROUTE[targets[i]]-body.position
			offset.y=0
		var direction := offset.normalized()
		body.rotation.y=atan2(direction.x,direction.z)
		var desired := minf(cruise[i],offset.length()/delta)
		# Cheap look-ahead and collision movement; no pathfinding or rigid-body AI.
		var query := PhysicsRayQueryParameters3D.create(body.position+Vector3(0,0.8,0)+direction*2.2,body.position+Vector3(0,0.8,0)+direction*(5+speeds[i]))
		query.exclude=[body.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): desired=0
		if is_instance_valid(player) and body.position.distance_to(player.position)<9: desired=0
		speeds[i]=move_toward(speeds[i],desired,delta*(8 if desired==0 else 2))
		body.move_and_collide(direction*speeds[i]*delta)

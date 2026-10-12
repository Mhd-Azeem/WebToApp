extends Node3D
const Coupe = preload("res://scripts/coupe_visual.gd")
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
		var kind: String=["sedan","hatchback","suv","van","bus"][i%5]
		var box := BoxShape3D.new()
		box.size=Vector3(2.1,2.4,6.3) if kind=="bus" else Vector3(1.8,1.8 if kind in ["suv","van"] else 1.3,4.1)
		shape.shape=box
		shape.position.y=0.85
		body.add_child(shape)
		var color := Color.from_hsv(float(i)/8,0.70,0.82)
		var model := Coupe.traffic_model(body,color,kind)
		model.set_meta("vehicle_type",kind)
		model.position.y=-0.10
		model.set_meta("coupe",true)
		model.set_meta("paint",color)
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
		# Slow before route turns and retain speed-dependent stopping distance.
		if offset.length()<18:
			desired=minf(desired,4.0)
			var phase := fmod(Time.get_ticks_msec()/1000.0,24.0)
			var green := phase<10 if absf(direction.z)>0.5 else phase>=12 and phase<22
			if not green and offset.length()>5: desired=minf(desired,maxf(0,(offset.length()-12)/1.5))
		for other in vehicles:
			if other==body: continue
			var gap := other.position-body.position
			var ahead := gap.dot(direction)
			var lateral := absf(gap.dot(Vector3(-direction.z,0,direction.x)))
			if ahead>0 and lateral<2.3:
				desired=minf(desired,maxf(0,(ahead-7.0)/1.6))
		# Cheap look-ahead and collision movement; no pathfinding or rigid-body AI.
		var query := PhysicsRayQueryParameters3D.create(body.position+Vector3(0,0.8,0)+direction*2.2,body.position+Vector3(0,0.8,0)+direction*(7+speeds[i]*1.5))
		query.exclude=[body.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): desired=0
		if is_instance_valid(player) and body.position.distance_to(player.position)<9: desired=0
		speeds[i]=move_toward(speeds[i],desired,delta*(8 if desired==0 else 2))
		body.move_and_collide(direction*speeds[i]*delta)


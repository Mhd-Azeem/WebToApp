extends Node3D

const Coupe = preload("res://scripts/coupe_visual.gd")
const G = preload("res://scripts/geometry.gd")
const Signals = preload("res://scripts/traffic_signal.gd")
const Audio = preload("res://scripts/engine_audio.gd")
const KINDS := ["sedan","hatchback","suv","van","bus","truck","motorcycle","tuk-tuk"]
const MAIN_X := [-96.0, 0.0, 96.0]
const LOOP_Z := [-960.0,-640.0,-320.0,-160.0,0.0,160.0,320.0,640.0,960.0]

var player: VehicleBody3D
var enabled := false
var density := 8
var vehicles: Array[CharacterBody3D] = []
var routes: Array[PackedVector3Array] = []
var targets: Array[int] = []
var speeds: Array[float] = []
var lanes: Array[float] = []
var pass_time: Array[float] = []
var passing: Array[bool] = []
var audio: AudioStreamPlayer3D
var sound_elapsed := 0.0
var sound_gain := 0.65

func _ready() -> void:
	set_physics_process(false)
	audio = AudioStreamPlayer3D.new()
	audio.stream = Audio._stream("engine0", 54, 1.0, true)
	audio.max_distance = 45
	audio.unit_size = 7
	audio.volume_db = -28
	add_child(audio)

func set_enabled(value: bool) -> void:
	enabled = value
	if enabled: _populate()
	for i in range(vehicles.size()):
		_activate(i, enabled and i < density)
	if not enabled: audio.stop()
	set_physics_process(enabled)

func set_density(value: int) -> void:
	density = clampi(value, 0, 10)
	set_enabled(enabled)

func _activate(index: int, active: bool) -> void:
	var body := vehicles[index]
	if active and not body.visible: _recycle(index)
	body.visible = active
	body.collision_layer = 2 if active else 0

func _populate() -> void:
	while vehicles.size() < density:
		var i := vehicles.size()
		var kind: String = KINDS[i % KINDS.size()]
		var body := CharacterBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 3
		body.hide()
		add_child(body)
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = {
			"bus": Vector3(2.2,2.5,6.3), "truck": Vector3(2.0,2.55,5.3),
			"motorcycle": Vector3(0.7,1.2,2.2), "tuk-tuk": Vector3(1.35,1.85,2.6),
			"van": Vector3(1.85,2,4.2), "suv": Vector3(1.85,1.8,4.1),
		}.get(kind,Vector3(1.85,1.3,4.1))
		shape.shape = bounds
		shape.position.y = bounds.size.y * 0.5 + 0.05
		body.add_child(shape)
		var color := Color.from_hsv(float(i) / 10.0,0.70,0.82)
		var model := Coupe.traffic_model(body,color,kind)
		model.set_meta("vehicle_type",kind)
		model.position.y = -0.10
		model.set_meta("coupe",true)
		model.set_meta("paint",color)
		vehicles.append(body)
		routes.append(PackedVector3Array())
		targets.append(0)
		speeds.append(0)
		lanes.append(4.6)
		pass_time.append(0)
		passing.append(false)

func _recycle(index: int) -> void:
	var focus := player.position if is_instance_valid(player) else Vector3(0,0,120)
	var region := 0
	for j in range(1,LOOP_Z.size()-1):
		if absf(focus.z-LOOP_Z[j]) < absf(focus.z-LOOP_Z[region]): region=j
	var north: float = LOOP_Z[maxi(0,region-1)]
	var south: float = LOOP_Z[mini(region+1,LOOP_Z.size()-1)]
	var x1: float = MAIN_X[0] if index%2==0 else MAIN_X[1]
	var x2: float = MAIN_X[1] if index%2==0 else MAIN_X[2]
	var corners := PackedVector3Array([Vector3(x1,0,north),Vector3(x2,0,north),Vector3(x2,0,south),Vector3(x1,0,south)])
	if index%3==0: corners.reverse()
	routes[index] = corners
	var preferred := index % 4
	var position_3d := Vector3.ZERO
	for attempt in range(16):
		var segment := (preferred + attempt) % 4
		var a := corners[segment]
		var b := corners[(segment+1)%4]
		var direction := (b-a).normalized()
		var progress := clampf((focus-a).dot(direction) + (42.0+14.0*floorf(index/4.0)) * (1 if attempt < 8 else -1), 14, a.distance_to(b)-14)
		position_3d = a + direction*progress + _left(direction)*4.6
		targets[index] = (segment+1)%4
		if position_3d.distance_to(focus)<28: continue
		var clear := true
		for other in vehicles:
			if other!=vehicles[index] and other.visible and other.position.distance_to(position_3d)<11:
				clear=false
				break
		if clear: break
	var current := routes[index]
	var direction := (current[targets[index]] - current[posmod(targets[index]-1,4)]).normalized()
	vehicles[index].position = position_3d
	vehicles[index].rotation.y = atan2(direction.x,direction.z)
	speeds[index] = 0
	lanes[index] = 4.6
	pass_time[index] = 0
	passing[index] = false

static func _left(direction: Vector3) -> Vector3:
	return Vector3(direction.z,0,-direction.x)

func _physics_process(delta: float) -> void:
	var closest := -1
	var nearest_distance := 45.0
	for i in range(density):
		var body := vehicles[i]
		var distance := body.position.distance_to(player.position) if is_instance_valid(player) else 0.0
		if distance > 300:
			_recycle(i)
			continue
		if distance < nearest_distance:
			closest = i
			nearest_distance = distance
		_drive(i,delta)
	sound_elapsed += delta
	if sound_elapsed < 0.12: return
	sound_elapsed = 0
	if closest < 0 or sound_gain <= 0:
		audio.stop()
		return
	audio.position = vehicles[closest].position + Vector3.UP
	audio.pitch_scale = 0.65 + speeds[closest]*0.07
	audio.volume_db = -23 + linear_to_db(sound_gain)
	if not audio.playing: audio.play()

func _drive(i: int, delta: float) -> void:
	var body := vehicles[i]
	var route := routes[i]
	var end := route[targets[i]]
	var start := route[posmod(targets[i]-1,4)]
	var heading := (end-start).normalized()
	var side := _left(heading)
	var remaining := (end-body.position).dot(heading)
	var city_signal := INF
	if absf(heading.z)>0.5:
		for z in [-160.0,-80.0,0.0,80.0,160.0]:
			var gap: float = (z-body.position.z)*heading.z
			if gap > 5 and gap < remaining+1: city_signal = minf(city_signal,gap)
	elif absf(end.z)<=160: city_signal = remaining
	var green := Signals.permits(absf(heading.z)>0.5)
	var gap_ahead := INF
	var pass_clear := true
	for j in range(density):
		if j==i: continue
		var offset := vehicles[j].position-body.position
		var ahead := offset.dot(heading)
		var lateral := (vehicles[j].position-start).dot(side)
		if ahead>0 and absf(lateral-lanes[i])<2.25: gap_ahead=minf(gap_ahead,ahead)
		if ahead>-13 and ahead<32 and absf(lateral-1.7)<2.4: pass_clear=false
	# Use the travel lane's inner half for a short pass. Never cross the center line.
	var can_pass := remaining>43 and city_signal>33 and pass_clear and pass_time[i]<3
	if not passing[i] and can_pass and gap_ahead>8 and gap_ahead<19 and i%3!=1:
		passing[i]=true
	elif passing[i] and (not can_pass or pass_time[i]>2.9):
		passing[i]=false
	pass_time[i] = pass_time[i]+delta if passing[i] else maxf(0,pass_time[i]-delta*0.5)
	lanes[i] = move_toward(lanes[i],1.7 if passing[i] else 4.6,delta*1.8)
	var next_heading := (route[(targets[i]+1)%4]-end).normalized()
	var destination := end + (side+_left(next_heading))*lanes[i]
	if body.position.distance_squared_to(destination)<1.5:
		targets[i]=(targets[i]+1)%4
		return
	var motion := destination-body.position
	if remaining>12:
		motion = heading*12 + side*(lanes[i]-(body.position-start).dot(side))
	var direction := motion.normalized()
	var desired := 8.0 + i%4*1.6
	if remaining<16: desired=minf(desired,4.0)
	if not green and city_signal > 5 and city_signal < 28:
		desired=minf(desired,maxf(0,(city_signal-12)/1.4))
	if not passing[i]:
		desired=minf(desired,maxf(0,(gap_ahead-6.0)*0.65))
	var origin := body.position+Vector3.UP*0.8
	var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*(4.8+speeds[i]*0.8),3)
	query.exclude=[body.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): desired=0
	speeds[i]=move_toward(speeds[i],desired,delta*(7 if desired<speeds[i] else 2.5))
	body.rotation.y=lerp_angle(body.rotation.y,atan2(direction.x,direction.z),minf(1,delta*10))
	if body.move_and_collide(direction * minf(motion.length(), speeds[i]*delta)):
		speeds[i] = 0

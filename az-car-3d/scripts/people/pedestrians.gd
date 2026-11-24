extends Node3D

const HumanModel = preload("res://scripts/people/human_model.gd")
const Signals = preload("res://scripts/traffic_signal.gd")
const LIMITS := [2,4,6,9]
const PEOPLE := [
	["Nirmala","shopkeeper","The tea shop is on the corner near the crossing.",Color(1.0,0.97,0.88),0.95],
	["Arun","commuter","Head north along this street for the hill road.",Color(0.76,0.64,0.54),1.0],
	["Shalini","commuter","The bus shelter is near the market block.",Color(0.86,0.72,0.67),1.04],
	["Faris","delivery worker","The garage is beside the turning near the shops.",Color(0.93,0.81,0.65),0.97],
	["Saroja","resident","The promenade runs along the west side of town.",Color(0.81,0.66,0.58),0.94],
	["Kasun","commuter","Follow the coast road south for the service stop.",Color(1.0,0.92,0.83),1.07],
	["Ayesha","resident","The road east leads to the paddy fields.",Color(0.92,0.79,0.74),1.02],
	["Ruwan","shopkeeper","The repair shop is close to the main road.",Color(0.78,0.69,0.62),1.06],
	["Fathima","commuter","The crossing is just past the next shelter.",Color(0.96,0.82,0.78),0.98],
]

var focus: Node3D
var car: VehicleBody3D
var graphics_tier := 1
var daylight := 1.0
var raining := false
var area_tick := 0.0
var actors: Array[Dictionary] = []
var panel: PanelContainer
var dialogue: Label
var active_index := -1
var rider := -1
var mobility: Node
var relationships := ConfigFile.new()
var population_center := Vector2i(999,999)

func setup(layer: CanvasLayer, vehicle: VehicleBody3D) -> void:
	car=vehicle
	focus=vehicle
	relationships.load("user://az_pedestrians.cfg")
	panel=PanelContainer.new()
	panel.position=Vector2(450,132)
	panel.custom_minimum_size=Vector2(380,0)
	layer.add_child(panel)
	var contents := VBoxContainer.new()
	panel.add_child(contents)
	dialogue=Label.new()
	dialogue.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dialogue.custom_minimum_size=Vector2(380,68)
	contents.add_child(dialogue)
	for title in ["Greet","Ask for directions","Talk","Invite as passenger","Close"]:
		var button := Button.new()
		button.text=title
		button.custom_minimum_size.y=42
		button.pressed.connect(func(): respond(title))
		contents.add_child(button)
	panel.hide()

func _add_actor(index: int) -> void:
	var body := CharacterBody3D.new()
	body.collision_layer=8
	body.collision_mask=1
	body.floor_snap_length=0.40
	add_child(body)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.24
	capsule.height=1.60
	shape.shape=capsule
	shape.position.y=0.8
	body.add_child(shape)
	var model := HumanModel.new()
	body.add_child(model)
	model.dress(1-index%2,PEOPLE[index][3],(2 if index%4==0 else 3) if index%2==0 else (0 if index%4==1 else 1))
	model.scale=Vector3(1.0,PEOPLE[index][4],1.0)
	actors.append({"body":body,"model":model,"route":PackedVector3Array(),"target":0,"wait":0.0,"stuck":0.0})

func _unspawn(actor: Dictionary) -> void:
	actor.body.visible=false
	actor.body.collision_layer=0
	actor.model.animations.pause()

func _place(index: int, cell: Vector2i) -> void:
	var actor := actors[index]
	var street := clampf(roundf((cell.x*80.0+40.0)/96.0)*96.0,-96,96)
	var cross := clampf((cell.y+1)*80.0,-160,160)
	var sidewalk := (-1.0 if index%2==0 else 1.0)*9.1
	var parallel := street+sidewalk
	var longitudinal := cross+(1.0 if cross<160 else -1.0)*(16.0+index*3.4)
	if longitudinal>163: longitudinal=cross-16.0-index*3.4
	var route := PackedVector3Array([
		Vector3(parallel,0.24,longitudinal),
		Vector3(parallel,0.24,clampf(longitudinal+(-14.0 if index%3==0 else 14.0),-167,167)),
	])
	if index%3==1:
		var end_z := cross+(12.8 if longitudinal>cross else -12.8)
		var near_corner := Vector3(parallel,0.24,end_z)
		var far_corner := Vector3(street-sidewalk,0.24,end_z)
		route=PackedVector3Array([route[0],near_corner,far_corner,Vector3(street-sidewalk,0.24,longitudinal),far_corner,near_corner])
	actor.route=route
	actor.target=1
	actor.wait=index*0.24
	actor.stuck=0.0
	actor.body.position=route[0]
	actor.body.velocity=Vector3.ZERO
	actor.body.collision_layer=8
	actor.body.visible=true
	actor.model.animations.play()

func _refresh() -> void:
	var p := focus.position
	var in_city := absf(p.x)<131 and absf(p.z)<172 and p.y<4
	var count: int=LIMITS[clampi(graphics_tier,0,3)] if in_city else 0
	if daylight<0.25 or raining: count=maxi(0,count-2)
	var cell := Vector2i(floori(p.x/80.0),floori(p.z/80.0))
	for index in range(count):
		if index>=actors.size(): _add_actor(index)
		if index==rider: continue
		var actor := actors[index]
		if not actor.body.visible or (cell!=population_center and actor.body.position.distance_to(p)>61.0):
			_place(index,cell)
	for index in range(count,actors.size()):
		if index!=rider and actors[index].body.visible: _unspawn(actors[index])
	population_center=cell
	if active_index>=0 and (not actors[active_index].body.visible or actors[active_index].body.position.distance_to(p)>4.5):
		respond("Close")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(focus): return
	area_tick+=delta
	if area_tick>=0.45:
		area_tick=0
		_refresh()
	for i in range(actors.size()):
		if i==rider:
			actors[i].body.global_position=car.to_global(mobility.PASSENGER)
			actors[i].model.rotation.y=car.global_rotation.y
		elif actors[i].body.visible: _move(i,delta)

func _move(i: int, delta: float) -> void:
	var actor := actors[i]
	var body: CharacterBody3D=actor.body
	var model: Node3D=actor.model
	var route: PackedVector3Array=actor.route
	var offset := route[actor.target]-body.position
	offset.y=0
	var across: bool=absf(offset.x)>2 and route.size()==6 and actor.target in [2,5]
	var motion := offset.normalized()
	var car_gap := Vector3(car.position.x-body.position.x,0,car.position.z-body.position.z)
	var alarm: bool= car_gap.length()<9.0 and (car.horn>0.0 or car.linear_velocity.length()>6.0)
	if i==active_index:
		var speaker := focus.position-body.position
		model.rotation.y=lerp_angle(model.rotation.y,atan2(speaker.x,speaker.z),delta*8)
		model.play("Idle_Talking_Loop")
		return
	if across and absf(body.position.x-route[actor.target-1].x)<1.7 and (Signals.permits(true) or car_gap.length()<6):
		model.play("Idle_Loop")
		return
	if offset.length()<0.65:
		actor.target=(actor.target+1)%route.size()
		actor.wait=1.4+(i%3)*0.60
	if alarm:
		actor.wait=0.0
		motion=-car_gap.normalized()
	elif actor.wait>0:
		actor.wait=maxf(0,actor.wait-delta)
		model.play("Idle_FoldArms_Loop" if i%3==1 else "Idle_Loop")
		return
	for other in actors:
		if other==actor or not other.body.visible: continue
		var gap: Vector3=other.body.position-body.position
		gap.y=0
		if gap.length_squared()<1.6 and gap.dot(motion)>0.12:
			motion=(motion+Vector3(motion.z,0,-motion.x)*0.65).normalized()
	var speed := 2.5 if alarm else 1.10+(i%4)*0.13
	body.velocity=Vector3(motion.x*speed,maxf(-8,body.velocity.y-12*delta),motion.z*speed)
	body.move_and_slide()
	model.rotation.y=lerp_angle(model.rotation.y,atan2(motion.x,motion.z),delta*9)
	model.play("Jog_Fwd_Loop" if alarm else ("Walk_Formal_Loop" if i%3==1 else "Walk_Loop"))
	if body.get_real_velocity().length()<0.12:
		actor.stuck+=delta
		if actor.stuck>1.1:
			actor.target=(actor.target+1)%route.size()
			actor.stuck=0.0
	else: actor.stuck=0.0

func nearby() -> int:
	var nearest := -1
	var best := 2.7
	for i in range(actors.size()):
		if i==rider or not actors[i].body.visible: continue
		var distance: float=actors[i].body.position.distance_to(focus.position)
		if distance<best:
			best=distance
			nearest=i
	return nearest

func interact() -> bool:
	var i := nearby()
	if i<0: return false
	if car.horn>0.0:
		dialogue.text="They step away from the noise."
		panel.show()
		return true
	active_index=i
	dialogue.text="%s · %s" % [PEOPLE[i][0],PEOPLE[i][1]]
	panel.show()
	return true

func respond(action: String) -> void:
	if action=="Close":
		active_index=-1
		panel.hide()
		return
	if active_index<0: return
	var person: Array=PEOPLE[active_index]
	var points := int(relationships.get_value("friendship",person[0],0))
	if action=="Invite as passenger":
		_invite(points)
		return
	match action:
		"Greet": dialogue.text="%s: %s" % [person[0],"Good to see you again." if points>=2 else "Hello. How's your day going?"]
		"Ask for directions": dialogue.text="%s: %s" % [person[0],person[2]]
		"Talk":
			if raining and person[1]=="commuter":
				dialogue.text="%s: I'm heading for shelter. Let's talk later." % person[0]
				return
			dialogue.text="%s: %s" % [person[0],"The shops stay busy until evening." if person[1]=="shopkeeper" else "It's usually quieter here after sunset."]
	relationships.set_value("friendship",person[0],mini(5,points+1))
	relationships.save("user://az_pedestrians.cfg")

func _invite(points: int) -> void:
	var name: String=PEOPLE[active_index][0]
	if points<2:
		dialogue.text="%s: Maybe after we get to know each other." % name
		return
	if rider>=0 or not mobility.walking or car.linear_velocity.length()>1.25:
		dialogue.text="%s: The passenger seat needs to be free and the car parked." % name
		return
	var actor := actors[active_index]
	if actor.body.position.distance_to(car.position)>7.0:
		dialogue.text="%s: Let's meet closer to the car." % name
		return
	rider=active_index
	active_index=-1
	mobility.passenger_occupied=true
	actor.body.collision_layer=0
	actor.body.global_position=car.to_global(mobility.PASSENGER)
	actor.model.play("Sitting_Idle_Loop")
	for mesh: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false): mesh.layers=4
	dialogue.text="%s joined you. Shift+G to let them out when stopped." % name

func drop_passenger() -> bool:
	if rider<0 or car.linear_velocity.length()>1.25: return false
	var point: Vector3=mobility.exit_position(-1)
	if point==Vector3.INF: return false
	var actor := actors[rider]
	for mesh: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false): mesh.layers=1
	actor.body.global_position=point
	actor.body.collision_layer=8
	actor.model.play("Idle_Loop")
	rider=-1
	mobility.passenger_occupied=false
	return true

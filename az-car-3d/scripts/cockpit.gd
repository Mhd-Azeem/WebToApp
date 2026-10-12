extends Node3D
## Original modeled interior. All dimensions are metres in driver camera space.
const G = preload("res://scripts/geometry.gd")
var vehicle: VehicleBody3D
var view_camera: Camera3D
var wheel: Node3D
var horn_target: Node3D
var light_stalk: Node3D
var wiper_stalk: Node3D
var wiper_mode := 0
var headlights := false
var sweep := 0.0
var clock := 0.0
var blades: Array[Node3D] = []
var mirrors: Array[SubViewport] = []
var mirror_cameras: Array[Camera3D] = []
var mirror_elapsed := 0.0
var low_quality := true
var cluster: Node2D
var lamps: Array[SpotLight3D] = []
var owner_finger := -1
var interaction := ""
var press_y := 0.0
var initial_mode := 0
var press_x := 0.0
var hazard_target: Node3D

func _ready() -> void:
	var leather := G.material("",Color(0.045,0.052,0.059))
	var trim := G.material("",Color(0.24,0.27,0.29))
	trim.metallic=0.65
	trim.roughness=0.34
	var rubber := G.material("",Color(0.015,0.019,0.024))
	# Tapered eight-sided cross sections, rather than a rectangular dashboard.
	var dash := G.profile_mesh(self,[[-1.40,1.45,-0.65,-0.31],[-1.12,1.44,-0.70,-0.29],[-0.92,1.35,-0.73,-0.34],[-0.79,1.26,-0.70,-0.40]],leather)
	dash.position.x=0.38
	G.profile_mesh(self,[[-1.09,0.34,-0.43,-0.20],[-0.91,0.34,-0.47,-0.21],[-0.84,0.30,-0.47,-0.27]],rubber)
	for x in [-0.66,0.47,0.76,1.48]:
		G.box(self,Vector3(x,-0.40,-0.77),Vector3(0.23,0.12,0.035),trim)
		G.box(self,Vector3(x,-0.40,-0.746),Vector3(0.21,0.095,0.022),rubber)
		for i in range(4):
			G.box(self,Vector3(x,-0.434+i*0.023,-0.727),Vector3(0.20,0.008,0.018),leather)
	# Passenger stack, screen, knobs and lower console.
	G.profile_mesh(self,[[-0.87,0.24,-1.1,-0.39],[-0.70,0.22,-1.07,-0.43],[-0.55,0.20,-1.0,-0.69]],leather).position.x=0.65
	G.box(self,Vector3(0.58,-0.26,-0.82),Vector3(0.35,0.19,0.025),trim)
	G.box(self,Vector3(0.58,-0.26,-0.80),Vector3(0.32,0.16,0.018),rubber)
	var screen := G.label(self,"AZ CONNECT\nCOLOMBO  •  24°C",Vector3(0.58,-0.26,-0.78),22)
	screen.pixel_size=0.0016
	screen.outline_size=0
	screen.modulate=Color(0.38,0.8,0.9)
	for x in [0.52,0.65,0.78]: cylinder(self,Vector3(x,-0.64,-0.94),0.033,0.023,trim)
	hazard_target=cylinder(self,Vector3(0.40,-0.37,-0.77),0.018,0.015,G.material("",Color(0.70,0.08,0.04)))
	for side in [-1.0,1.0]:
		var x := -0.86 if side<0 else 1.67
		var pillar := G.box(self,Vector3(x,0.13,-1.03),Vector3(0.085,1.15,0.13),leather)
		pillar.rotation.z=side*0.22
		G.profile_mesh(self,[[-1.02,0.09,-0.85,-0.32],[-0.55,0.11,-0.92,-0.38],[0.15,0.09,-0.95,-0.47]],leather).position.x=x
		G.box(self,Vector3(x,-0.59,-0.36),Vector3(0.10,0.06,0.40),trim)
	G.box(self,Vector3(0.4,0.69,-1.10),Vector3(2.5,0.08,0.15),leather)
	G.box(self,Vector3(0.40,0.38,-1.05),Vector3(0.28,0.10,0.045),rubber)
	# Natural 370 mm wheel; tilted mounting and rotation are separate transforms.
	var mount := Node3D.new()
	add_child(mount)
	mount.position=Vector3(-0.06,-0.26,-0.78)
	mount.rotation.x=deg_to_rad(-16)
	cylinder(mount,Vector3(0,0,-0.12),0.052,0.25,rubber)
	wheel=Node3D.new()
	mount.add_child(wheel)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius=0.157
	ring.outer_radius=0.185
	ring.rings=48
	ring.ring_segments=12
	rim.mesh=ring
	rim.rotation.x=PI/2
	rim.material_override=leather
	wheel.add_child(rim)
	for a in [0.0,PI,PI/2]:
		var spoke := G.box(wheel,Vector3(cos(a)*0.096,-sin(a)*0.096,0),Vector3(0.13,0.041,0.028),trim)
		spoke.rotation.z=-a
	horn_target=cylinder(wheel,Vector3(0,0,0.015),0.071,0.035,leather)
	var badge := G.label(wheel,"AZ",Vector3(0,0,0.036),20)
	badge.pixel_size=0.0014
	badge.outline_size=0
	light_stalk=stalk(mount,Vector3(-0.065,0.015,-0.095),-1,rubber)
	wiper_stalk=stalk(mount,Vector3(0.065,0.015,-0.095),1,rubber)
	for x in [-0.18,-0.04,0.10]:
		var pedal := G.box(self,Vector3(x,-0.99,-0.84),Vector3(0.075,0.12,0.025),trim)
		pedal.rotation.x=-0.3
		for j in range(4): G.box(pedal,Vector3(0,-0.04+j*0.025,0.016),Vector3(0.06,0.006,0.004),rubber)
	# Instrument texture is attached to the cluster face.
	var panel := SubViewport.new()
	panel.size=Vector2i(768,320)
	panel.disable_3d=true
	panel.transparent_bg=true
	add_child(panel)
	cluster=Node2D.new()
	cluster.set_script(preload("res://scripts/ui/cluster.gd"))
	cluster.vehicle=vehicle
	cluster.cockpit=self
	panel.add_child(cluster)
	surface(self,Vector3(0,-0.205,-0.825),Vector2(0.57,0.235),panel.get_texture(),false)
	for side in [-1.0,1.0]:
		var housing := G.box(self,Vector3(-0.78 if side<0 else 0.90,-0.16,-1.28),Vector3(0.27,0.16,0.08),rubber)
		var vp := SubViewport.new()
		vp.world_3d=vehicle.get_world_3d()
		vp.audio_listener_enable_3d=false
		vp.render_target_update_mode=SubViewport.UPDATE_DISABLED
		add_child(vp)
		var cam := Camera3D.new()
		cam.cull_mask=5
		cam.fov=65
		cam.far=120
		vp.add_child(cam)
		cam.current=true
		mirrors.append(vp)
		mirror_cameras.append(cam)
		surface(housing,Vector3(0,0,0.045),Vector2(0.235,0.125),vp.get_texture(),true)
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position=Vector3(side*0.34,-0.29,-1.43)
		G.box(pivot,Vector3(0,0.21,0),Vector3(0.013,0.42,0.015),rubber)
		G.box(pivot,Vector3(0,0.40,0),Vector3(0.026,0.22,0.02),rubber)
		blades.append(pivot)
		var lamp := SpotLight3D.new()
		vehicle.add_child(lamp)
		lamp.position=Vector3(side*0.64,0.62,1.75)
		lamp.rotation_degrees=Vector3(7,180,0)
		lamp.spot_range=42
		lamp.spot_angle=35
		lamp.light_energy=2
		lamp.visible=false
		lamps.append(lamp)
	# All camera-space geometry is invisible to mirror cameras (layer 2).
	for mesh in find_children("*","GeometryInstance3D",true,false): mesh.layers=2
	set_quality(low_quality)

func cylinder(parent: Node3D,pos: Vector3,radius: float,length: float,mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=length
	mesh.radial_segments=32
	node.mesh=mesh
	node.material_override=mat
	node.position=pos
	node.rotation.x=PI/2
	parent.add_child(node)
	return node

func stalk(parent: Node3D,pos: Vector3,side: float,mat: Material) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	node.position=pos
	G.box(node,Vector3(side*0.09,0,0),Vector3(0.18,0.014,0.015),mat)
	G.box(node,Vector3(side*0.18,0,0),Vector3(0.048,0.031,0.032),mat)
	return node

func surface(parent: Node3D,pos: Vector3,extent: Vector2,texture: Texture2D,flip: bool) -> void:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size=extent
	node.mesh=quad
	node.position=pos
	var mat := StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture=texture
	if flip:
		mat.uv1_scale=Vector3(-1,1,1)
		mat.uv1_offset=Vector3(1,0,0)
	node.material_override=mat
	parent.add_child(node)

func set_quality(low: bool) -> void:
	low_quality=low
	for vp in mirrors: vp.size=Vector2i(192,112) if low else Vector2i(384,224)

func _process(delta: float) -> void:
	if not is_instance_valid(wheel): return
	wheel.rotation.z=lerp_angle(wheel.rotation.z,-vehicle.steering*7.5,1-exp(-delta*14))
	light_stalk.rotation.z=lerpf(light_stalk.rotation.z,0.22 if headlights else 0.0,1-exp(-delta*14))
	wiper_stalk.rotation.z=lerpf(wiper_stalk.rotation.z,-wiper_mode*0.12,1-exp(-delta*14))
	clock+=delta
	for lamp in lamps:
		lamp.light_energy=3.0 if vehicle.high_beams else 2.0
		lamp.spot_range=70.0 if vehicle.high_beams else 42.0
	if vehicle.turn_signal!=0 and absf(vehicle.steering)>0.20: set_meta("indicator_turned",true)
	if has_meta("indicator_turned") and absf(vehicle.steering)<0.03:
		vehicle.turn_signal=0
		remove_meta("indicator_turned")
	# Complete a sweep and park, including when switched off mid-cycle.
	var active := wiper_mode>=2 or (wiper_mode==1 and fmod(clock,3.5)<1.2)
	if active or sweep>0:
		sweep+=delta*(1.8 if wiper_mode==3 else 1.0)
		if sweep>=1: sweep=0
	for i in range(blades.size()): blades[i].rotation.z=-PI/2+sin(sweep*PI)*1.10
	mirror_elapsed+=delta
	for i in range(mirrors.size()):
		var cam := mirror_cameras[i]
		var side := 1.0 if i==0 else -1.0
		cam.global_position=vehicle.to_global(Vector3(side*1.05,1.25,0.4))
		cam.look_at(cam.global_position-vehicle.global_basis.z*15+vehicle.global_basis.x*side*3,vehicle.global_basis.y)
		mirrors[i].render_target_update_mode=SubViewport.UPDATE_ONCE if visible and mirror_elapsed>=(0.1 if low_quality else 1.0/30) else SubViewport.UPDATE_DISABLED
	if mirror_elapsed>=(0.1 if low_quality else 1.0/30): mirror_elapsed=0
	if not visible and owner_finger!=-1: cancel()

func cancel() -> void:
	if interaction=="horn": vehicle.horn=0
	interaction=""
	owner_finger=-1

func begin(pos: Vector2,index: int) -> bool:
	if owner_finger!=-1 or not visible: return false
	var nearest := 42.0
	for entry in [[horn_target,"horn"],[light_stalk,"lights"],[wiper_stalk,"wipers"],[hazard_target,"hazard"]]:
		var target: Node3D=entry[0]
		var p := target.global_position
		if entry[1] in ["lights","wipers"]: p=target.to_global(Vector3(-0.18 if entry[1]=="lights" else 0.18,0,0))
		var distance := view_camera.unproject_position(p).distance_to(pos)
		if distance<nearest:
			nearest=distance
			interaction=entry[1]
	if interaction=="": return false
	owner_finger=index
	press_y=pos.y
	press_x=pos.x
	initial_mode=wiper_mode
	if interaction=="horn": vehicle.horn=1
	elif interaction=="hazard": vehicle.hazards=not vehicle.hazards
	elif interaction=="lights":
		headlights=not headlights
		for lamp in lamps: lamp.visible=headlights
	else: wiper_mode=(wiper_mode+1)%4
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if begin(event.position,event.index): get_viewport().set_input_as_handled()
		elif event.index==owner_finger:
			cancel()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==owner_finger:
		drag(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			if begin(event.position,-2): get_viewport().set_input_as_handled()
		elif owner_finger==-2:
			cancel()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and owner_finger==-2:
		drag(event.position)
		get_viewport().set_input_as_handled()

func drag(pos: Vector2) -> void:
	if interaction=="wipers" and absf(pos.y-press_y)>15:
		wiper_mode=clampi(initial_mode+roundi((press_y-pos.y)/35),0,3)
	elif interaction=="lights" and absf(pos.y-press_y)>15:
		headlights=pos.y<press_y
		vehicle.high_beams=press_y-pos.y>75
		for lamp in lamps: lamp.visible=headlights
	if interaction=="lights" and absf(pos.x-press_x)>40:
		vehicle.turn_signal=-1 if pos.x<press_x else 1

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(vehicle): cancel()

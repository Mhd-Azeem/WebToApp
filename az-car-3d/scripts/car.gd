extends VehicleBody3D
const G = preload("res://scripts/geometry.gd")
const Transmission = preload("res://scripts/transmission.gd")
var transmission := Transmission.new()
var gas := 0.0
var pedal_brake := 0.0
var turn := 0.0
var clutch_pedal := 0.0
var signed_speed := 0.0
var wheels: Array[VehicleWheel3D] = []
var visual: Node3D

func _ready() -> void:
	mass = 1250
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0,0.1,0)
	var shape := CollisionShape3D.new()
	var hull := BoxShape3D.new()
	hull.size=Vector3(1.78,0.9,4.0)
	shape.shape=hull
	shape.position.y=0.8
	add_child(shape)
	visual = Node3D.new()
	add_child(visual)
	# Original performance-coupe geometry: long sculpted hood, sloped glass,
	# broad haunches, rear diffuser, spoiler, split grille and detailed alloy wheels.
	var paint := G.material("",Color(0.19,0.25,0.30))
	paint.metallic=0.65
	paint.roughness=0.25
	var trim := G.material("",Color(0.025,0.035,0.045))
	var chrome := G.material("",Color(0.53,0.60,0.66))
	chrome.metallic=0.85
	chrome.roughness=0.27
	G.profile_mesh(visual,[[-2.17,0.79,0.48,0.75],[-1.98,0.98,0.47,0.96],[-1.40,1.0,0.44,1.02],[-0.70,0.94,0.46,1.04],[0.5,0.94,0.46,1.03],[1.20,1.0,0.44,0.98],[1.85,0.93,0.47,0.85],[2.22,0.82,0.49,0.77]],paint)
	var glass := G.material("",Color(0.055,0.10,0.135))
	glass.metallic=0.2
	glass.roughness=0.16
	G.profile_mesh(visual,[[-1.39,0.81,1.00,1.08],[-0.86,0.70,1.01,1.43],[0.10,0.71,1.01,1.44],[0.99,0.83,1.0,1.08]],glass)
	G.profile_mesh(visual,[[-0.89,0.69,1.41,1.47],[-0.67,0.70,1.42,1.48],[-0.08,0.70,1.42,1.48],[0.16,0.68,1.41,1.47]],paint)
	for side in [-1.0,1.0]:
		G.box(visual,Vector3(side*0.94,0.51,-0.1),Vector3(0.12,0.09,2.65),trim)
		G.box(visual,Vector3(side*0.83,1.24,-0.60),Vector3(0.055,0.43,0.08),paint)
		G.box(visual,Vector3(side*0.89,1.05,0),Vector3(0.045,0.05,2),chrome)
		G.box(visual,Vector3(side*1.04,1.05,0.63),Vector3(0.26,0.13,0.21),paint)
		G.box(visual,Vector3(side*0.965,0.99,-0.28),Vector3(0.035,0.035,0.17),chrome)
		# Paired slim LED headlights and sculpted front intake / split grille.
		G.box(visual,Vector3(side*0.65,0.81,2.12),Vector3(0.46,0.10,0.10),trim)
		var led := G.material("",Color(0.84,0.93,1))
		led.emission_enabled=true
		led.emission=Color(0.40,0.59,0.78)
		G.box(visual,Vector3(side*0.65,0.83,2.18),Vector3(0.42,0.022,0.022),led)
		G.box(visual,Vector3(side*0.21,0.66,2.21),Vector3(0.32,0.25,0.032),trim)
		for bar in range(4): G.box(visual,Vector3(side*0.21-0.10+bar*0.065,0.66,2.24),Vector3(0.014,0.21,0.018),chrome)
		G.box(visual,Vector3(side*0.69,0.53,2.11),Vector3(0.27,0.13,0.08),trim)
		# Continuous rear-light sections, diffuser and four exhaust tips.
		G.box(visual,Vector3(side*0.65,0.86,-2.06),Vector3(0.50,0.09,0.06),G.material("",Color(0.72,0.025,0.035)))
		for offset in [-0.07,0.07]:
			var exhaust := MeshInstance3D.new()
			var pipe := CylinderMesh.new()
			pipe.top_radius=0.06
			pipe.bottom_radius=0.06
			pipe.height=0.16
			pipe.radial_segments=12
			exhaust.mesh=pipe
			exhaust.position=Vector3(side*0.68+offset,0.43,-2.14)
			exhaust.rotation.x=PI/2
			exhaust.material_override=chrome
			visual.add_child(exhaust)
	G.box(visual,Vector3(0,0.43,-2.10),Vector3(1.45,0.11,0.24),trim)
	for x in [-0.55,-0.25,0.25,0.55]: G.box(visual,Vector3(x,0.41,-2.17),Vector3(0.035,0.15,0.23),trim)
	G.box(visual,Vector3(0,0.46,2.15),Vector3(1.62,0.06,0.28),trim)
	G.box(visual,Vector3(0,0.69,-2.20),Vector3(0.42,0.13,0.025),G.material("",Color(0.9,0.93,0.94)))
	var plate := G.label(visual,"AZ 003",Vector3(0,0.70,-2.225),12)
	plate.pixel_size=0.006
	plate.rotation.y=PI
	plate.modulate=Color(0.05,0.08,0.11)
	# Rear boot lip / modest wing, two supports.
	G.box(visual,Vector3(0,1.10,-1.87),Vector3(1.76,0.06,0.30),paint)
	for x in [-0.55,0.55]: G.box(visual,Vector3(x,1.02,-1.87),Vector3(0.06,0.15,0.12),trim)
	# VehicleBody3D forward is local +Z. Driver sits on local -X (right).
	G.box(visual,Vector3(-0.42,1.15,0.6),Vector3(0.28,0.08,0.28),G.material("",Color(0.05,0.05,0.05)))
	for x in [-0.94,0.94]:
		for z in [-1.3,1.3]:
			var w := VehicleWheel3D.new()
			w.position=Vector3(x,0.45,z)
			w.wheel_radius=0.34
			w.wheel_rest_length=0.2
			w.suspension_stiffness=30
			w.suspension_max_force=8500
			w.damping_compression=0.8
			w.damping_relaxation=0.9
			w.wheel_friction_slip=2.2
			w.use_as_steering=z>0
			w.use_as_traction=z<0
			add_child(w)
			wheels.append(w)
			var tire := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius=0.34
			cylinder.bottom_radius=0.34
			cylinder.height=0.22
			cylinder.radial_segments=16
			tire.mesh=cylinder
			tire.rotation.z=PI/2
			tire.material_override=G.material("",Color(0.03,0.035,0.038))
			w.add_child(tire)
			var rim := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius=0.245
			disc.bottom_radius=0.245
			disc.height=0.235
			disc.radial_segments=16
			rim.mesh=disc
			rim.rotation.z=PI/2
			rim.material_override=trim
			w.add_child(rim)
			for spoke in range(5):
				var angle := spoke*TAU/5.0
				var arm := G.box(w,Vector3(signf(x)*0.128,sin(angle)*0.12,cos(angle)*0.12),Vector3(0.025,0.035,0.22),chrome)
				arm.rotation.x=-angle
			var hub := G.box(w,Vector3(signf(x)*0.143,0,0),Vector3(0.03,0.07,0.07),chrome)
			hub.rotation.x=PI/4

func _physics_process(delta: float) -> void:
	signed_speed = linear_velocity.dot(global_basis.z)
	var t := maxf(gas,float(Input.is_key_pressed(KEY_W)))
	var b := maxf(pedal_brake,float(Input.is_key_pressed(KEY_S)))
	var c := maxf(clutch_pedal,float(Input.is_key_pressed(KEY_C)))
	transmission.clutch=move_toward(transmission.clutch,c,delta*3.0)
	var steer_input := turn + float(Input.is_key_pressed(KEY_A))-float(Input.is_key_pressed(KEY_D))
	steering = move_toward(steering,clampf(steer_input,-1,1)*0.48/(1+absf(signed_speed)*0.045),delta*1.6)
	engine_force=transmission.update(delta,signed_speed,t)
	brake=b*45.0
	if transmission.mode==Transmission.Mode.AUTOMATIC and transmission.selector=="P": brake=80.0
	# Drag and rolling resistance; braking is handled by the wheel contact solver.
	apply_central_force(-linear_velocity*linear_velocity.length()*0.42)
	if signed_speed>45 or signed_speed < -10: engine_force=0
	if position.y < -5: reset()

func reset() -> void:
	linear_velocity=Vector3.ZERO
	angular_velocity=Vector3.ZERO
	position=Vector3(-3.5,1.0,120)
	rotation=Vector3(0,PI,0)
	transmission.gear=0
	transmission.selector="P"
	transmission.running=true

func release_controls() -> void:
	gas=0
	pedal_brake=0
	turn=0
	clutch_pedal=0

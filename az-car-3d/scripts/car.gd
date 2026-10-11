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
	var paint := G.material("",Color(0.11,0.32,0.47))
	paint.metallic=0.35
	paint.roughness=0.32
	G.profile_mesh(visual,[[-2.08,0.72,0.6,0.82],[-1.82,0.89,0.57,0.98],[-1.0,0.94,0.55,1.04],[0.8,0.94,0.55,1.03],[1.65,0.87,0.6,0.89],[2.06,0.72,0.66,0.82]],paint)
	var glass := G.material("",Color(0.10,0.17,0.21))
	glass.roughness=0.2
	G.profile_mesh(visual,[[-1.15,0.80,1.0,1.11],[-0.65,0.72,1.01,1.58],[0.42,0.72,1.01,1.58],[1.02,0.79,1.0,1.10]],glass)
	G.box(visual,Vector3(0,1.6,-0.1),Vector3(1.44,0.05,1.1),paint)
	for x in [-0.81,0.81]:
		G.box(visual,Vector3(x,1.30,-0.12),Vector3(0.065,0.5,0.075),paint)
		G.box(visual,Vector3(x,1.10,0),Vector3(0.035,0.045,1.85),paint)
		G.box(visual,Vector3(x*1.23,1.13,0.66),Vector3(0.24,0.12,0.18),paint)
		for z in [-0.6,0.3]: G.box(visual,Vector3(x*1.14,1.0,z),Vector3(0.035,0.04,0.15),G.material("",Color(0.62,0.65,0.65)))
	G.box(visual,Vector3(0,0.73,2.07),Vector3(0.8,0.17,0.04),G.material("",Color(0.04,0.05,0.055)))
	G.box(visual,Vector3(0,0.68,-2.09),Vector3(0.45,0.12,0.025),G.material("",Color(0.86,0.88,0.86)))
	for x in [-0.65,0.65]:
		G.box(visual,Vector3(x,0.9,2.08),Vector3(0.44,0.2,0.03),G.material("",Color(0.92,0.90,0.70)))
		G.box(visual,Vector3(x,0.9,-2.08),Vector3(0.44,0.2,0.03),G.material("",Color(0.65,0.08,0.04)))
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
			disc.top_radius=0.22
			disc.bottom_radius=0.22
			disc.height=0.235
			disc.radial_segments=16
			rim.mesh=disc
			rim.rotation.z=PI/2
			rim.material_override=G.material("",Color(0.58,0.62,0.65))
			w.add_child(rim)

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

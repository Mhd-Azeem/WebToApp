extends VehicleBody3D
const G = preload("res://scripts/geometry.gd")
const Coupe = preload("res://scripts/coupe_visual.gd")
const Transmission = preload("res://scripts/transmission.gd")
var transmission := Transmission.new()
var gas := 0.0
var horn := 0.0
var effective_gas := 0.0
var effective_brake := 0.0
var controls_enabled := true
var pedal_brake := 0.0
var turn := 0.0
var clutch_pedal := 0.0
var signed_speed := 0.0
var wheels: Array[VehicleWheel3D] = []
var visual: Node3D

func _ready() -> void:
	mass = 1250
	collision_mask=3
	continuous_cd=true
	angular_damp=1.8
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0,-0.18,0)
	var shape := CollisionShape3D.new()
	var hull := BoxShape3D.new()
	hull.size=Vector3(1.78,0.9,4.0)
	shape.shape=hull
	shape.position.y=0.8
	add_child(shape)
	visual = Coupe.build(self,Color(0.19,0.25,0.30))
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
			w.wheel_friction_slip=3.2
			w.wheel_roll_influence=0.12
			w.use_as_steering=z>0
			w.use_as_traction=z<0
			add_child(w)
			wheels.append(w)
			Coupe.wheel(w,x)

func _physics_process(delta: float) -> void:
	signed_speed = linear_velocity.dot(global_basis.z)
	var t := maxf(gas,float(Input.is_key_pressed(KEY_W)))
	var b := maxf(pedal_brake,float(Input.is_key_pressed(KEY_S)))
	if not controls_enabled:
		t=0
		b=1
	effective_gas=t
	effective_brake=b
	var c := maxf(clutch_pedal,float(Input.is_key_pressed(KEY_C)))
	if not controls_enabled: c=1
	transmission.clutch=move_toward(transmission.clutch,c,delta*(6.0 if c>transmission.clutch else 2.4))
	var steer_input := turn + float(Input.is_key_pressed(KEY_A))-float(Input.is_key_pressed(KEY_D))
	if not controls_enabled: steer_input=0
	var target_steer := clampf(steer_input,-1,1)*0.62/(1+signed_speed*signed_speed*0.014)
	steering = move_toward(steering,target_steer,delta*(4.2 if is_zero_approx(steer_input) else 3.4))
	engine_force=transmission.update(delta,signed_speed,t)
	brake=b*65.0
	if transmission.mode==Transmission.Mode.AUTOMATIC and transmission.selector=="P": brake=80.0
	# Drag and rolling resistance; braking is handled by the wheel contact solver.
	apply_central_force(-linear_velocity*linear_velocity.length()*0.34)
	var grounded := false
	for w in wheels: grounded=grounded or w.is_in_contact()
	if grounded:
		var lateral := linear_velocity.dot(global_basis.x)
		apply_central_force(-global_basis.x*lateral*mass*2.5)
		apply_central_force(-global_basis.y*minf(3000, signed_speed*signed_speed*1.2))
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
	horn=0
	gas=0
	pedal_brake=0
	turn=0
	clutch_pedal=0




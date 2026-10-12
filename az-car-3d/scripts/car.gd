extends VehicleBody3D
const G = preload("res://scripts/geometry.gd")
const Coupe = preload("res://scripts/coupe_visual.gd")
const Transmission = preload("res://scripts/transmission.gd")
const WheelPhysics = preload("res://scripts/drivetrain/wheel_physics_controller.gd")
var transmission := Transmission.new()
@export var vehicle_configuration: Resource
var wheel_physics := WheelPhysics.new(transmission.config)
var handbrake := 0.0
var drive_force := 0.0
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
	if vehicle_configuration!=null:
		transmission=Transmission.new(vehicle_configuration)
		wheel_physics=WheelPhysics.new(transmission.config)
	mass = transmission.config.mass_kg
	collision_mask=3
	continuous_cd=true
	# Replace Godot's default linear damping: road/air resistance is explicit.
	linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
	linear_damp=0
	angular_damp=0.8
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = transmission.config.center_of_mass
	var shape := CollisionShape3D.new()
	var hull := BoxShape3D.new()
	hull.size=Vector3(1.78,0.9,4.0)
	shape.shape=hull
	shape.position.y=0.8
	add_child(shape)
	visual = Coupe.build(self,Color(0.19,0.25,0.30))
	for side in [-1.0,1.0]:
		for axle in [-1.0,1.0]:
			var x: float=side*transmission.config.track_width_m/2
			var z: float=axle*transmission.config.wheelbase_m/2
			var w := VehicleWheel3D.new()
			w.position=Vector3(x,0.45,z)
			w.wheel_radius=transmission.config.wheel_radius_m
			w.wheel_rest_length=transmission.config.suspension_rest_m
			w.suspension_stiffness=transmission.config.suspension_stiffness
			w.suspension_max_force=transmission.config.suspension_max_force_n
			w.damping_compression=transmission.config.suspension_compression
			w.damping_relaxation=transmission.config.suspension_relaxation
			w.wheel_friction_slip=transmission.config.tire_grip
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
	var c := maxf(clutch_pedal,float((Input.is_key_pressed(KEY_SHIFT) if OS.has_feature("pc") else Input.is_key_pressed(KEY_C))))
	if not controls_enabled: c=1
	transmission.clutch=move_toward(transmission.clutch,c,delta*7.0)
	var steer_input := turn + float(Input.is_key_pressed(KEY_A))-float(Input.is_key_pressed(KEY_D))
	if not controls_enabled: steer_input=0
	var target_steer := clampf(steer_input,-1,1)*0.62/(1+signed_speed*signed_speed*0.014)
	steering = move_toward(steering,target_steer,delta*(4.2 if is_zero_approx(steer_input) else 3.4))
	var wheel_omega := wheel_physics.feedback(wheels,signed_speed,delta)
	drive_force=transmission.update(delta,signed_speed,t,wheel_omega,wheel_physics.driven_contacts==2)
	wheel_physics.apply(self,wheels,drive_force,b,handbrake,transmission.mode==Transmission.Mode.AUTOMATIC and transmission.selector=="P",delta)
	if wheel_physics.grounded:
		apply_central_force(-global_basis.y*minf(500,signed_speed*signed_speed*transmission.config.downforce_coefficient))
	if position.y < -5: reset()

func reset() -> void:
	linear_velocity=Vector3.ZERO
	angular_velocity=Vector3.ZERO
	position=Vector3(-3.5,1.0,120)
	rotation=Vector3(0,PI,0)
	transmission.reset()
	handbrake=0
	wheel_physics.last_speed=0
	wheel_physics.airborne_omega=0
	engine_force=0
	brake=0

func release_controls() -> void:
	horn=0
	gas=0
	pedal_brake=0
	turn=0
	clutch_pedal=0




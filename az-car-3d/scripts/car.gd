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
var garage_kind := "sedan"
var drive_multiplier := 1.0
var paint_material: StandardMaterial3D
var rim_material: StandardMaterial3D
var fuel_litres := 45.0
var damage := 0.0
var damage_enabled := false
var previous_velocity := Vector3.ZERO
var recovery_point := Vector3(-3.5,1.0,120)
var recovery_heading := PI
var road_navigation: RefCounted
var recovery_elapsed := 0.0
var fuel_exhausted := false
var turn_signal := 0
var hazards := false
var high_beams := false

func _ready() -> void:
	if vehicle_configuration!=null:
		transmission=Transmission.new(vehicle_configuration)
		wheel_physics=WheelPhysics.new(transmission.config)
	mass = transmission.config.mass_kg
	collision_mask=3
	continuous_cd=true
	max_contacts_reported = 4
	contact_monitor = true
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
	if fuel_exhausted: t = 0
	if damage_enabled: t *= 1.0 - damage * 0.45
	if damage_enabled and (previous_velocity - linear_velocity).length() > 7.0 and get_contact_count() > 0:
		damage = clampf(damage + (previous_velocity - linear_velocity).length() * 0.008, 0, 1)
	previous_velocity = linear_velocity
	var b := maxf(pedal_brake,float(Input.is_key_pressed(KEY_S)))
	if not controls_enabled:
		t=0
		b=1
	effective_gas=t
	if transmission.running:
		var rpm_ratio := clampf(transmission.rpm / float(transmission.config.redline_rpm), 0, 1)
		var load := maxf(0.0, transmission.engine.load)
		var litres_per_hour := 0.85 + 30.0 * load * rpm_ratio + 3.0 * t
		fuel_litres = maxf(0, fuel_litres - delta * litres_per_hour / 3600.0)
		if fuel_litres == 0:
			fuel_exhausted = true
			transmission.start_stop()
	effective_brake=b
	var c := maxf(clutch_pedal,float(Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_C)))
	if not controls_enabled: c=1
	transmission.clutch=move_toward(transmission.clutch,c,delta*7.0)
	var steer_input := turn + float(Input.is_key_pressed(KEY_A))-float(Input.is_key_pressed(KEY_D))
	if not controls_enabled: steer_input=0
	var target_steer := clampf(steer_input,-1,1)*0.62/(1+signed_speed*signed_speed*0.014)
	steering = move_toward(steering,target_steer,delta*(4.2 if is_zero_approx(steer_input) else 3.4))
	var wheel_omega := wheel_physics.feedback(wheels,signed_speed,delta)
	drive_force=transmission.update(delta,signed_speed,t,wheel_omega,wheel_physics.driven_contacts==2)
	wheel_physics.apply(self,wheels,drive_force*drive_multiplier,b,handbrake,transmission.mode==Transmission.Mode.AUTOMATIC and transmission.selector=="P",delta)
	if wheel_physics.grounded:
		apply_central_force(-global_basis.y*minf(500,signed_speed*signed_speed*transmission.config.downforce_coefficient))
	recovery_elapsed += delta
	if recovery_elapsed >= 0.35 and wheel_physics.grounded and global_basis.y.y > 0.85:
		recovery_elapsed = 0.0
		for wheel in wheels:
			var contact := wheel.get_contact_body() if wheel.is_in_contact() else null
			if is_instance_valid(contact) and contact.get_meta("surface", "") == "asphalt":
				recovery_point = position + Vector3.UP * 0.9
				recovery_heading = rotation.y
				break
	if position.y < -5: recover()

func apply_garage_vehicle(kind: String, index: int) -> void:
	if kind != garage_kind:
		visual.free()
		visual = Coupe.build(self,Color(0.19,0.25,0.30),kind)
		garage_kind=kind
		paint_material=null
		for mesh in visual.find_children("*","GeometryInstance3D",true,false): mesh.layers=4
	mass=transmission.config.mass_kg * [1.0,0.86,1.16][index]
	drive_multiplier=[1.0,0.70,0.90][index]

func apply_appearance(paint: Color, rims: Color) -> void:
	if paint_material==null:
		var original: StandardMaterial3D=visual.get_meta("paint_material")
		paint_material=original.duplicate()
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			if mesh.material_override==original: mesh.material_override=paint_material
	paint_material.albedo_color=paint
	if rim_material==null:
		var original := G.material("",Color(0.53,0.60,0.66))
		rim_material=original.duplicate()
		for wheel in wheels:
			for mesh in wheel.get_children():
				if mesh is MeshInstance3D and mesh.material_override==original:
					mesh.material_override=rim_material
	rim_material.albedo_color=rims

func recover() -> void:
	if road_navigation != null:
		var pose: Dictionary=road_navigation.recovery_pose(global_position,get_world_3d().direct_space_state,get_rid())
		if not pose.is_empty():
			recovery_point=pose.point
			recovery_heading=pose.heading
	_reset_motion(recovery_point, recovery_heading)
	if fuel_exhausted: transmission.start_stop()

func reset() -> void:
	_reset_motion(Vector3(-3.5,1.0,120), PI)

func _reset_motion(point: Vector3, heading: float) -> void:
	linear_velocity=Vector3.ZERO
	angular_velocity=Vector3.ZERO
	position=point
	rotation=Vector3(0,heading,0)
	previous_velocity = Vector3.ZERO
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




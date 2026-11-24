extends RefCounted
# Adapter to Godot raycast suspension, its tire solver and per-wheel impulses.
const Config = preload("res://scripts/drivetrain/vehicle_configuration.gd")
var config: Config
var abs_enabled := false
var traction_control := false
var limited_slip := false
var wet_roads := false
var omega := 0.0
var skid := 0.0
var grounded := false
var driven_contacts := 0
var last_speed := 0.0
var acceleration := 0.0
var airborne_omega := 0.0
var applied_force := 0.0
func _init(c: Config = null) -> void:
	config=c if c!=null else Config.new()
func feedback(wheels: Array[VehicleWheel3D],speed: float,delta: float) -> float:
	grounded=false
	driven_contacts=0
	var rotation := 0.0
	skid=0
	for w in wheels:
		if w.is_in_contact():
			grounded=true
			skid=maxf(skid,1-w.get_skidinfo())
			if w.use_as_traction:
				driven_contacts+=1
				rotation+=absf(w.get_rpm())*TAU/60
	acceleration=clampf((speed-last_speed)/maxf(delta,0.001),-12,12)
	last_speed=speed
	if driven_contacts==2:
		omega=rotation/driven_contacts*signf(speed)
		if absf(speed)<0.05: omega=speed/config.wheel_radius_m
		airborne_omega=omega
	elif driven_contacts==1:
		omega=(rotation*signf(speed)+airborne_omega)*0.5
	else: omega=airborne_omega
	return omega
func apply(body: VehicleBody3D,wheels: Array[VehicleWheel3D],force: float,brake_pedal: float,handbrake: float,park: bool,delta: float) -> void:
	# VehicleBody engine_force sets the SAME force on each driven wheel, not a
	# total axle force. Assign half to each rear wheel to conserve shaft power.
	body.engine_force=0
	body.brake=0
	var rear_load := config.mass_kg*9.8*0.5+config.mass_kg*acceleration*config.center_of_mass.y/config.wheelbase_m
	rear_load=clampf(rear_load,config.mass_kg*9.8*0.25,config.mass_kg*9.8*0.75)
	var maximum := rear_load*config.tire_grip
	# Open differential: with a rear wheel off the ground, both receive little traction.
	var drive := clampf(force,-maximum,maximum) if driven_contacts==2 else 0.0
	if limited_slip and driven_contacts == 1: drive = clampf(force, -maximum * 0.45, maximum * 0.45)
	if traction_control and force * last_speed >= 0:
		drive *= clampf(1.0 - skid * 0.85, 0.2, 1.0)
	var allocation := 1.0 if limited_slip and driven_contacts == 1 else 0.5
	applied_force=0
	for w in wheels:
		var rear := w.use_as_traction
		var braking := brake_pedal>0.01 or park or (rear and handbrake>0.01)
		var contact := w.is_in_contact()
		var grip := surface_grip(w.get_contact_body() if contact else null, wet_roads)
		w.engine_force=drive*allocation*grip if rear and not braking and contact else 0.0
		var torque := (config.rear_brake_nm if rear else config.front_brake_nm)*brake_pedal
		if rear: torque+=config.handbrake_nm*handbrake
		if park: torque=maxf(torque,config.handbrake_nm)
		if braking and rear and force*last_speed<0: torque+=absf(force)*0.5*config.wheel_radius_m
		# Godot 4.5.1 uses wheel.brake as a maximum CONTACT IMPULSE internally,
		# despite its inspector label. Convert N*m -> N -> N*s once per tick.
		if abs_enabled and brake_pedal > 0.01 and handbrake < 0.01 and absf(last_speed) > 4.0 and contact:
			var tread_speed := absf(w.get_rpm()) * TAU / 60.0 * w.wheel_radius
			torque *= clampf(tread_speed / absf(last_speed) + 0.2, 0.30, 1.0)
		w.brake=torque/config.wheel_radius_m*delta
		if w.is_in_contact(): applied_force+=w.engine_force
		w.wheel_friction_slip=config.tire_grip*grip*(0.6 if rear and handbrake>0.1 else 1.0)
	if driven_contacts<2:
		airborne_omega+=force*config.wheel_radius_m/(config.wheel_inertia*maxi(1,2-driven_contacts))*delta
		airborne_omega*=exp(-delta*0.3)
	if grounded:
		var rolling := config.mass_kg*9.8*config.rolling_coefficient
		rolling=minf(rolling,config.mass_kg*absf(last_speed)/maxf(delta,0.001))
		body.apply_central_force(-body.global_basis.z*signf(last_speed)*rolling)
	body.apply_central_force(-body.linear_velocity*body.linear_velocity.length()*config.drag_n_per_speed_squared)


static func surface_grip(contact: Object, wet: bool) -> float:
	var surface: String = contact.get_meta("surface", "asphalt") if is_instance_valid(contact) else "asphalt"
	match surface:
		"grass": return 0.55 if wet else 0.68
		"sand": return 0.48
		_: return 0.74 if wet else 1.0

extends Resource
# SI units. Five ratio choices retain the game's earlier 40/60/80/120/220 gearing.
@export var mass_kg := 1250.0
@export var wheel_radius_m := 0.34
@export var wheelbase_m := 2.60
@export var track_width_m := 1.88
@export var center_of_mass := Vector3(0,0.45,0)
@export var wheel_inertia := 1.1
@export var final_drive := 3.90
@export var forward_ratios := PackedFloat32Array([0.0,5.34,3.56,2.67,1.78,0.97])
@export var reverse_ratio := -3.40
@export var reverse_speed_limit_kph := 25.0
@export var idle_rpm := 800.0
@export var redline_rpm := 6000.0
@export var maximum_rpm := 6500.0
@export var overrev_rpm := 7000.0
@export var stall_rpm := 400.0
@export var engine_inertia := 0.22
@export var engine_friction_nm := 10.0
@export var engine_viscous_friction := 0.10
@export var throttle_time_s := 0.12
@export var idle_governor_max_nm := 55.0
@export var starter_torque_nm := 45.0
@export var starter_crank_rpm := 300.0
@export var starter_ignition_rpm := 220.0
@export var starter_duration_s := 0.75
@export var torque_curve := PackedVector2Array([Vector2(0,0),Vector2(800,115),Vector2(1500,150),Vector2(2500,175),Vector2(3500,180),Vector2(4500,170),Vector2(5500,140),Vector2(6000,122),Vector2(6500,108),Vector2(7500,0)])
@export var clutch_capacity_nm := 250.0
@export var clutch_bite_pedal := 0.85
@export var clutch_stiffness := 80.0
@export var manual_shift_s := 0.14
@export var auto_shift_s := 0.28
@export var drivetrain_efficiency := 0.90
@export var converter_coefficient := 0.0025
@export var converter_multiplication := 1.8
@export var tire_grip := 1.1
@export var drag_n_per_speed_squared := 0.24
@export var rolling_coefficient := 0.008
@export var front_brake_nm := 1100.0
@export var rear_brake_nm := 800.0
@export var handbrake_nm := 1400.0
@export var suspension_stiffness := 30.0
@export var suspension_rest_m := 0.20
@export var suspension_max_force_n := 8500.0
@export var suspension_compression := 0.8
@export var suspension_relaxation := 0.9
@export var downforce_coefficient := 0.04
@export var engine_cylinders := 4
@export var audio_references := PackedFloat32Array([800,1800,3200,5200])
func torque_at(rpm: float) -> float:
	for i in range(1,torque_curve.size()):
		if rpm<=torque_curve[i].x:
			var a := torque_curve[i-1]
			var b := torque_curve[i]
			return lerpf(a.y,b.y,clampf((rpm-a.x)/(b.x-a.x),0,1))
	return 0

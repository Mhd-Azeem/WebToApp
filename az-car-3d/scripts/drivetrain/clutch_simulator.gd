extends RefCounted
const Config = preload("res://scripts/drivetrain/vehicle_configuration.gd")
var config: Config
var engagement := 0.0
var torque_nm := 0.0
var slip_rpm := 0.0
var locked := false
func _init(c: Config = null) -> void:
	config=c if c!=null else Config.new()
func solve(dt: float,free_engine_omega: float,input_omega: float,pedal: float,input_inverse_inertia: float) -> float:
	engagement=pow(clampf((config.clutch_bite_pedal-pedal)/0.65,0,1),2)
	var capacity := config.clutch_capacity_nm*engagement
	var stiffness := config.clutch_stiffness*engagement
	var slip := free_engine_omega-input_omega
	# Implicit reaction torque avoids a stiff spring oscillating at the physics timestep.
	var denominator := 1+stiffness*dt*(1/config.engine_inertia+input_inverse_inertia)
	torque_nm=clampf(stiffness*slip/denominator,-capacity,capacity)
	slip_rpm=slip*60/TAU
	locked=engagement>0.98 and absf(slip_rpm)<60
	return torque_nm

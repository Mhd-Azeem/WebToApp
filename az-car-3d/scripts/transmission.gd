extends RefCounted
class_name SriTransmission
const Config = preload("res://scripts/drivetrain/vehicle_configuration.gd")
const EngineMotor = preload("res://scripts/drivetrain/engine_simulator.gd")
const ClutchModel = preload("res://scripts/drivetrain/clutch_simulator.gd")
const Automatic = preload("res://scripts/drivetrain/automatic_transmission.gd")
enum Mode { MANUAL, AUTOMATIC }
const SPEED_LIMITS := [0.0,40.0,60.0,80.0,120.0,220.0]
const RATIOS := [0.0,5.34,3.56,2.67,1.78,0.97]
var config: Config
var engine: EngineMotor
var coupling: ClutchModel
var automatic: Automatic
var mode := Mode.MANUAL
var gear := 0
var selector := "P"
var clutch := 0.0
var auto_gear := 1
var message := "Hold clutch, select 1; add gas and slide clutch down gently"
var shift_timer := 0.0
var shift_serial := 0
var grind_serial := 0
var wheel_torque := 0.0
var clutch_torque := 0.0
var shaft_rpm := 0.0
var mechanical_overrev := false
var rpm: float:
	get: return engine.rpm
	set(value): engine.rpm=value
var running: bool:
	get: return engine.running
	set(value):
		if value: engine.reset_idle()
		else: engine.stop()
var ignition_serial: int:
	get: return engine.ignition_serial
func _init(c: Config = null) -> void:
	config=c if c!=null else load("res://vehicle_configuration.tres") as Config
	engine=EngineMotor.new(config)
	coupling=ClutchModel.new(config)
	automatic=Automatic.new(config)
func reset() -> void:
	gear=0
	selector="P"
	auto_gear=1
	clutch=0
	shift_timer=0
	wheel_torque=0
	clutch_torque=0
	engine.reset_idle()
	automatic.cooldown=0
	message="Engine running • select a gear to drive"
func reject_shift(reason: String) -> void:
	message=reason
	if engine.running: grind_serial+=1
func shift(next: int,speed: float) -> bool:
	if mode!=Mode.MANUAL or next< -1 or next>5: return false
	if clutch<0.85:
		reject_shift("Press clutch at least 85% before shifting")
		return false
	if (next==-1 and absf(speed)>0.5) or (next>0 and speed< -0.5):
		reject_shift("Stop before changing direction")
		return false
	var predicted := absf(speed)/config.wheel_radius_m*absf(config.reverse_ratio if next==-1 else config.forward_ratios[next])*config.final_drive*60/TAU
	if next!=0 and predicted>config.overrev_rpm:
		mechanical_overrev=true
		reject_shift("Downshift rejected: mechanical over-rev risk")
		return false
	if next!=gear:
		gear=next
		shift_timer=config.manual_shift_s if next!=0 else 0.0
		shift_serial+=1
	message="Gear selected • release clutch progressively"
	return true
func select(next: String,speed: float,brake: float) -> bool:
	if mode!=Mode.AUTOMATIC or next not in ["P","R","N","D"]: return false
	if next in ["P","R","D"] and (absf(speed)>0.5 or brake<0.5):
		message="Stop and hold brake before selecting P / R / D"
		return false
	if selector!=next:
		selector=next
		shift_timer=config.auto_shift_s if next in ["R","D"] else 0.0
		shift_serial+=1
		if next=="D": auto_gear=1
	message="Automatic "+next
	return true
func toggle(speed: float) -> bool:
	if absf(speed)>0.5:
		message="Stop before changing transmission"
		return false
	mode=Mode.AUTOMATIC if mode==Mode.MANUAL else Mode.MANUAL
	gear=0
	selector="P"
	shift_timer=0
	wheel_torque=0
	message="Automatic: brake then D" if mode==Mode.AUTOMATIC else "Manual: clutch then 1"
	return true
func restart() -> bool:
	if (mode==Mode.MANUAL and (clutch>=0.85 or gear==0)) or (mode==Mode.AUTOMATIC and selector in ["P","N"]):
		engine.start()
		message="Cranking engine..."
		return true
	message="To start: hold clutch / select neutral; automatic P or N"
	return false
func start_stop() -> void:
	if engine.running or engine.state==EngineMotor.State.STARTING:
		engine.stop()
		message="Ignition off"
	else: restart()
func ratio(_speed: float = 0.0) -> float:
	if mode==Mode.MANUAL: return config.reverse_ratio if gear==-1 else config.forward_ratios[gear]
	if selector=="R": return config.reverse_ratio
	return config.forward_ratios[auto_gear] if selector=="D" else 0.0
func update(delta: float,speed: float,gas: float,measured_wheel_omega: float = NAN,grounded: bool = true) -> float:
	var wheel_omega := speed/config.wheel_radius_m if is_nan(measured_wheel_omega) else measured_wheel_omega
	if mode==Mode.AUTOMATIC and selector=="D" and shift_timer<=0 and engine.running:
		var next := automatic.schedule(delta,auto_gear,rpm,gas,engine.load,speed,wheel_omega)
		if next!=auto_gear:
			auto_gear=next
			shift_timer=config.auto_shift_s
			shift_serial+=1
	var r := ratio()*config.final_drive
	shaft_rpm=wheel_omega*r*60/TAU
	var ticks := maxi(1,ceili(delta*240.0))
	var dt := delta/ticks
	var torque_sum := 0.0
	var throttle_request := gas
	if r<0 and speed<0 and absf(speed)*3.6>config.reverse_speed_limit_kph: throttle_request=0
	for i in range(ticks):
		shift_timer=maxf(0,shift_timer-dt)
		var free := engine.free_torque(dt,throttle_request)
		var free_omega := maxf(0,engine.omega+free*dt/config.engine_inertia)
		var input_omega := wheel_omega*r
		var input_inertia := config.mass_kg*config.wheel_radius_m*config.wheel_radius_m if grounded else config.wheel_inertia*2
		var input_inverse := r*r/maxf(0.01,input_inertia)
		var drive_torque := 0.0
		clutch_torque=0
		coupling.engagement=0
		automatic.lockup=false
		if not is_zero_approx(r) and shift_timer<=0 and engine.state!=EngineMotor.State.STARTING:
			if mode==Mode.MANUAL:
				clutch_torque=coupling.solve(dt,free_omega,input_omega,clutch,input_inverse)
				drive_torque=clutch_torque
			else:
				automatic.lockup=auto_gear>=3 and absf(speed)>13 and shaft_rpm>1300 and automatic.cooldown<=0 and (gas<0.8 or absf(speed)>35)
				if automatic.lockup:
					clutch_torque=coupling.solve(dt,free_omega,input_omega,0,input_inverse)
					drive_torque=clutch_torque
				else:
					var converter := automatic.converter(engine.omega,input_omega)
					clutch_torque=converter.x
					drive_torque=converter.y
		engine.integrate(dt,clutch_torque)
		if not engine.running and drive_torque>0: drive_torque=0
		var efficiency := config.drivetrain_efficiency if drive_torque>=0 else 1/config.drivetrain_efficiency
		torque_sum+=drive_torque*r*efficiency
	wheel_torque=torque_sum/ticks
	mechanical_overrev=mechanical_overrev or engine.mechanical_overrev
	if engine.state==EngineMotor.State.STALLED: message="Engine stalled • clutch and START, or P/N in automatic"
	return wheel_torque/config.wheel_radius_m
func display() -> String:
	if mode==Mode.AUTOMATIC: return "AT "+selector+(" / "+str(auto_gear) if selector=="D" else "")
	return "MT "+("R" if gear==-1 else ("N" if gear==0 else str(gear)))

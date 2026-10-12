extends RefCounted
const Config = preload("res://scripts/drivetrain/vehicle_configuration.gd")
enum State { OFF, STARTING, RUNNING, STALLED }
var config: Config
var state := State.RUNNING
var omega := 0.0
var throttle := 0.0
var combustion_nm := 0.0
var friction_nm := 0.0
var net_nm := 0.0
var load := 0.0
var limiter := false
var ignition_cut := false
var mechanical_overrev := false
var clock := 0.0
var crank_time := 0.0
var stall_time := 0.0
var ignition_serial := 0
var stall_serial := 0
var shutdown_serial := 0
var rpm: float:
	get: return omega*60.0/TAU
	set(value): omega=maxf(0,value)*TAU/60.0
var running: bool:
	get: return state==State.RUNNING
func _init(c: Config = null) -> void:
	config=c if c!=null else Config.new()
	reset_idle()
func reset_idle() -> void:
	state=State.RUNNING
	rpm=config.idle_rpm
	throttle=0
	limiter=false
	ignition_cut=false
	mechanical_overrev=false
	stall_time=0
	crank_time=0
	load=0
func start() -> void:
	if state==State.RUNNING or state==State.STARTING: return
	state=State.STARTING
	crank_time=0
	ignition_serial+=1
func stop() -> void:
	if state==State.OFF: return
	state=State.OFF
	shutdown_serial+=1
func free_torque(dt: float,pedal: float) -> float:
	clock+=dt
	throttle=lerpf(throttle,clampf(pedal,0,1),1-exp(-dt/config.throttle_time_s))
	mechanical_overrev=rpm>config.overrev_rpm
	if rpm>=config.maximum_rpm: limiter=true
	elif rpm<config.maximum_rpm-180: limiter=false
	ignition_cut=limiter and fposmod(clock,0.065)<0.046
	friction_nm=(config.engine_friction_nm+config.engine_viscous_friction*omega)*clampf(omega/15,0,1)
	combustion_nm=0
	var starter := 0.0
	if state==State.STARTING:
		crank_time+=dt
		var target := config.starter_crank_rpm*TAU/60
		starter=clampf((target-omega)*3+config.engine_friction_nm+config.engine_viscous_friction*target,0,config.starter_torque_nm) if crank_time<config.starter_duration_s+1.0 else 0.0
		if crank_time>=config.starter_duration_s and rpm>config.starter_ignition_rpm:
			state=State.RUNNING
			starter=0
		elif crank_time>config.starter_duration_s+1.0:
			state=State.OFF
	if running:
		var idle_omega := config.idle_rpm*TAU/60.0
		var governor := clampf((idle_omega-omega)*1.8+config.engine_friction_nm+config.engine_viscous_friction*idle_omega,0,config.idle_governor_max_nm)
		# The configured manufacturer curve is net crankshaft torque. Account
		# for internal friction in combustion, while closed-throttle still brakes.
		governor*=1-clampf(throttle/0.3,0,1)
		combustion_nm=((config.torque_at(rpm)+friction_nm)*throttle+governor)*(0.0 if ignition_cut else 1.0)
	net_nm=combustion_nm+starter-friction_nm
	return net_nm
func integrate(dt: float,load_torque: float) -> void:
	omega=clampf(omega+(net_nm-load_torque)*dt/config.engine_inertia,0,config.maximum_rpm*TAU/60.0*1.4)
	load=clampf(load_torque/maxf(1,config.torque_at(rpm)),-1.5,1.5)
	if running and rpm<config.stall_rpm:
		stall_time+=dt
		if stall_time>0.10:
			state=State.STALLED
			stall_serial+=1
	else: stall_time=0
func status() -> String:
	if mechanical_overrev: return "OVERREV"
	return ["OFF","STARTING","RUNNING","STALLED"][state]

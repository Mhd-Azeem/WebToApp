extends RefCounted
const T = preload("res://scripts/transmission.gd")
const Audio = preload("res://scripts/engine_audio.gd")
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)
func advance(t: T,seconds: float,speed: float,gas: float,rate: float = 120.0) -> float:
	var total := 0.0
	for i in range(roundi(seconds*rate)): total+=t.update(1/rate,speed,gas)
	return total/maxf(1,seconds*rate)
func run() -> int:
	var t := T.new()
	var peak_power := 0.0
	var peak_torque := 0.0
	for r in range(800,6501,50):
		var torque: float=t.config.torque_at(r)
		peak_torque=maxf(peak_torque,torque)
		peak_power=maxf(peak_power,torque*r*TAU/60/745.7)
	check(absf(peak_torque-180)<1 and peak_power>105 and peak_power<115,"180 Nm and approximately 110 HP curve consistency")
	var idle := t.rpm
	check(is_zero_approx(advance(t,1,0,0.6)),"Neutral revving cannot send wheel torque")
	check(t.rpm>idle+1500,"Neutral RPM rises from integrated torque")
	advance(t,5,0,0)
	check(absf(t.rpm-800)<35,"Friction and governor return engine to idle")
	check(not t.shift(1,0),"Unsafe clutchless shift rejected")
	check(t.grind_serial>0,"Incorrect shift emits grind event")
	t.clutch=1
	check(t.shift(1,0),"First selected with clutch")
	check(is_zero_approx(advance(t,0.5,5,0.7)),"Pressed clutch disconnects torque while moving")
	check(t.rpm>2000,"Disconnected engine can free-rev while coasting")
	t.reset()
	t.gear=1
	t.clutch=0
	advance(t,1,0,0)
	check(not t.running and t.engine.state==3,"Abrupt first-gear clutch release stalls")
	t.clutch=1
	check(t.restart(),"Clutch permits restart")
	check(not t.running and t.engine.state==1,"Restart has a real cranking phase")
	advance(t,1.1,0,0)
	check(t.running and t.rpm>500,"Starter torque restarts engine")
	t.engine.stop()
	advance(t,2,0,0)
	check(not t.running and t.rpm<10,"Ignition off stops combustion and rotation decays")
	var rpm_by_gear := []
	for g in [2,5]:
		t=T.new()
		t.gear=g
		t.clutch=0
		advance(t,3,60/3.6,0.25)
		rpm_by_gear.append(t.rpm)
		var expected: float=60/3.6/t.config.wheel_radius_m*t.ratio()*t.config.final_drive*60/TAU
		check(absf(t.rpm-expected)<90,"Locked clutch follows wheel RPM x ratios for gear "+str(g))
	check(rpm_by_gear[0]>rpm_by_gear[1]*2.5,"Same 60 km/h, second produces much higher RPM than fifth")
	var standard := T.new(load("res://standard_vehicle_configuration.tres"))
	standard.gear=2
	advance(standard,3,60/3.6,0.25)
	var standard_second := standard.rpm
	standard.gear=5
	advance(standard,3,60/3.6,0.25)
	check(standard_second>standard.rpm*2.4 and absf(standard_second-3834)<100,"Suggested standard gear-ratio preset is configurable and mechanically distinct")
	t=T.new()
	t.gear=3
	var engine_braking := advance(t,3,50/3.6,0)
	check(engine_braking< -100,"Closed-throttle coupled engine brakes wheels")
	t.clutch=1
	check(is_zero_approx(advance(t,0.1,50/3.6,0)),"Pressing clutch removes engine braking")
	t.gear=0
	check(is_zero_approx(advance(t,0.2,50/3.6,0)),"Neutral coasts without engine torque")
	# Smooth hill-start plant: reaction wheel torque accelerates a finite chassis.
	t=T.new()
	t.gear=1
	t.clutch=1
	advance(t,0.6,0,0.45)
	var speed := 0.0
	for i in range(180):
		t.clutch=maxf(0,1-float(i)/120)
		var force := t.update(1.0/120,speed,0.5)
		force=clampf(force,-t.config.mass_kg*9.8*0.55,t.config.mass_kg*9.8*0.55)
		speed+=force/t.config.mass_kg/120
	check(t.running and speed>1,"Progressive clutch and throttle launch finite mass without stalling")
	check(t.coupling.engagement>0.9,"Fully released pedal couples clutch")
	t.clutch=1
	var before := t.rpm
	check(t.shift(2,speed),"Upshift accepted with clutch")
	check(t.rpm==before,"Selecting another gear does not assign an arbitrary RPM")
	check(is_zero_approx(t.update(0.05,speed,0.4)),"Shift timing disconnects drive")
	check(not t.shift(1,100/3.6) and t.mechanical_overrev,"Unsafe downshift mechanical over-rev detected and rejected")
	check(not t.shift(-1,10),"Moving reverse rejected")
	# Limiter is hysteretic combustion cut, not hard vehicle-speed assignment.
	t=T.new()
	var saw_limiter := false
	var saw_cut := false
	for i in range(600):
		t.update(1.0/120,0,1)
		saw_limiter=saw_limiter or t.engine.limiter
		saw_cut=saw_cut or t.engine.ignition_cut
	check(saw_limiter and saw_cut and t.rpm<6700,"Limiter cuts combustion around configured maximum RPM")
	# Automatic selection, timed shifts, converter creep and safe kickdown.
	t=T.new()
	t.toggle(0)
	check(not t.select("D",0,0),"Automatic D requires brake")
	check(t.select("D",0,1),"D accepted with brake at rest")
	check(is_zero_approx(t.update(0.1,0,0)),"Automatic engagement delay")
	check(advance(t,1,0,0)>0 and t.running,"Torque converter idle creep without engine stall")
	check(not t.select("P",5,1) and not t.select("R",5,1),"Moving park / direction changes rejected")
	t.select("R",0,1)
	check(advance(t,1,0,0.4)<0,"Automatic reverse transmits negative wheel torque")
	t.select("N",0,0)
	check(is_zero_approx(advance(t,0.5,15,1)),"Automatic neutral disconnected")
	t.select("P",0,1)
	check(is_zero_approx(advance(t,0.2,0,1)),"Park supplies no propulsion")
	t.selector="D"
	t.auto_gear=5
	t.shift_timer=0
	t.rpm=1800
	t.automatic.cooldown=0
	t.update(1.0/60,60/3.6,1)
	check(t.auto_gear<5 and t.shift_timer>0,"Full-throttle automatic kickdown and real shift delay")
	t=T.new()
	t.mode=T.Mode.AUTOMATIC
	t.selector="D"
	t.auto_gear=1
	t.rpm=6100
	t.update(1.0/60,36/3.6,1)
	check(t.auto_gear==2,"Automatic upshift from RPM / throttle scheduling")
	# Converter stall multiplication respects energy on rotating pump/turbine.
	var converted := t.automatic.converter(200,100)
	check(converted.y*100<=converted.x*200+0.01,"Converter multiplication cannot create shaft power")
	# Rendering rate cannot alter mechanical integration.
	var reference := 0.0
	for rate in [30.0,60.0,120.0]:
		t=T.new()
		advance(t,0.8,0,0.6,rate)
		if reference==0: reference=t.rpm
		check(absf(t.rpm-reference)<20,"Engine integration stable at 30/60/120 Hz")
	# Procedural PCM layers are valid, seam-safe loops rather than repeated events.
	var stream := Audio._stream("engine0",800.0*4/120,1.5,true)
	check(stream.data.size()==48000 and stream.loop_end==24000,"PCM engine layer size / seamless loop configuration")
	print("Mechanical drivetrain scenario checks: ","PASS" if failures==0 else "FAIL", " • 60 km/h RPM: ",rpm_by_gear, " • peak HP: ",peak_power)
	return failures

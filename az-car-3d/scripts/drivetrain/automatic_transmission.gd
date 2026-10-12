extends RefCounted
const Config = preload("res://scripts/drivetrain/vehicle_configuration.gd")
var config: Config
var cooldown := 0.0
var lockup := false
func _init(c: Config = null) -> void:
	config=c if c!=null else Config.new()
func schedule(dt: float,gear: int,rpm: float,throttle: float,load: float,speed: float,wheel_omega: float) -> int:
	cooldown=maxf(0,cooldown-dt)
	if cooldown>0: return gear
	var up_rpm := lerpf(2400,6000,throttle)+maxf(0,load-0.8)*150
	var next := gear
	if throttle>0.75 and rpm<3300 and absf(speed)>4 and gear>1:
		for candidate in range(maxi(1,gear-2),gear):
			var predicted := absf(wheel_omega)*config.forward_ratios[candidate]*config.final_drive*60/TAU
			if predicted>=1800 and predicted<config.redline_rpm-200:
				next=candidate
				break
	elif rpm>up_rpm and gear<5: next=gear+1
	elif rpm<1150 and gear>1:
		var predicted := absf(wheel_omega)*config.forward_ratios[gear-1]*config.final_drive*60/TAU
		if predicted<config.maximum_rpm-200: next=gear-1
	if next!=gear: cooldown=0.85
	return next
func converter(engine_omega: float,input_omega: float) -> Vector2:
	# Fluid pump/turbine model; multiplication cannot create shaft power.
	var pump := clampf(config.converter_coefficient*(engine_omega*engine_omega-input_omega*input_omega),-config.clutch_capacity_nm,config.clutch_capacity_nm)
	var speed_ratio := input_omega/maxf(1,engine_omega)
	var multiplier := lerpf(config.converter_multiplication,1,clampf(speed_ratio,0,1))
	if speed_ratio>0: multiplier=minf(multiplier,1/maxf(0.01,speed_ratio))
	if pump<0: multiplier=1
	return Vector2(pump,pump*multiplier)

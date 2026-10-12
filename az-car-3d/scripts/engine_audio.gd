extends Node
# Original procedural audio; no third-party recordings.
const RATE := 16000.0
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var car: VehicleBody3D
var phase := 0.0
var clock := 0.0
var smooth_rpm := 850.0
var gain := 0.0
var start_left := 0.7
var shift_left := 0.0
var drop_left := 0.0
var last_gear := ""
var last_ignition := 0
var last_throttle := 0.0
var noise := RandomNumberGenerator.new()
var filtered_noise := 0.0

func _ready() -> void:
	noise.seed=32003
	player=AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate=RATE
	stream.buffer_length=0.12
	player.stream=stream
	player.volume_db=-8.0
	add_child(player)
	player.play()
	playback=player.get_stream_playback() as AudioStreamGeneratorPlayback

func _process(_delta: float) -> void:
	if not is_instance_valid(car) or playback==null: return
	var t = car.transmission
	var throttle: float=car.effective_gas
	if t.ignition_serial!=last_ignition:
		last_ignition=t.ignition_serial
		start_left=0.7
	var gear: String=t.display()
	if gear!=last_gear and not last_gear.is_empty(): shift_left=0.12
	last_gear=gear
	if last_throttle>0.5 and throttle<0.15 and t.rpm>2000: drop_left=0.22
	last_throttle=throttle
	var horn_on: bool = car.horn>0 or Input.is_key_pressed(KEY_H)
	var speed := car.linear_velocity.length()
	var tire := 0.0
	for w in car.wheels:
		if w.is_in_contact(): tire=maxf(tire,clampf(1.0-w.get_skidinfo(),0,1))
	var braking: float=car.effective_brake*clampf((speed-2.0)/15.0,0,1)
	# Fill all available frames to avoid starvation at low frame rates.
	for i in range(playback.get_frames_available()):
		clock+=1.0/RATE
		start_left=maxf(0,start_left-1.0/RATE)
		shift_left=maxf(0,shift_left-1.0/RATE)
		drop_left=maxf(0,drop_left-1.0/RATE)
		smooth_rpm=move_toward(smooth_rpm,maxf(700,t.rpm),18000.0/RATE)
		gain=move_toward(gain,(0.10+throttle*0.14) if t.running else 0.0,2.0/RATE)
		var hz := smooth_rpm/30.0
		if start_left>0.25: hz=35.0+(0.7-start_left)*80.0
		phase=fposmod(phase+TAU*hz/RATE,TAU)
		var white := noise.randf_range(-1,1)
		filtered_noise=lerpf(filtered_noise,white,0.18)
		var motor := sin(phase)*0.55+sin(phase*2)*0.25+sin(phase*3)*0.12
		var limiter := 0.6 if smooth_rpm>6250 and sin(clock*TAU*24)>0 else 1.0
		var v := motor*gain*limiter*(0.45 if shift_left>0 else 1.0)
		v+=filtered_noise*throttle*gain*0.3
		if start_left>0 and t.running: v+=sin(clock*TAU*48)*0.07*start_left
		if shift_left>0: v+=filtered_noise*shift_left*0.3
		if drop_left>0: v+=sin(phase*0.5)*drop_left*0.16
		v+=white*braking*0.025
		v+=(sin(clock*TAU*1450)*0.045+white*0.06)*tire*clampf(speed/8,0,1)
		if horn_on: v+=(sin(clock*TAU*440)+sin(clock*TAU*554))*0.10
		v=clampf(v,-0.85,0.85)
		playback.push_frame(Vector2(v,v))

extends Node
# Original procedural PCM loops; native Godot mixing, no per-sample render loop.
const RATE := 16000
static var cache := {}
var car: VehicleBody3D
var layers: Array[AudioStreamPlayer] = []
var references := PackedFloat32Array()
var noises := {}
var starter: AudioStreamPlayer
var shift_sound: AudioStreamPlayer
var grind_sound: AudioStreamPlayer
var lifecycle: AudioStreamPlayer
var ignition: AudioStreamPlayer
var last_ignition := 0
var last_shift := 0
var last_grind := 0
var last_stall := 0
var last_shutdown := 0
var frequency := 0.0
var audible_rpm := 800.0
var engine_mix := 0.0
# Boost perceived engine loudness while limiting peaks from simultaneous layers.
const ENGINE_GAIN := 1.9
const MASTER_HEADROOM := 0.90
var layer_weights := PackedFloat32Array()
func _ready() -> void:
	references=car.transmission.config.audio_references
	layer_weights.resize(references.size())
	for i in range(references.size()):
		layers.append(_player(_stream("engine"+str(i),references[i]*car.transmission.config.engine_cylinders/120.0,1.5,true)))
	for kind in ["rolling","wind","brake","horn"]:
		noises[kind]=_player(_stream(kind,0,1.5,true))
	starter=_player(_stream("starter",0,1.5,true))
	shift_sound=_player(_stream("shift",0,0.12,false),false)
	grind_sound=_player(_stream("grind",0,0.22,false),false)
	lifecycle=_player(_stream("stall",0,0.4,false),false)
	ignition=_player(_stream("ignition",0,0.10,false),false)
	last_ignition=car.transmission.engine.ignition_serial
	last_stall=car.transmission.engine.stall_serial
	last_shutdown=car.transmission.engine.shutdown_serial
func _player(stream: AudioStreamWAV,looping: bool = true) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream=stream
	p.volume_db=-80
	add_child(p)
	if looping: p.play()
	return p
static func _stream(kind: String,hz: float,duration: float,looping: bool) -> AudioStreamWAV:
	var key := kind+str(hz)+str(duration)
	if cache.has(key): return cache[key]
	var bytes := PackedByteArray()
	var frames := roundi(duration*RATE)
	bytes.resize(frames*2)
	var rng := RandomNumberGenerator.new()
	rng.seed=32003
	var filtered := 0.0
	for i in range(frames):
		var time := float(i)/RATE
		var phase := TAU*hz*time
		var n := rng.randf_range(-1,1)
		filtered=lerpf(filtered,n,0.14 if kind!="wind" else 0.025)
		var v := 0.0
		if kind.begins_with("engine"):
			var index := int(kind.trim_prefix("engine"))
			v=sin(phase)*0.19+sin(phase*2)*0.08+sin(phase*3)*0.045
			v+=sin(phase*4)*(0.012+index*0.012)+sin(phase*6)*index*0.008
		elif kind=="horn": v=(sin(TAU*440*time)+sin(TAU*554*time))*0.16
		elif kind=="starter": v=sin(TAU*45*time)*0.1+sin(TAU*130*time)*0.08+filtered*0.12
		elif kind=="skid": v=filtered*0.04 # No high-frequency tire squeal
		elif kind=="shift": v=filtered*0.65*exp(-time*28)+sin(TAU*250*time)*0.1*exp(-time*40)
		elif kind=="ignition": v=filtered*0.5*exp(-time*45)
		elif kind=="grind": v=n*0.23+sin(TAU*180*time)*0.12
		elif kind=="stall" or kind=="shutdown": v=sin(TAU*(40*time-30*time*time))*0.25*exp(-time*8)+filtered*0.08
		else: v=filtered*0.5
		# Noise loops have short edge fades; the harmonic engine loops have
		# integer cycle counts and are inherently continuous at their seam.
		if not kind.begins_with("engine"):
			v*=minf(1,minf(float(i)/80,float(frames-1-i)/80))
		var sample := roundi(clampf(v,-1,1)*32767)
		bytes[i*2]=sample&255
		bytes[i*2+1]=(sample>>8)&255
	var stream := AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=RATE
	stream.data=bytes
	if looping:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		stream.loop_end=frames
	cache[key]=stream
	return stream
func _volume(p: AudioStreamPlayer,target: float,delta: float,rate: float = 14.0) -> void:
	target=clampf(target*MASTER_HEADROOM,0.0,0.92) # Keep individual layers below full scale.
	var gain := db_to_linear(p.volume_db)
	gain=lerpf(gain,target,1-exp(-delta*rate))
	p.volume_db=linear_to_db(maxf(0.00001,gain))
	if target>0.0001 and not p.playing: p.play()
	elif target==0 and gain<0.0001 and p.playing: p.stop()
func _process(delta: float) -> void:
	if not is_instance_valid(car): return
	var t = car.transmission
	var e = t.engine
	if e.ignition_serial!=last_ignition:
		ignition.volume_db=-10
		ignition.play()
	audible_rpm=lerpf(audible_rpm,maxf(100,e.rpm),1-exp(-delta*18))
	frequency=audible_rpm*car.transmission.config.engine_cylinders/120.0
	var load := clampf(absf(e.load),0,1)
	engine_mix=(0.32+load*0.42+e.throttle*0.22) if e.running else 0.0
	if e.ignition_cut: engine_mix*=0.06
	for i in range(layers.size()):
		var weight := 0.0
		if i==0 and audible_rpm<=references[0]: weight=1
		elif i==layers.size()-1 and audible_rpm>=references[i]: weight=1
		elif audible_rpm>=references[i] and i+1<layers.size(): weight=1-clampf((audible_rpm-references[i])/(references[i+1]-references[i]),0,1)
		elif i>0 and audible_rpm<=references[i]: weight=clampf((audible_rpm-references[i-1])/(references[i]-references[i-1]),0,1)
		layer_weights[i]=weight
		layers[i].pitch_scale=clampf(audible_rpm/references[i],0.25,4)
		_volume(layers[i],weight*engine_mix*ENGINE_GAIN,delta,35 if e.ignition_cut else 14)
	_volume(starter,0.75 if e.state==1 else 0.0,delta)
	starter.pitch_scale=clampf(maxf(150,e.rpm)/400,0.5,1.7)
	if t.shift_serial!=last_shift:
		last_shift=t.shift_serial
		shift_sound.volume_db=-7
		shift_sound.play()
	if t.grind_serial!=last_grind:
		last_grind=t.grind_serial
		grind_sound.volume_db=-16
		grind_sound.play()
	if e.stall_serial!=last_stall or e.shutdown_serial!=last_shutdown:
		var stalled: bool=e.stall_serial!=last_stall
		last_stall=e.stall_serial
		last_shutdown=e.shutdown_serial
		lifecycle.stream=_stream("stall" if stalled else "shutdown",0,0.4,false)
		lifecycle.volume_db=-6
		lifecycle.play()
	last_ignition=e.ignition_serial
	var speed := car.linear_velocity.length()
	var road := clampf(speed/45,0,1) if car.wheel_physics.grounded else 0.0
	_volume(noises.rolling,road*0.45,delta)
	noises.rolling.pitch_scale=clampf(speed/16,0.5,2.0)
	_volume(noises.wind,pow(clampf(speed/65,0,1),1.7)*0.24,delta)
	_volume(noises.brake,car.effective_brake*clampf((speed-1)/12,0,1)*0.07,delta)
	// Tire squeal disabled: retain traction/skid physics without the irritating screech.
	_volume(noises.horn,0.8 if car.horn>0 or Input.is_key_pressed(KEY_H) else 0.0,delta,25)

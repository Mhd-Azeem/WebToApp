extends Node
# Synthesized motor sound avoids external copyrighted sound files.
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var car: VehicleBody3D
var phase := 0.0
var sample_rate := 22050.0
func _ready() -> void:
 player=AudioStreamPlayer.new()
 var stream := AudioStreamGenerator.new()
 stream.mix_rate=sample_rate
 stream.buffer_length=0.25
 player.stream=stream
 player.volume_db=-15.0
 add_child(player)
 player.play()
 playback=player.get_stream_playback() as AudioStreamGeneratorPlayback
func _process(_delta: float) -> void:
 if not is_instance_valid(car) or playback==null: return
 var rpm := clampf(float(car.transmission.rpm),700.0,7500.0)
 var throttle := clampf(float(car.gas),0.0,1.0)
 var frequency := rpm/60.0*2.0
 var amplitude := 0.12+throttle*0.13
 if not car.transmission.running: amplitude=0.0
 var frames := mini(playback.get_frames_available(),1024)
 for i in range(frames):
  phase=fposmod(phase+TAU*frequency/sample_rate,TAU)
  var wave := sin(phase)*0.66+sin(phase*2.0)*0.23+sin(phase*0.5)*0.11
  var v := wave*amplitude
  playback.push_frame(Vector2(v,v))

extends RefCounted

enum Preset { ULTRA_LOW, LOW, MEDIUM, HIGH, AUTO }
const NAMES := ["Ultra Low", "Low", "Medium", "High", "Auto"]
const SCALES := [0.60, 0.75, 0.90, 1.0]
const DISTANCES := [150.0, 190.0, 235.0, 285.0]
const VEGETATION := [0.0, 0.35, 0.70, 1.0]
const TRAFFIC := [4, 6, 8, 10]

var selected := Preset.LOW
var tier := Preset.LOW
var target_fps := 30
var average_ms := 0.0
var sample_time := 0.0
var sample_frames := 0
var slow_windows := 0
var fast_windows := 0

func choose(preset: int, fps: int) -> void:
	selected = clampi(preset, Preset.ULTRA_LOW, Preset.AUTO)
	target_fps = 60 if fps == 60 else 30
	tier = (Preset.MEDIUM if target_fps == 60 else Preset.LOW) if selected == Preset.AUTO else selected
	reset_sample()

func reset_sample() -> void:
	sample_time = 0
	sample_frames = 0
	slow_windows = 0
	fast_windows = 0

func sample(delta: float) -> bool:
	if selected != Preset.AUTO: return false
	sample_time += minf(delta, 0.25)
	sample_frames += 1
	if sample_time < 2.0: return false
	average_ms = sample_time * 1000.0 / sample_frames
	sample_time = 0
	sample_frames = 0
	var budget := 1000.0 / target_fps
	slow_windows = slow_windows + 1 if average_ms > budget * 1.12 else 0
	fast_windows = fast_windows + 1 if average_ms < budget * 1.025 else 0
	if slow_windows >= 2 and tier > Preset.ULTRA_LOW:
		tier -= 1
		reset_sample()
		return true
	if fast_windows >= 8 and tier < Preset.HIGH:
		tier += 1
		reset_sample()
		return true
	return false

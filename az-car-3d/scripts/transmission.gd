extends RefCounted
class_name SriTransmission

enum Mode { MANUAL, AUTOMATIC }
var mode := Mode.MANUAL
var gear := 0
var selector := "P"
var clutch := 0.0
var rpm := 850.0
var running := true
var auto_gear := 1
var message := "Hold clutch, select 1, release clutch gently and accelerate"
const RATIOS := [0.0, 3.55, 2.05, 1.36, 1.03, 0.82]

func shift(next: int, speed: float) -> bool:
	if mode != Mode.MANUAL or clutch < 0.85 or next < -1 or next > 5:
		message = "Manual shifts require the clutch pedal"
		return false
	if (next == -1 and absf(speed) > 0.5) or (next > 0 and speed < -0.5):
		message = "Stop before changing direction"
		return false
	gear = next
	message = "Gear engaged"
	return true

func select(next: String, speed: float, brake: float) -> bool:
	if mode != Mode.AUTOMATIC or next not in ["P", "R", "N", "D"]: return false
	if next in ["P", "R", "D"] and (absf(speed) > 0.5 or brake < 0.5):
		message = "Stop and hold brake before selecting P / R / D"
		return false
	selector = next
	message = "Automatic " + next
	return true

func toggle(speed: float) -> void:
	if absf(speed) > 0.5:
		message = "Stop before changing transmission"
		return
	mode = Mode.AUTOMATIC if mode == Mode.MANUAL else Mode.MANUAL
	gear = 0
	selector = "P"
	running = true

func restart() -> void:
	if clutch > 0.85 or gear == 0 or mode == Mode.AUTOMATIC:
		running = true
		rpm = 850.0
		message = "Engine started"

func ratio(speed: float) -> float:
	if mode == Mode.MANUAL: return -3.3 if gear == -1 else RATIOS[gear]
	if selector == "R": return -3.3
	if selector != "D": return 0.0
	var kph := absf(speed) * 3.6
	var thresholds := [17.0, 34.0, 56.0, 82.0]
	# Hysteresis prevents hunting around a shift threshold.
	if auto_gear < 5 and kph > thresholds[auto_gear - 1] + 2.0: auto_gear += 1
	if auto_gear > 1 and kph < thresholds[auto_gear - 2] - 3.0: auto_gear -= 1
	return RATIOS[auto_gear]

func update(delta: float, speed: float, gas: float) -> float:
	var r := ratio(speed)
	var engagement := 1.0 - clutch if mode == Mode.MANUAL else 1.0
	var wheel_rpm := absf(speed) / (TAU * 0.34) * 60.0 * absf(r) * 3.9
	var free_rpm := 850.0 + gas * 5650.0
	var target := lerpf(free_rpm, wheel_rpm, engagement) if r != 0.0 else free_rpm
	if mode == Mode.AUTOMATIC: target = maxf(850.0 + gas * 700.0, target)
	rpm = lerpf(rpm, target, minf(1.0, delta * 5.0))
	if mode == Mode.MANUAL and r != 0.0 and engagement > 0.95 and rpm < 450.0 and gas < 0.15:
		running = false
		message = "Engine stalled: hold clutch and press START"
	if not running:
		rpm = 0.0
		return 0.0
	if rpm > 6400.0: gas = 0.0
	var torque := 160.0 * (0.65 + 0.35 * sin(clampf(rpm / 6500.0, 0, 1) * PI))
	return gas * torque * r * 3.9 / 0.34 * engagement

func display() -> String:
	if mode == Mode.AUTOMATIC: return "AT " + selector + (" / " + str(auto_gear) if selector == "D" else "")
	return "MT " + ("R" if gear == -1 else ("N" if gear == 0 else str(gear)))

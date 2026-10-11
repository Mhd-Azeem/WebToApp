extends RefCounted
class_name AZTransmission

enum Mode { MANUAL, AUTOMATIC }
var mode: Mode = Mode.MANUAL
var gear: int = 0 # -1 reverse, 0 neutral, 1..5 forward; automatic uses -2 park, -1 reverse, 0 neutral, 1 drive
var clutch: float = 1.0 # 1 means pedal pressed
var rpm: float = 850.0
var engine_running := true
const RATIOS := {-1: -3.30, 1: 3.55, 2: 2.05, 3: 1.36, 4: 1.03, 5: 0.82}
const FINAL_DRIVE := 3.9

func select_manual(next_gear: int, speed_mps: float) -> bool:
    if mode != Mode.MANUAL or clutch < 0.85:
        return false
    if next_gear < -1 or next_gear > 5:
        return false
    if next_gear == -1 and absf(speed_mps) > 0.5:
        return false
    gear = next_gear
    return true

func select_automatic(selector: int, speed_mps: float) -> bool:
    if mode != Mode.AUTOMATIC or selector < -2 or selector > 1:
        return false
    if selector == -2 and absf(speed_mps) > 0.3:
        return false
    if selector == -1 and absf(speed_mps) > 0.5:
        return false
    gear = selector
    return true

func drive_ratio(speed_mps: float) -> float:
    if mode == Mode.MANUAL:
        return RATIOS.get(gear, 0.0)
    if gear == -1:
        return RATIOS[-1]
    if gear != 1:
        return 0.0
    var kph := absf(speed_mps) * 3.6
    if kph < 17.0: return RATIOS[1]
    if kph < 34.0: return RATIOS[2]
    if kph < 56.0: return RATIOS[3]
    if kph < 82.0: return RATIOS[4]
    return RATIOS[5]

func toggle_mode(speed_mps: float) -> void:
    if absf(speed_mps) > 0.5: return
    mode = Mode.AUTOMATIC if mode == Mode.MANUAL else Mode.MANUAL
    gear = -2 if mode == Mode.AUTOMATIC else 0

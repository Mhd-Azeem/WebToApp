extends Node3D

const Transmission = preload("res://scripts/transmission.gd")
var transmission = Transmission.new()
var speed_mps := 0.0
var heading := 0.0
var car: Node3D
var camera: Camera3D
var hud: Label
var throttle := 0.0
var brake := 0.0
var steer := 0.0
var money := 10000
var owned_cars := ["Starter Sedan"]
var current_car := "Starter Sedan"
var upgrades := {"engine": 0, "brakes": 0, "grip": 0}
var mission_index := 0
var mission_target := Vector3(0, 0, -150)
var garage_position := Vector3(22, 0, 10)
var distance_to_target := 0.0
const MISSIONS := [{"name":"First Delivery","reward":500,"target":Vector3(0,0,-150)},{"name":"Highway Run","reward":1000,"target":Vector3(0,0,-450)},{"name":"Return to Town","reward":750,"target":Vector3(20,0,20)}]

func _ready() -> void:
    _build_world()
    _build_car()
    camera = get_node("Camera3D")
    _build_hud()
    _load_game()

func _make_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    mesh.material = material
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.position = pos
    parent.add_child(node)
    return node

func _build_world() -> void:
    _make_box(self, Vector3(0,-0.25,-180), Vector3(1100,0.5,1100), Color(0.24,0.43,0.23))
    _make_box(self, Vector3(0,0,-180), Vector3(18,0.05,1050), Color(0.16,0.17,0.19))
    _make_box(self, Vector3(0,0,-180), Vector3(0.18,0.06,1050), Color(0.95,0.79,0.2))
    for i in range(24):
        var z := 65.0 - i * 35.0
        for side in [-1,1]:
            var x := float(side) * 35.0
            var h := 8.0 + float(i % 5) * 5.0
            _make_box(self, Vector3(x,h/2.0,z), Vector3(13,h,16), Color(0.38 + float(i%3)*0.1,0.43,0.5))
    _make_box(self, Vector3(22,0.1,10), Vector3(18,0.2,20), Color(0.24,0.25,0.27))
    _make_box(self, Vector3(22,4,-1), Vector3(19,8,2), Color(0.16,0.34,0.56))

func _build_car() -> void:
    car = Node3D.new()
    car.name = "PlayerCar"
    add_child(car)
    _make_box(car, Vector3(0,0.9,0), Vector3(1.9,0.7,4.2), Color(0.08,0.28,0.8))
    _make_box(car, Vector3(0,1.5,0.2), Vector3(1.6,0.65,2.1), Color(0.11,0.18,0.24))
    for x in [-1.0,1.0]:
        for z in [-1.35,1.35]:
            _make_box(car, Vector3(x,0.48,z), Vector3(0.3,0.85,0.85), Color(0.035,0.035,0.04))

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = Label.new()
    hud.position = Vector2(18,18)
    hud.add_theme_font_size_override("font_size",22)
    layer.add_child(hud)
    var instructions := Label.new()
    instructions.text = "Keyboard: W/S throttle/brake, A/D steer, C clutch, 1-5 gears, R reverse, N neutral, M mode, G garage, B buy, U upgrade, F save"
    instructions.position = Vector2(18,145)
    layer.add_child(instructions)
    var controls := Control.new()
    controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(controls)
    _touch_button(controls,"LEFT",Vector2(20,540),Vector2(90,70),-1)
    _touch_button(controls,"RIGHT",Vector2(120,540),Vector2(90,70),1)
    _touch_button(controls,"BRAKE",Vector2(910,540),Vector2(100,70),2)
    _touch_button(controls,"GAS",Vector2(1030,540),Vector2(100,70),3)
    _touch_button(controls,"CLUTCH",Vector2(790,540),Vector2(110,70),4)
    _touch_button(controls,"GEAR +",Vector2(1140,450),Vector2(115,60),5)
    _touch_button(controls,"GEAR -",Vector2(1140,520),Vector2(115,60),6)
    _touch_button(controls,"MODE",Vector2(1140,30),Vector2(115,55),7)
    _touch_button(controls,"GARAGE",Vector2(1140,95),Vector2(115,55),8)
    _touch_button(controls,"BUY",Vector2(1140,160),Vector2(115,55),9)
    _touch_button(controls,"UPGRADE",Vector2(1140,225),Vector2(115,55),10)
    _touch_button(controls,"SAVE",Vector2(1140,290),Vector2(115,55),11)

func _touch_button(parent: Control, title: String, pos: Vector2, size: Vector2, action: int) -> void:
    var button := Button.new()
    button.text = title
    button.position = pos
    button.size = size
    parent.add_child(button)
    button.button_down.connect(func(): _button_action(action,true))
    button.button_up.connect(func(): _button_action(action,false))

func _button_action(action: int, down: bool) -> void:
    if action == -1: steer = -1.0 if down else 0.0
    elif action == 1: steer = 1.0 if down else 0.0
    elif action == 2: brake = 1.0 if down else 0.0
    elif action == 3: throttle = 1.0 if down else 0.0
    elif action == 4: transmission.clutch = 1.0 if down else 0.0
    elif not down: return
    elif action == 5: _shift(1)
    elif action == 6: _shift(-1)
    elif action == 7: transmission.toggle_mode(speed_mps)
    elif action == 8: _visit_garage()
    elif action == 9: _buy_car()
    elif action == 10: _upgrade()
    elif action == 11: _save_game()

func _shift(direction: int) -> void:
    if transmission.mode == Transmission.Mode.MANUAL:
        transmission.select_manual(clampi(transmission.gear+direction,-1,5),speed_mps)
    else:
        transmission.select_automatic(clampi(transmission.gear+direction,-2,1),speed_mps)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        var key := event.keycode
        if key == KEY_M: transmission.toggle_mode(speed_mps)
        elif key == KEY_G: _visit_garage()
        elif key == KEY_B: _buy_car()
        elif key == KEY_U: _upgrade()
        elif key == KEY_F: _save_game()
        elif key == KEY_N: transmission.select_manual(0,speed_mps)
        elif key == KEY_R: transmission.select_manual(-1,speed_mps)
        elif key >= KEY_1 and key <= KEY_5: transmission.select_manual(key-KEY_0,speed_mps)

func _physics_process(delta: float) -> void:
    var keyboard_throttle := 1.0 if Input.is_key_pressed(KEY_W) else 0.0
    var keyboard_brake := 1.0 if Input.is_key_pressed(KEY_S) else 0.0
    var keyboard_steer := float(Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_A))
    var t: float = maxf(throttle,keyboard_throttle)
    var b: float = maxf(brake,keyboard_brake)
    var s: float = steer if absf(steer)>0.01 else keyboard_steer
    if Input.is_key_pressed(KEY_C): transmission.clutch=1.0
    var ratio: float = transmission.drive_ratio(speed_mps)
    var engagement: float = 1.0-transmission.clutch if transmission.mode == Transmission.Mode.MANUAL else 1.0
    var drive: float = signf(ratio)*t*7.0*engagement*(1.0+upgrades.engine*0.15)
    if not transmission.engine_running: drive=0.0
    var drag: float = speed_mps*absf(speed_mps)*0.003 + speed_mps*0.12
    var braking: float = b*12.0*signf(speed_mps)
    speed_mps += (drive-drag-braking)*delta
    if absf(speed_mps)<0.04 and t==0.0: speed_mps=0.0
    speed_mps=clampf(speed_mps,-12.0,48.0)
    heading += s*speed_mps*0.018*delta
    car.rotation.y=heading
    car.position += Vector3(-sin(heading),0,-cos(heading))*speed_mps*delta
    camera.position = camera.position.lerp(car.position+Vector3(sin(heading)*10,5,cos(heading)*10),minf(1.0,delta*5.0))
    camera.look_at(car.position+Vector3(0,1,0))
    transmission.rpm=clampf(850.0+absf(speed_mps*ratio)*115.0,850.0,6500.0)
    _check_mission()
    var mode_name := "MT" if transmission.mode==Transmission.Mode.MANUAL else "AT"
    hud.text="AZ CAR 3D | %s | Gear %s | %d km/h | %d RPM\nCash: $%d | Car: %s | Engine upgrade: %d\nMission: %s (%dm) | Garage: drive near the blue building" % [mode_name,str(transmission.gear),roundi(absf(speed_mps)*3.6),roundi(transmission.rpm),money,current_car,upgrades.engine,MISSIONS[mission_index%MISSIONS.size()].name,roundi(distance_to_target)]

func _check_mission() -> void:
    var mission: Dictionary=MISSIONS[mission_index%MISSIONS.size()]
    mission_target=mission.target
    distance_to_target=car.position.distance_to(mission_target)
    if distance_to_target<12.0:
        money+=mission.reward
        mission_index+=1
        _save_game()

func _near_garage() -> bool:
    return car.position.distance_to(garage_position)<25.0 and absf(speed_mps)<1.0

func _visit_garage() -> void:
    if _near_garage(): speed_mps=0.0

func _buy_car() -> void:
    if not _near_garage() or money<6000 or "Sport Coupe" in owned_cars: return
    money-=6000
    owned_cars.append("Sport Coupe")
    current_car="Sport Coupe"
    _save_game()

func _upgrade() -> void:
    if not _near_garage() or money<1000 or upgrades.engine>=5: return
    money-=1000
    upgrades.engine+=1
    _save_game()

func _save_game() -> void:
    var data: Dictionary={"money":money,"owned_cars":owned_cars,"current_car":current_car,"upgrades":upgrades,"mission_index":mission_index}
    var file:=FileAccess.open("user://az_car_save.json",FileAccess.WRITE)
    if file: file.store_string(JSON.stringify(data))

func _load_game() -> void:
    if not FileAccess.file_exists("user://az_car_save.json"): return
    var file:=FileAccess.open("user://az_car_save.json",FileAccess.READ)
    if not file: return
    var data=JSON.parse_string(file.get_as_text())
    if not data is Dictionary: return
    money=int(data.get("money",money))
    owned_cars=Array(data.get("owned_cars",owned_cars))
    current_car=str(data.get("current_car",current_car))
    upgrades=Dictionary(data.get("upgrades",upgrades))
    mission_index=int(data.get("mission_index",mission_index))

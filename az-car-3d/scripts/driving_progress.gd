extends RefCounted

const SAVE_PATH := "user://driving-progress.cfg"
const VEHICLES := ["Sport coupe", "City hatchback", "Touring SUV"]
const KINDS := ["sedan", "hatchback", "suv"]
const PAINTS := [Color(0.19,0.25,0.30),Color(0.74,0.15,0.10),Color(0.13,0.38,0.63),Color(0.89,0.89,0.84),Color(0.25,0.46,0.21)]
const WHEELS := [Color(0.53,0.60,0.66),Color(0.22,0.24,0.25),Color(0.77,0.61,0.39)]
const MISSIONS := ["Parking practice", "Coastal delivery", "Highland drive"]
const FINISH := [1,4,2]
const REWARD := [75,180,140]

var vehicle := 0
var paint := 0
var wheels := 0
var fuel := PackedFloat32Array([45,45,45])
var wear := PackedFloat32Array([0,0,0])
var credits := 150
var distance_m := 0.0
var achievements := PackedStringArray()
var completed := PackedInt32Array()
var mission := -1
var delivery_loaded := false

func load_from(path := SAVE_PATH) -> void:
	var state := ConfigFile.new()
	if state.load(path) != OK: return
	vehicle = clampi(int(state.get_value("garage","vehicle",0)),0,VEHICLES.size()-1)
	paint = clampi(int(state.get_value("garage","paint",0)),0,PAINTS.size()-1)
	wheels = clampi(int(state.get_value("garage","wheels",0)),0,WHEELS.size()-1)
	var saved_fuel = state.get_value("garage","fuel",fuel)
	var saved_wear = state.get_value("garage","wear",wear)
	if saved_fuel is PackedFloat32Array and saved_fuel.size() == VEHICLES.size():
		for i in range(fuel.size()): fuel[i] = clampf(saved_fuel[i],0,45)
	if saved_wear is PackedFloat32Array and saved_wear.size() == VEHICLES.size():
		for i in range(wear.size()): wear[i] = clampf(saved_wear[i],0,1)
	credits = maxi(0,int(state.get_value("progress","credits",150)))
	distance_m = maxf(0,float(state.get_value("progress","distance",0.0)))
	var earned = state.get_value("progress","achievements",achievements)
	if earned is PackedStringArray: achievements = earned
	var finished = state.get_value("progress","completed",completed)
	if finished is PackedInt32Array: completed = finished
	mission = clampi(int(state.get_value("progress","mission",-1)),-1,MISSIONS.size()-1)
	delivery_loaded = bool(state.get_value("progress","delivery_loaded",false)) and mission == 1

func save_to(path := SAVE_PATH) -> Error:
	var state := ConfigFile.new()
	state.set_value("garage","vehicle",vehicle)
	state.set_value("garage","paint",paint)
	state.set_value("garage","wheels",wheels)
	state.set_value("garage","fuel",fuel)
	state.set_value("garage","wear",wear)
	state.set_value("progress","credits",credits)
	state.set_value("progress","distance",distance_m)
	state.set_value("progress","achievements",achievements)
	state.set_value("progress","completed",completed)
	state.set_value("progress","mission",mission)
	state.set_value("progress","delivery_loaded",delivery_loaded)
	var temporary := path + ".tmp"
	var error := state.save(temporary)
	return DirAccess.rename_absolute(temporary,path) if error == OK else error

func start(index: int) -> void:
	mission = clampi(index,-1,MISSIONS.size()-1)
	delivery_loaded = false

func target() -> int:
	if mission < 0: return -1
	return 0 if mission == 1 and not delivery_loaded else FINISH[mission]

func arrive(destination: int) -> String:
	if mission < 0 or destination != target(): return ""
	if mission == 1 and not delivery_loaded:
		delivery_loaded = true
		return "Cargo loaded. Continue to the coastal lay-by."
	var index := mission
	if index not in completed: completed.append(index)
	credits += REWARD[index]
	award("First mission")
	if completed.size() == MISSIONS.size(): award("Island driver")
	start(-1)
	return "%s complete · +%d credits" % [MISSIONS[index],REWARD[index]]

func award(name: String) -> void:
	if name not in achievements: achievements.append(name)

extends Node

const Progress = preload("res://scripts/driving_progress.gd")
const Navigation = preload("res://scripts/road_navigation.gd")
const Region = preload("res://scripts/regional_road.gd")
const Minimap = preload("res://scripts/ui/minimap.gd")
var progress := Progress.new()
var navigation := Navigation.new()
var car: VehicleBody3D
var panel: PanelContainer
var map: Control
var status: Label
var summary: Label
var route_selection: OptionButton
var mission_selection: OptionButton
var vehicle_selection: OptionButton
var elapsed := 0.0
var save_elapsed := 0.0
var selection := -1
var nearby := -1

func setup(layer: CanvasLayer, vehicle: VehicleBody3D) -> void:
	car = vehicle
	car.road_navigation=navigation
	progress.load_from()
	_apply_vehicle()
	map=Minimap.new()
	map.navigation=navigation
	map.position=Vector2(16,185)
	map.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(map)
	status=Label.new()
	status.position=Vector2(338,112)
	status.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(status)
	panel=PanelContainer.new()
	panel.position=Vector2(485,190)
	panel.custom_minimum_size=Vector2(330,340)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",7)
	panel.add_child(column)
	summary=Label.new()
	column.add_child(summary)
	var route_items := ["GPS off"]
	for location in Region.DESTINATIONS: route_items.append(location[0])
	route_selection=_choice(column,route_items,0)
	route_selection.item_selected.connect(func(index: int): selection=index-1; _update_map())
	var missions := ["Free roam"]
	missions.append_array(Progress.MISSIONS)
	mission_selection=_choice(column,missions,progress.mission+1)
	mission_selection.item_selected.connect(func(index: int):
		progress.start(index-1)
		save()
		_update_map())
	vehicle_selection=_choice(column,Progress.VEHICLES,progress.vehicle)
	vehicle_selection.item_selected.connect(_switch_vehicle)
	_choice(column,["Graphite paint","Red paint","Blue paint","Pearl paint","Olive paint"],progress.paint).item_selected.connect(func(index: int):
		progress.paint=index
		_apply_appearance()
		save())
	_choice(column,["Silver alloys","Dark alloys","Bronze alloys"],progress.wheels).item_selected.connect(func(index: int):
		progress.wheels=index
		_apply_appearance()
		save())
	_button(column,"Interact at destination  (G)",interact)
	_button(column,"Close",panel.hide)
	panel.hide()
	_update_map()

func _choice(parent: Control, labels: Array, index: int) -> OptionButton:
	var option := OptionButton.new()
	for label in labels: option.add_item(label)
	option.custom_minimum_size.y=38
	option.select(index)
	parent.add_child(option)
	return option

func _button(parent: Control, title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text=title
	button.custom_minimum_size.y=38
	button.pressed.connect(callback)
	parent.add_child(button)

func _switch_vehicle(index: int) -> void:
	if car.linear_velocity.length()>1.0:
		status.text="Stop to switch vehicles"
		vehicle_selection.select(progress.vehicle)
		return
	_capture_car()
	progress.vehicle=index
	_apply_vehicle()
	save()

func _apply_vehicle() -> void:
	car.fuel_litres=progress.fuel[progress.vehicle]
	car.fuel_exhausted=car.fuel_litres<=0.0
	if car.fuel_exhausted and car.transmission.running: car.transmission.start_stop()
	car.damage=progress.wear[progress.vehicle]
	car.apply_garage_vehicle(Progress.KINDS[progress.vehicle],progress.vehicle)
	_apply_appearance()

func _apply_appearance() -> void:
	car.apply_appearance(Progress.PAINTS[progress.paint],Progress.WHEELS[progress.wheels])

func _capture_car() -> void:
	progress.fuel[progress.vehicle]=car.fuel_litres
	progress.wear[progress.vehicle]=car.damage

func save() -> void:
	if not is_instance_valid(car): return
	_capture_car()
	if progress.save_to()!=OK: status.text="Progress could not be saved"

func interact() -> void:
	if nearby<0 or car.linear_velocity.length()>1.1:
		status.text="Stop at the marked destination to interact."
		return
	var message := progress.arrive(nearby)
	if not message.is_empty():
		status.text=message
		mission_selection.select(progress.mission+1)
	elif nearby in [0,3]:
		var litres := minf(45.0-car.fuel_litres,float(progress.credits)/2.0)
		progress.credits -= ceili(litres*2.0)
		car.fuel_litres+=litres
		car.fuel_exhausted=car.fuel_litres<=0
		var repaired: bool = car.damage_enabled and car.damage>0.0 and progress.credits>=25
		if repaired:
			progress.credits-=25
			car.damage=0
		status.text="Added %.1f L%s" % [litres," · Repaired" if repaired else ""]
	else:
		status.text="Destination reached"
		selection=-1
		route_selection.select(0)
	save()
	_update_map()

func _process(delta: float) -> void:
	if not is_instance_valid(car): return
	progress.distance_m += car.linear_velocity.length()*delta if car.wheel_physics.grounded else 0.0
	elapsed+=delta
	save_elapsed+=delta
	if elapsed>=0.35:
		elapsed=0
		_update_map()
	if save_elapsed>=15.0:
		save_elapsed=0
		save()

func _update_map() -> void:
	nearby=-1
	for i in range(Region.DESTINATIONS.size()):
		var point: Vector3 = Region.DESTINATIONS[i][1]
		if car.position.distance_to(point)<14.0:
			nearby=i
			break
	if progress.distance_m>=1000.0: progress.award("First kilometre")
	summary.text="%d credits · %.1f L · %d%% wear\n%d/%d missions · %d achievements" % [
		progress.credits,car.fuel_litres,roundi(car.damage*100),
		progress.completed.size(),Progress.MISSIONS.size(),progress.achievements.size()]
	if nearby>=0: summary.text+="\n"+Region.DESTINATIONS[nearby][0]
	map.position_3d=car.position
	map.forward=car.global_basis.z
	var target := progress.target()
	map.highlighted=target if target>=0 else selection
	map.route=navigation.route(car.position,Region.DESTINATIONS[map.highlighted][1]) if map.highlighted>=0 else PackedVector3Array()
	map.queue_redraw()

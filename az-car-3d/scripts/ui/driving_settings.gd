extends PanelContainer
signal traffic_changed(enabled: bool)
signal quality_changed(low: bool)
signal transmission_changed(mode: int)
var transmission_selector: OptionButton
var traffic_toggle: CheckButton
var quality_toggle: CheckButton
var shadow_toggle: CheckButton
var saved := ConfigFile.new()
func _ready() -> void:
	position=Vector2(350,130)
	custom_minimum_size=Vector2(330,220)
	var backing := StyleBoxFlat.new()
	backing.bg_color=Color(0.025,0.045,0.06,0.96)
	backing.content_margin_left=12
	backing.content_margin_right=12
	backing.content_margin_top=12
	backing.content_margin_bottom=12
	backing.set_corner_radius_all(8)
	add_theme_stylebox_override("panel",backing)
	var column := VBoxContainer.new()
	add_child(column)
	var title := Label.new()
	title.text="  SETTINGS"
	title.add_theme_font_size_override("font_size",24)
	column.add_child(title)
	traffic_toggle=CheckButton.new()
	traffic_toggle.text="Traffic"
	traffic_toggle.custom_minimum_size=Vector2(300,60)
	column.add_child(traffic_toggle)
	quality_toggle=CheckButton.new()
	quality_toggle.text="Performance mode (30 FPS)"
	quality_toggle.custom_minimum_size=Vector2(300,60)
	column.add_child(quality_toggle)
	shadow_toggle=CheckButton.new()
	shadow_toggle.text="Shadows (higher GPU cost)"
	column.add_child(shadow_toggle)
	shadow_toggle.toggled.connect(func(_value: bool): quality_changed.emit(quality_toggle.button_pressed))
	transmission_selector=OptionButton.new()
	transmission_selector.add_item("Manual transmission",0)
	transmission_selector.add_item("Automatic transmission",1)
	transmission_selector.custom_minimum_size=Vector2(300,52)
	column.add_child(transmission_selector)
	transmission_selector.item_selected.connect(func(index: int): transmission_changed.emit(index))
	var hint := Label.new()
	hint.text="Stop before changing transmission\nGas: press 25%, drag UP for more\nBrake / clutch: slide down to reduce"
	hint.add_theme_font_size_override("font_size",14)
	column.add_child(hint)
	saved.load("user://driving-settings.cfg")
	traffic_toggle.button_pressed=saved.get_value("driving","traffic",false)
	quality_toggle.button_pressed=saved.get_value("driving","low_quality",OS.has_feature("android"))
	traffic_toggle.toggled.connect(func(value: bool):
		_save("traffic",value)
		traffic_changed.emit(value))
	quality_toggle.toggled.connect(func(value: bool):
		_save("low_quality",value)
		quality_changed.emit(value))
	var close := Button.new()
	close.text="Close"
	close.custom_minimum_size=Vector2(300,48)
	close.pressed.connect(hide)
	column.add_child(close)
	hide()
func _save(key: String,value: bool) -> void:
	saved.set_value("driving",key,value)
	saved.save("user://driving-settings.cfg")

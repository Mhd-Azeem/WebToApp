extends PanelContainer
signal traffic_changed(enabled: bool)
signal quality_changed(low: bool)
signal transmission_changed(mode: int)
signal throttle_travel_changed(value: float)
var transmission_selector: OptionButton
var traffic_toggle: CheckButton
var quality_toggle: CheckButton
var shadow_toggle: CheckButton
var saved := ConfigFile.new()
var throttle_travel := 96.0
func _ready() -> void:
	position=Vector2(350,70)
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
	shadow_toggle.toggled.connect(func(value: bool):
		_save("shadows",value)
		quality_changed.emit(quality_toggle.button_pressed))
	transmission_selector=OptionButton.new()
	transmission_selector.add_item("Manual transmission",0)
	transmission_selector.add_item("Automatic transmission",1)
	transmission_selector.custom_minimum_size=Vector2(300,52)
	column.add_child(transmission_selector)
	var sensitivity_label := Label.new()
	sensitivity_label.text="Accelerator drag distance"
	column.add_child(sensitivity_label)
	var sensitivity := HSlider.new()
	sensitivity.min_value=48
	sensitivity.max_value=192
	sensitivity.step=8
	column.add_child(sensitivity)
	sensitivity.value_changed.connect(func(value: float):
		throttle_travel=value
		_save("throttle_travel",value)
		throttle_travel_changed.emit(value))
	var scale_option := OptionButton.new()
	for label in ["Render scale 75%","Render scale 100%"]:
		scale_option.add_item(label)
	column.add_child(scale_option)
	scale_option.item_selected.connect(func(index: int):
		get_viewport().scaling_3d_scale=0.75 if index==0 else 1.0
		_save("render_scale",index))
	if not OS.has_feature("android"):
		var resolution := OptionButton.new()
		for label in ["1280 Ã— 720","1600 Ã— 900","1920 Ã— 1080"]: resolution.add_item(label)
		column.add_child(resolution)
		resolution.item_selected.connect(func(index: int):
			get_window().size=[Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)][index])
	transmission_selector.item_selected.connect(func(index: int): transmission_changed.emit(index))
	var hint := Label.new()
	hint.text="Stop before changing transmission\nGas: press 25%, drag UP for more\nBrake / clutch: slide down to reduce"
	hint.add_theme_font_size_override("font_size",14)
	column.add_child(hint)
	saved.load("user://driving-settings.cfg")
	shadow_toggle.button_pressed=saved.get_value("driving","shadows",false)
	throttle_travel=saved.get_value("driving","throttle_travel",96.0)
	sensitivity.value=throttle_travel
	scale_option.select(saved.get_value("driving","render_scale",1))
	get_viewport().scaling_3d_scale=0.75 if scale_option.selected==0 else 1.0
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
func _save(key: String,value: Variant) -> void:
	saved.set_value("driving",key,value)
	saved.save("user://driving-settings.cfg")

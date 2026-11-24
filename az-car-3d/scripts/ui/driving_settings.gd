extends PanelContainer
signal traffic_changed(enabled: bool)
signal quality_changed
const Graphics = preload("res://scripts/adaptive_graphics.gd")
signal transmission_changed(mode: int)
signal throttle_travel_changed(value: float)
var transmission_selector: OptionButton
var traffic_toggle: CheckButton
var quality_selector: OptionButton
var fps_selector: OptionButton
var monitor_toggle: CheckButton
var render_scale_selector: OptionButton
var controls_column: VBoxContainer
var shadow_toggle: CheckButton
var saved := ConfigFile.new()
var throttle_travel := 96.0
func _ready() -> void:
	position=Vector2(350,70)
	custom_minimum_size=Vector2(430,560)
	var backing := StyleBoxFlat.new()
	backing.bg_color=Color(0.025,0.045,0.06,0.96)
	backing.content_margin_left=12
	backing.content_margin_right=12
	backing.content_margin_top=12
	backing.content_margin_bottom=12
	backing.set_corner_radius_all(8)
	add_theme_stylebox_override("panel",backing)
	var body := VBoxContainer.new()
	add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	controls_column = column
	var title := Label.new()
	title.text="  SETTINGS"
	title.add_theme_font_size_override("font_size",24)
	column.add_child(title)
	saved.load("user://driving-settings.cfg")
	traffic_toggle=CheckButton.new()
	traffic_toggle.text="Traffic"
	traffic_toggle.custom_minimum_size=Vector2(300,60)
	column.add_child(traffic_toggle)
	quality_selector = choice("Graphics preset", Graphics.NAMES, "preset",
		Graphics.Preset.LOW if saved.get_value("driving","low_quality",OS.has_feature("android")) else Graphics.Preset.HIGH)
	quality_selector.item_selected.connect(func(_index: int): quality_changed.emit())
	fps_selector = choice("Auto frame rate", ["30 FPS", "60 FPS"], "auto_fps", 0 if OS.has_feature("android") else 1)
	fps_selector.item_selected.connect(func(_index: int): quality_changed.emit())
	monitor_toggle = toggle("Performance monitor", "performance_monitor", false)
	shadow_toggle=CheckButton.new()
	shadow_toggle.text="Shadows (higher GPU cost)"
	column.add_child(shadow_toggle)
	shadow_toggle.toggled.connect(func(value: bool):
		_save("shadows",value)
		quality_changed.emit())
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
	render_scale_selector = choice("Render scale limit", ["75%", "100%"], "render_scale", 1)
	render_scale_selector.item_selected.connect(func(_index: int): quality_changed.emit())
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
	shadow_toggle.button_pressed=saved.get_value("driving","shadows",false)
	throttle_travel=saved.get_value("driving","throttle_travel",96.0)
	sensitivity.value=throttle_travel
	traffic_toggle.button_pressed=saved.get_value("driving","traffic",false)
	traffic_toggle.toggled.connect(func(value: bool):
		_save("traffic",value)
		traffic_changed.emit(value))
	var close := Button.new()
	close.text="Close"
	close.custom_minimum_size=Vector2(300,48)
	close.pressed.connect(hide)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(close)
	hide()
func _save(key: String,value: Variant) -> void:
	saved.set_value("driving",key,value)
	saved.save("user://driving-settings.cfg")

func choice(label: String, items: Array, key: String, fallback: int) -> OptionButton:
	var title := Label.new()
	title.text = label
	controls_column.add_child(title)
	var options := OptionButton.new()
	for item in items: options.add_item(item)
	controls_column.add_child(options)
	options.select(clampi(int(saved.get_value("driving", key, fallback)), 0, items.size() - 1))
	options.item_selected.connect(func(index: int): _save(key, index))
	return options

func toggle(label: String, key: String, fallback: bool) -> CheckButton:
	var button := CheckButton.new()
	button.text = label
	button.button_pressed = saved.get_value("driving", key, fallback)
	controls_column.add_child(button)
	button.toggled.connect(func(value: bool): _save(key, value))
	return button

func slider(label: String, key: String, minimum: float, maximum: float, fallback: float) -> HSlider:
	var title := Label.new()
	title.text = label
	controls_column.add_child(title)
	var control := HSlider.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = 0.05
	control.value = saved.get_value("driving", key, fallback)
	controls_column.add_child(control)
	control.drag_ended.connect(func(_changed: bool): _save(key, control.value))
	return control

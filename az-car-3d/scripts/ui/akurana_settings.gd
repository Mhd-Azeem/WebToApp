extends "res://scripts/ui/driving_settings.gd"
signal graphics_changed
var graphics := {}
var selectors := {}
const PRESETS = [
	{"scale":.7,"shadows":0,"textures":0,"vegetation":.25,"distance":180,"aa":0,"mirrors":0,"effects":0,"fps":30},
	{"scale":.85,"shadows":1,"textures":1,"vegetation":.5,"distance":300,"aa":1,"mirrors":1,"effects":1,"fps":60},
	{"scale":1.,"shadows":2,"textures":2,"vegetation":.75,"distance":450,"aa":2,"mirrors":2,"effects":1,"fps":60},
	{"scale":1.,"shadows":3,"textures":2,"vegetation":1.,"distance":650,"aa":3,"mirrors":3,"effects":2,"fps":0}]

func _ready() -> void:
	super._ready()
	position=Vector2(390,55)
	custom_minimum_size=Vector2(470,600)
	var column: VBoxContainer=get_child(0)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(450,580)
	add_child(scroll)
	column.reparent(scroll)
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for control in column.get_children():
		if control is OptionButton and control.item_count>0 and control.get_item_text(0).begins_with("Render scale"): control.hide()
	traffic_toggle.disabled=false
	traffic_toggle.text="Akurana traffic and pedestrians"
	traffic_toggle.button_pressed=bool(saved.get_value("driving","traffic",true))
	quality_toggle.hide()
	shadow_toggle.hide()
	var close: Node=column.get_child(column.get_child_count()-1)
	var preset:=int(saved.get_value("graphics","preset",0 if OS.has_feature("android") else 1))
	graphics=PRESETS[clampi(preset,0,3)].duplicate()
	for key in graphics: graphics[key]=saved.get_value("graphics",key,graphics[key])
	_option(column,"preset","Graphics preset",["Low","Medium","High","Ultra"],[0,1,2,3],preset)
	_option(column,"scale","Render resolution",["70%","85%","100%"],[.7,.85,1.],graphics.scale)
	_option(column,"shadows","Shadows",["Off","Low","Medium","High"],[0,1,2,3],graphics.shadows)
	_option(column,"textures","Texture quality",["Low / 256px asphalt","Medium / 512px maps","High / 1K PBR maps"],[0,1,2],graphics.textures)
	_option(column,"vegetation","Vegetation density",["25%","50%","75%","100%"],[.25,.5,.75,1.],graphics.vegetation)
	_option(column,"distance","Draw distance",["180 m","300 m","450 m","650 m"],[180,300,450,650],graphics.distance)
	_option(column,"aa","Anti-aliasing",["Off","2x MSAA","4x MSAA","8x MSAA"],[0,1,2,3],graphics.aa)
	_option(column,"mirrors","Mirror quality",["Low","Medium","High","Ultra"],[0,1,2,3],graphics.mirrors)
	_option(column,"effects","Environment effects",["Low","Medium","High"],[0,1,2],graphics.effects)
	_option(column,"fps","Frame limit",["30","60","90","Unlimited"],[30,60,90,0],graphics.fps)
	var hint:=Label.new()
	hint.text="Advanced effects follow renderer support.\nRenderer selection is a startup option."
	column.add_child(hint)
	var credits:=Button.new()
	credits.text="Map and asset credits"
	credits.pressed.connect(_show_credits)
	column.add_child(credits)
	column.move_child(close,column.get_child_count()-1)

func _show_credits() -> void:
	var dialog:=AcceptDialog.new()
	dialog.title="AZ Car 3D Akurana — credits"
	dialog.dialog_text="Map: © OpenStreetMap contributors — ODbL 1.0\nhttps://www.openstreetmap.org/copyright\n\nTerrain: inherited Copernicus GLO-30 DSM / Airbus WorldDEM; OpenTopography distributor. Terrain and untagged building heights are approximate. Facades, vegetation and poles are inferred.\n\nAsphalt012, Grass004, Ground037: Lennart Demes / ambientCG — CC0 1.0\nhttps://docs.ambientcg.com/license/\n\nPeriwinkle Plant: Amal Kumar / Poly Haven — CC0 1.0\nhttps://polyhaven.com/a/periwinkle_plant\n\nGodot Engine — MIT and third-party notices\nhttps://godotengine.org/license/\n\nVehicle, cockpit and other procedural art: original AZ Car 3D project artwork."
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(800,550))

func _option(column: VBoxContainer,key: String,title: String,labels: Array,values: Array,selected: Variant) -> void:
	var label:=Label.new()
	label.text=title
	column.add_child(label)
	var option:=OptionButton.new()
	for text in labels: option.add_item(text)
	var index:=values.find(selected)
	option.select(maxi(0,index))
	column.add_child(option)
	selectors[key]={"option":option,"values":values}
	option.item_selected.connect(func(i: int):
		if key=="preset":
			graphics=PRESETS[i].duplicate()
			saved.set_value("graphics","preset",i)
			for item in graphics:
				var control: Dictionary=selectors[item]
				control.option.select(maxi(0,control.values.find(graphics[item])))
		else: graphics[key]=values[i]
		for item in graphics: saved.set_value("graphics",item,graphics[item])
		saved.save("user://driving-settings.cfg")
		graphics_changed.emit())

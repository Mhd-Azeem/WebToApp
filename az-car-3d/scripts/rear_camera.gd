extends Node
var vehicle: VehicleBody3D
var camera: Camera3D
var viewport: SubViewport
var display: TextureRect
var label: Label
var elapsed := 0.0
var active := false
func setup(parent: Node, car: VehicleBody3D) -> void:
	vehicle=car
	viewport=SubViewport.new()
	viewport.size=Vector2i(320,180)
	viewport.world_3d=car.get_world_3d()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	viewport.audio_listener_enable_3d=false
	add_child(viewport)
	camera=Camera3D.new()
	camera.fov=85
	camera.far=110
	viewport.add_child(camera)
	camera.current=true
	display=TextureRect.new()
	display.position=Vector2(700,95)
	display.size=Vector2(320,180)
	display.texture=viewport.get_texture()
	display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(display)
	label=Label.new()
	label.text="REAR CAMERA"
	label.position=Vector2(8,6)
	label.add_theme_font_size_override("font_size",15)
	display.add_child(label)
	for x in [70.0,250.0]:
		var guide := Line2D.new()
		guide.points=PackedVector2Array([Vector2(160+(x-160)*0.4,110),Vector2(x,170)])
		guide.width=3
		guide.default_color=Color(0.3,1,0.4,0.7)
		display.add_child(guide)
	display.visible=false
func _process(delta: float) -> void:
	if not is_instance_valid(vehicle): return
	var t = vehicle.transmission
	active=(t.mode==0 and t.gear==-1) or (t.mode==1 and t.selector=="R")
	display.visible=active
	if not active:
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		elapsed=1
		return
	camera.global_position=vehicle.to_global(Vector3(0,1.45,-2.35))
	camera.look_at(camera.global_position-vehicle.global_basis.z*20,vehicle.global_basis.y)
	elapsed+=delta
	if elapsed>=1.0/15.0:
		elapsed=0
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

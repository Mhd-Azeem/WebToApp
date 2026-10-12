extends Node2D
var vehicle: VehicleBody3D
var speed := 0.0
var rpm := 0.0
var gear := "N"
const INK := Color(0.9,0.95,1)
func _process(delta: float) -> void:
	if not is_instance_valid(vehicle): return
	speed=lerpf(speed,vehicle.linear_velocity.length()*3.6,1-exp(-delta*12))
	rpm=lerpf(rpm,vehicle.transmission.rpm,1-exp(-delta*12))
	var t = vehicle.transmission
	gear=t.selector if t.mode==1 and t.selector!="D" else (str(t.auto_gear) if t.mode==1 else ("R" if t.gear==-1 else ("N" if t.gear==0 else str(t.gear))))
	queue_redraw()
func _draw() -> void:
	_dial(Vector2(-112,0),speed,240.0,"km/h",12)
	_dial(Vector2(112,0),rpm/1000.0,8.0,"RPM x1000",8,vehicle.transmission.config.redline_rpm/1000.0)
	draw_rect(Rect2(-31,-32,62,64),Color(0.02,0.04,0.06,0.88))
	draw_string(ThemeDB.fallback_font,Vector2(-12,9),gear,HORIZONTAL_ALIGNMENT_LEFT,-1,30,INK)
	draw_string(ThemeDB.fallback_font,Vector2(-20,49),"GEAR",HORIZONTAL_ALIGNMENT_LEFT,-1,12,INK)
	draw_string(ThemeDB.fallback_font,Vector2(-27,76),vehicle.transmission.engine.status(),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(1,0.4,0.2) if not vehicle.transmission.running or vehicle.transmission.engine.mechanical_overrev else INK)
func _dial(c: Vector2,value: float,maximum: float,title: String,ticks: int,redline: float = INF) -> void:
	draw_circle(c,83,Color(0.02,0.04,0.06,0.9))
	draw_arc(c,81,0,TAU,64,Color(0.4,0.6,0.7),2,true)
	for i in range(ticks*4+1):
		var a := deg_to_rad(135.0+270.0*i/(ticks*4))
		var d := Vector2(cos(a),sin(a))
		var major := i%4==0
		draw_line(c+d*(63 if major else 70),c+d*76,Color(1,0.25,0.16) if maximum*i/(ticks*4)>=redline else INK,2,true)
		if major and (maximum<10 or i%8==0):
			var text := str(roundi(maximum*i/(ticks*4)))
			draw_string(ThemeDB.fallback_font,c+d*52-Vector2(7,-5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,INK)
	var angle := deg_to_rad(135+270*clampf(value/maximum,0,1))
	draw_line(c,c+Vector2(cos(angle),sin(angle))*62,Color(1,0.25,0.16),3,true)
	draw_circle(c,5,INK)
	draw_string(ThemeDB.fallback_font,c+Vector2(-30,37),title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,INK)


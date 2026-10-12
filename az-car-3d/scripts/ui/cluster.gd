extends Node2D
var vehicle: VehicleBody3D
var cockpit: Node3D
var speed := 0.0
var rpm := 0.0
func _process(delta: float) -> void:
	speed=lerpf(speed,absf(vehicle.signed_speed)*3.6,1-exp(-delta*10))
	rpm=lerpf(rpm,vehicle.transmission.rpm,1-exp(-delta*12))
	queue_redraw()
func text_at(value: String,pos: Vector2,size: int,color := Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func dial(center: Vector2,value: float,maximum: float,title: String) -> void:
	draw_circle(center,119,Color(0.08,0.10,0.12))
	draw_arc(center,116,0,TAU,96,Color(0.45,0.52,0.57),3,true)
	for i in range(25):
		var angle := deg_to_rad(135+270*float(i)/24)
		var dir := Vector2(cos(angle),sin(angle))
		draw_line(center+dir*98,center+dir*111,Color(1,0.25,0.18) if title=="RPM" and i>=20 else Color.WHITE,2,true)
		if i%(3 if title=="RPM" else 4)==0:
			text_at(str(roundi(maximum*i/24)),center+dir*80-Vector2(15,-6),19)
	var angle := deg_to_rad(135+270*clampf(value/maximum,0,1))
	draw_line(center,center+Vector2(cos(angle),sin(angle))*91,Color(1,0.28,0.12),5,true)
	draw_circle(center,8,Color(0.7,0.73,0.75))
	text_at(title,center+Vector2(-24,62),18)
func _draw() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color=Color(0.012,0.018,0.025)
	backing.set_corner_radius_all(42)
	draw_style_box(backing,Rect2(0,0,768,320))
	dial(Vector2(170,160),speed,240,"km/h")
	dial(Vector2(598,160),rpm,8000,"RPM")
	text_at(str(roundi(absf(vehicle.signed_speed)*3.6)),Vector2(327,138),58)
	text_at("km/h",Vector2(353,167),19)
	text_at(vehicle.transmission.display(),Vector2(326,86),26,Color(0.4,0.85,1))
	text_at("AUTO" if vehicle.transmission.mode==1 else "MANUAL",Vector2(335,239),20)
	if cockpit.headlights: text_at("LIGHT",Vector2(327,56),18,Color(0.3,0.75,1))
	if vehicle.high_beams and cockpit.headlights: text_at("HIGH",Vector2(327,80),16,Color(0.3,0.6,1))
	if fmod(cockpit.clock,0.8)<0.4:
		if vehicle.turn_signal==-1 or vehicle.hazards: text_at("<",Vector2(275,50),28,Color(0.25,1,0.4))
		if vehicle.turn_signal==1 or vehicle.hazards: text_at(">",Vector2(462,50),28,Color(0.25,1,0.4))
	text_at("FUEL %d%%" % roundi(vehicle.fuel_litres/45*100),Vector2(322,308),18,Color(0.7,0.8,0.9))
	if vehicle.handbrake>0: text_at("(P)",Vector2(395,56),21,Color(1,0.25,0.15))
	if not vehicle.transmission.running: text_at("ENGINE OFF",Vector2(320,280),20,Color(1,0.65,0.2))

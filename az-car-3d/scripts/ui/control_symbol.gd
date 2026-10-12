extends Node2D
# Original vector symbols; no font-dependent emoji or borrowed image assets.
var kind := "left"
var extent := Vector2(96,96)
var active := false:
	set(value):
		active=value
		queue_redraw()
const INK := Color(0.91,0.95,0.98)
func line(a: Vector2, b: Vector2, width := 3.0) -> void:
	draw_line(a,b,INK,width,true)
func _draw() -> void:
	var c := extent*0.5
	var scale_factor := minf(extent.x,extent.y)/96.0
	draw_set_transform(c,0,Vector2.ONE*scale_factor)
	draw_circle(Vector2.ZERO,43,Color(0.035,0.075,0.11,0.82))
	draw_arc(Vector2.ZERO,42,0,TAU,48,Color(0.35,0.77,0.85) if active else Color(0.45,0.56,0.63,0.70),2,true)
	match kind:
		"handbrake":
			draw_circle(Vector2.ZERO,21,INK,false,3,true)
			line(Vector2(-28,-16),Vector2(-28,16),3)
			line(Vector2(28,-16),Vector2(28,16),3)
			line(Vector2(-7,-12),Vector2(-7,14),3)
			draw_arc(Vector2(0,-5),8,-PI/2,PI/2,16,INK,3,true)
			line(Vector2(-7,-13),Vector2(0,-13),3)
			line(Vector2(-7,3),Vector2(0,3),3)
		"settings":
			draw_circle(Vector2.ZERO,18,INK,false,3,true)
			draw_circle(Vector2.ZERO,7,INK,false,3,true)
			for i in range(8):
				var d := Vector2(cos(i*TAU/8),sin(i*TAU/8))
				line(d*20,d*28,5)
		"horn":
			line(Vector2(-22,-10),Vector2(-8,-10),3)
			line(Vector2(-8,-10),Vector2(12,-24),3)
			line(Vector2(12,-24),Vector2(12,24),3)
			line(Vector2(12,24),Vector2(-8,10),3)
			line(Vector2(-8,10),Vector2(-22,10),3)
			line(Vector2(-22,10),Vector2(-22,-10),3)
			draw_arc(Vector2(12,0),15,-PI/3,PI/3,16,INK,3,true)
		"left", "right":
			var sign_x := -1.0 if kind=="left" else 1.0
			line(Vector2(-20*sign_x,0),Vector2(20*sign_x,0),5)
			line(Vector2(5*sign_x,-16),Vector2(21*sign_x,0),5)
			line(Vector2(5*sign_x,16),Vector2(21*sign_x,0),5)
		"gas", "brake", "clutch":
			var narrow := kind=="gas"
			draw_style_box(_pedal_style(),Rect2(Vector2(-12 if narrow else -21,-20),Vector2(24 if narrow else 42,37)))
			for y in [-10.0,0.0,10.0]: line(Vector2(-7 if narrow else -15,y),Vector2(7 if narrow else 15,y),2)
			line(Vector2(0,18),Vector2(12,27),4)
			if kind=="clutch":
				draw_arc(Vector2(-26,0),8,-PI/2,PI/2,16,INK,2,true)
				draw_arc(Vector2(26,0),8,PI/2,3*PI/2,16,INK,2,true)
			elif kind=="brake":
				line(Vector2(-29,-14),Vector2(-29,14),2)
				line(Vector2(29,-14),Vector2(29,14),2)
		"camera":
			draw_rect(Rect2(-24,-16,48,34),INK,false,3)
			draw_circle(Vector2.ZERO,10,INK,false,3,true)
			line(Vector2(-11,-17),Vector2(-7,-25))
			line(Vector2(-7,-25),Vector2(8,-25))
			line(Vector2(8,-25),Vector2(13,-17))
		"reset":
			draw_arc(Vector2.ZERO,23,-PI*0.75,PI*0.82,32,INK,4,true)
			line(Vector2(-17,-18),Vector2(-27,-16),4)
			line(Vector2(-17,-18),Vector2(-17,-29),4)
		"start":
			draw_arc(Vector2.ZERO,22,-PI*0.30,PI*1.30,32,INK,4,true)
			line(Vector2(0,-28),Vector2(0,-3),4)
		"quality":
			for i in range(3):
				var x := -18.0+i*18
				line(Vector2(x,-25),Vector2(x,25),2)
				draw_circle(Vector2(x,[-10.0,12.0,-2.0][i]),5,INK)
		"regions":
			line(Vector2(-25,-17),Vector2(-8,-24))
			line(Vector2(-8,-24),Vector2(10,-17))
			line(Vector2(10,-17),Vector2(26,-24))
			line(Vector2(-25,-17),Vector2(-25,24))
			line(Vector2(-25,24),Vector2(-8,17))
			line(Vector2(-8,17),Vector2(10,24))
			line(Vector2(10,24),Vector2(26,17))
			line(Vector2(26,17),Vector2(26,-24))
			line(Vector2(-8,-24),Vector2(-8,17))
			line(Vector2(10,-17),Vector2(10,24))
		"mode":
			for x in [-18.0,0.0,18.0]: line(Vector2(x,-18),Vector2(x,18),3)
			line(Vector2(-18,0),Vector2(18,0),3)
			draw_arc(Vector2.ZERO,31,-PI/4,PI*1.35,32,INK,2,true)
			line(Vector2(22,-22),Vector2(30,-21),3)
			line(Vector2(22,-22),Vector2(22,-31),3)
func _pedal_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color=Color(0.15,0.23,0.27)
	s.border_color=INK
	s.set_border_width_all(2)
	s.set_corner_radius_all(5)
	return s

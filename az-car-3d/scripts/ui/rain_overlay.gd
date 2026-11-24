extends Control

var phase := 0.0
var drops := 24

func _process(delta: float) -> void:
	phase += delta
	if phase >= 100.0: phase -= 100.0
	queue_redraw()

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	for i in range(drops):
		var x := fposmod(i*93.7+phase*85.0, viewport_size.x)
		var y := fposmod(i*47.3+phase*430.0, viewport_size.y)
		var point := Vector2(x,y)
		draw_line(point,point+Vector2(-4,12),Color(0.70,0.84,0.92,0.22),1,true)

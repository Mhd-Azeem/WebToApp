extends Control

const Region = preload("res://scripts/regional_road.gd")
const MAP_SIZE := Vector2(155,190)
var navigation: RefCounted
var position_3d := Vector3.ZERO
var forward := Vector3.FORWARD
var route := PackedVector3Array()
var highlighted := -1

func _map(point: Vector3) -> Vector2:
	return Vector2(12,10)+Vector2((point.x+135.0)/820.0,(point.z+1000.0)/2000.0)*(MAP_SIZE-Vector2(24,20))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,MAP_SIZE),Color(0.026,0.054,0.066,0.88))
	if navigation==null: return
	for edge: Vector2i in navigation.links:
		draw_line(_map(navigation.points[edge.x]),_map(navigation.points[edge.y]),Color(0.31,0.46,0.48),2,true)
	for i in range(route.size()-1):
		draw_line(_map(route[i]),_map(route[i+1]),Color(0.45,0.95,0.65),3,true)
	for i in range(Region.DESTINATIONS.size()):
		draw_circle(_map(Region.DESTINATIONS[i][1]),4 if i==highlighted else 2,Color(1,0.76,0.32))
	var heading := Vector2(forward.x,forward.z).normalized()
	var player := _map(position_3d).clamp(Vector2(8,8),MAP_SIZE-Vector2(8,8))
	draw_colored_polygon(PackedVector2Array([player+heading*7,player-heading*5+heading.orthogonal()*4,player-heading*5-heading.orthogonal()*4]),Color.WHITE)

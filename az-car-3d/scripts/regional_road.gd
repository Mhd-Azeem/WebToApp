extends Node3D

const G = preload("res://scripts/geometry.gd")
const LINE := [
	Vector3(154,0,-640), Vector3(230,0,-640), Vector3(320,0,-620),
	Vector3(408,2,-566), Vector3(467,8,-474), Vector3(525,14,-379),
	Vector3(583,19,-279), Vector3(610,23,-170), Vector3(612,22,-55),
	Vector3(580,19,63), Vector3(529,16,158), Vector3(485,13,255),
	Vector3(420,10,350), Vector3(356,7,444), Vector3(294,4,542),
	Vector3(234,0,617), Vector3(190,0,640), Vector3(154,0,640),
]
const DESTINATIONS := [
	["Fort service station", Vector3(158,0,73)],
	["Paddy village parking", Vector3(116,0,-637)],
	["Highland lookout", Vector3(613,23,-168)],
	["South junction service station", Vector3(159,0,634)],
	["Coastal delivery lay-by", Vector3(-94,0,782)],
]

static func nearest(point: Vector2) -> Vector2:
	var best := Vector2(INF, 0)
	for index in range(LINE.size() - 1):
		var a: Vector3 = LINE[index]
		var b: Vector3 = LINE[index+1]
		var start := Vector2(a.x,a.z)
		var direction := Vector2(b.x,b.z) - start
		var t := clampf((point - start).dot(direction) / direction.length_squared(), 0, 1)
		var gap := point.distance_to(start + direction*t)
		if gap < best.x: best = Vector2(gap,lerpf(a.y,b.y,t))
	return best

func _ready() -> void:
	var asphalt := G.material("asphalt")
	var marking := G.material("", Color(0.88,0.83,0.67))
	var stone := G.material("concrete", Color(0.59,0.61,0.58))
	var rail := G.material("", Color(0.26,0.31,0.34))
	for i in range(LINE.size() - 1):
		var a: Vector3 = LINE[i]
		var b: Vector3 = LINE[i+1]
		_ribbon(a,b,_normal(i),_normal(i+1),7.0,asphalt)
		var direction := (b-a).normalized()
		var length := a.distance_to(b)
		for offset in range(10,int(length)-4,14):
			_beam(a+direction*(offset-2)+Vector3.UP*0.02,a+direction*(offset+2)+Vector3.UP*0.02,0.14,0.025,marking)
		for side in [-1,1]:
			var left: Vector3 = a + _normal(i)*6.85*side
			var right: Vector3 = b + _normal(i+1)*6.85*side
			_beam(left+Vector3.UP*0.02,right+Vector3.UP*0.02,0.13,0.025,marking)
			if i in [3,4,5,6,7,8,9,10,11,12,13]:
				_beam(left+Vector3.UP*0.38,right+Vector3.UP*0.38,0.26,0.76,rail,true)
		if i==7:
			for side in [-1,1]:
				_beam(a+Vector3(side*8,2.9,0),b+Vector3(side*8,2.9,0),1.6,5.8,stone,true)
			_beam(a+Vector3.UP*5.8,b+Vector3.UP*5.8,18.0,1.2,stone,true)
		if i==11:
			G.box(self,(a+b)*0.5-Vector3.UP*7,Vector3(4,14,4),stone,true)
	for i in range(DESTINATIONS.size()):
		var destination: Array = DESTINATIONS[i]
		var point: Vector3 = destination[1]
		var sign := G.label(self,destination[0],point+Vector3(4,2.3,0),26)
		sign.pixel_size=0.012
		var marker := G.box(self,point+Vector3.UP*0.07,Vector3(2.8,0.03,6),marking)
		marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _normal(index: int) -> Vector3:
	var direction: Vector3 = LINE[mini(index+1, LINE.size()-1)] - LINE[maxi(0,index-1)]
	return Vector3(direction.z,0,-direction.x).normalized()

func _beam(a: Vector3,b: Vector3,width: float,height: float,material: Material,solid := false) -> void:
	var beam := G.box(self,(a+b)*0.5,Vector3(width,height,a.distance_to(b)+0.035),material,solid)
	beam.look_at(b,Vector3.UP,true)

func _ribbon(a: Vector3,b: Vector3,na: Vector3,nb: Vector3,width: float,material: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var extension := (b-a).normalized()*0.12
	a -= extension
	b += extension
	var vertices := [a+na*width,a-na*width,b+nb*width,b-nb*width]
	for i in [0,2,1,1,2,3]:
		var vertex: Vector3 = vertices[i]
		st.set_uv(Vector2(vertex.x,vertex.z)*0.2)
		st.add_vertex(vertex-(a+b)*0.5)
	st.generate_normals()
	var road := MeshInstance3D.new()
	road.mesh=st.commit()
	road.material_override=material
	road.position=(a+b)*0.5
	add_child(road)
	road.create_trimesh_collision()
	road.get_child(0).set_meta("surface","asphalt")

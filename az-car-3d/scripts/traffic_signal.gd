extends Node3D
const G = preload("res://scripts/geometry.gd")
var bulbs: Array[MeshInstance3D] = []
var lit: Array[StandardMaterial3D] = []
var dark: Material
var last_state := -1
func _ready() -> void:
	dark=G.material("",Color(0.035,0.043,0.045))
	for color in [Color(1,0.08,0.02),Color(1,0.62,0.02),Color(0.05,0.85,0.24)]:
		var m := StandardMaterial3D.new()
		m.albedo_color=color
		m.emission_enabled=true
		m.emission=color
		lit.append(m)
	for side in [-1.0,1.0]:
		G.box(self,Vector3(side*8.5,1.7,side*8.5),Vector3(0.09,3.4,0.09),dark)
		G.box(self,Vector3(side*8.5,3.4,side*8.5),Vector3(0.33,0.91,0.25),dark)
		for i in range(3):
			var mesh := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius=0.105
			sphere.height=0.21
			sphere.radial_segments=12
			sphere.rings=6
			mesh.mesh=sphere
			mesh.position=Vector3(side*8.5,3.70-i*0.28,side*8.5+0.15)
			mesh.visibility_range_end=120
			add_child(mesh)
			bulbs.append(mesh)
func _process(_delta: float) -> void:
	var phase := fmod(Time.get_ticks_msec()/1000.0,24.0)
	var state := 2 if phase<10 else (1 if phase<12 else 0)
	if state==last_state: return
	last_state=state
	for i in range(bulbs.size()): bulbs[i].material_override=lit[i%3] if i%3==state else dark

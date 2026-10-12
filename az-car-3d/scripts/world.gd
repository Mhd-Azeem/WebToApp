extends Node3D
const G = preload("res://scripts/geometry.gd")
const STREET_X := [-96.0, 0.0, 96.0]
const STREET_Z := [-160.0, -80.0, 0.0, 80.0, 160.0]
var landmark_count := 0

func _ready() -> void:
	var ground := G.material("concrete", Color(0.74,0.77,0.66))
	G.box(self, Vector3(10,-0.35,0), Vector3(380,0.5,410), ground, true)
	var asphalt := G.material("asphalt")
	asphalt.uv1_triplanar = true
	asphalt.uv1_scale = Vector3(0.2,0.2,0.2)
	var pavement := G.material("concrete")
	pavement.uv1_triplanar = true
	var white := G.material("", Color(0.88,0.86,0.71))
	for x in STREET_X:
		G.box(self,Vector3(x,-0.07,0),Vector3(15,0.12,360),asphalt,true)
		for side in [-1,1]:
			for z0 in [-180.0,-160.0,-80.0,0.0,80.0,160.0]:
				var z1 := minf(z0+80.0,180.0) if z0>=-160 else -160.0
				if z1-z0>24: G.box(self,Vector3(x+side*9,0.07,(z0+z1)/2),Vector3(3,0.25,z1-z0-24),pavement,true)
		for z in range(-175,176,8):
			if _junction(float(z)): continue
			G.box(self,Vector3(x,0.005,z),Vector3(0.12,0.015,3),white)
	for z in STREET_Z:
		G.box(self,Vector3(0,-0.05,z),Vector3(340,0.12,15),asphalt,true)
		for side in [-1,1]:
			for span in [Vector2(-170,-108),Vector2(-84,-12),Vector2(12,84),Vector2(108,148)]:
				G.box(self,Vector3((span.x+span.y)/2,0.06,z+side*9),Vector3(span.y-span.x,0.24,3),pavement,true)
		for x in range(-108,109,8):
			if abs(x)<12 or abs(abs(x)-96)<12: continue
			G.box(self,Vector3(x,0.015,z),Vector3(3,0.01,0.12),white)
	# Short raised crossing pads meet sidewalks that stop before each junction.
	for x in STREET_X:
		for z in STREET_Z:
			G.box(self,Vector3(x,0.06,z),Vector3(21,0.12,21),asphalt,true)
			for lane in range(6):
				G.box(self,Vector3(x-5+lane*2,0.13,z+6),Vector3(1,0.015,2.1),white)
			G.label(self,"GIVE WAY",Vector3(x+9,2.2,z+12),22)
	for row in range(4):
		for col in range(2):
			for side in [-1,1]:
				for slot in range(3):
					var x: float = -72.0 + col*96.0 + slot*23.0
					var z: float = -140.0 + row*80.0 + (0 if side==-1 else 40)
					_building(Vector3(x,0,z),2+(row+col+slot)%5,(row+slot)%3)
	# Seafront promenade, sea and protective wall west of district.
	G.box(self,Vector3(-220,-0.28,0),Vector3(180,0.1,500),G.material("",Color(0.08,0.37,0.47)))
	G.box(self,Vector3(-124,0,0),Vector3(12,0.15,365),pavement,true)
	G.box(self,Vector3(-132,0.65,0),Vector3(0.6,1.3,370),ground,true)
	for z in range(-140,161,40): _palm(Vector3(-122,0,z))
	for x in STREET_X:
		for z in range(-140,151,40): _lamp(Vector3(x+10,0,z))
	# Colombo-inspired arcade and civic landmark, built as original modular art.
	G.label(self,"COLOMBO • FORT / PETTAH",Vector3(-45,10,-138),45)
	G.label(self,"GALLE FACE PROMENADE",Vector3(-121,4,45),28).rotation.y=PI/2
	G.label(self,"KANDY ROAD →
Future hill-country district",Vector3(7,5,-181),25)
	G.label(self,"← GALLE COAST
Future coastal district",Vector3(96,5,181),25).rotation.y=PI
	for z in [-188.0,188.0]:
		for span in [Vector2(-140,-108),Vector2(-84,-12),Vector2(12,84),Vector2(108,148),Vector2(172,180)]:
			G.box(self,Vector3((span.x+span.y)/2,0.8,z),Vector3(span.y-span.x,1.6,2),ground,true)
	for x in [-140.0,180.0]: G.box(self,Vector3(x,0.8,0),Vector3(2,1.6,380),ground,true)
	# Hybrid fringe: rural plots / tea-country hills and a Galle-inspired arcade.
	G.box(self,Vector3(160,0.01,0),Vector3(13,0.12,340),asphalt,true)
	for z in [-120.0,-40.0,40.0,120.0]:
		G.box(self,Vector3(133,0.02,z),Vector3(23,0.16,33),G.material("",Color(0.34,0.48,0.15)))
		for row in range(5):
			G.box(self,Vector3(123+row*4,0.2,z),Vector3(0.45,0.25,32),G.material("",Color(0.24,0.39,0.12)))
		_palm(Vector3(147,0,z+12))
	G.label(self,"RURAL LANKA • PADDY LANE",Vector3(156,4,105),28)
	_building(Vector3(129,0,-15),1,0)
	G.label(self,"GALLE-INSPIRED COLONIAL ARCADE",Vector3(42,5,32),22)
	for x in [-220.0,260.0,380.0]:
		var hill := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius=55
		sphere.height=100
		sphere.radial_segments=24
		sphere.rings=12
		hill.mesh=sphere
		hill.position=Vector3(x,-25,-245)
		hill.material_override=G.material("",Color(0.29,0.39,0.22))
		add_child(hill)
	var extension := Node3D.new()
	extension.set_script(preload("res://scripts/road_extension.gd"))
	add_child(extension)
	var landscape := Node3D.new()
	landscape.name="Landscape"
	landscape.set_script(preload("res://scripts/landscape.gd"))
	add_child(landscape)
	_batch_geometry(landscape)
	_batch_geometry(extension)
	landmark_count = 4
	_urban_details()
	_batch_geometry()

func _urban_details() -> void:
	var metal := G.material("",Color(0.13,0.17,0.19))
	var paint := G.material("",Color(0.92,0.93,0.89))
	for x in STREET_X:
		for z in STREET_Z:
			var signals := Node3D.new()
			signals.position=Vector3(x,0,z)
			signals.set_script(preload("res://scripts/traffic_signal.gd"))
			add_child(signals)
		for side in [-1.0,1.0]:
			for z in range(-150,151,8):
				if _junction(float(z)): continue
				G.box(self,Vector3(x+side*3.7,0.018,z),Vector3(0.09,0.015,4),paint)
	# Shelters and parking stay off the existing connected road surfaces.
	for pos in [Vector3(12,0,115),Vector3(-84,0,-115),Vector3(108,0,35)]:
		for x in [-2.0,2.0]:
			for z in [-0.8,0.8]: G.box(self,pos+Vector3(x,1.3,z),Vector3(0.06,2.6,0.06),metal)
		G.box(self,pos+Vector3(0,2.65,0),Vector3(4.8,0.09,2.2),G.material("",Color(0.22,0.38,0.43)))
		G.box(self,pos+Vector3(0,0.5,0.6),Vector3(3.7,0.09,0.38),metal)
		var sign := G.label(self,"BUS • COLOMBO",pos+Vector3(0,2.35,-0.85),22)
		sign.pixel_size=0.006
	for x in range(22,67,5):
		G.box(self,Vector3(x,0.025,92),Vector3(0.10,0.015,6),paint)
	G.box(self,Vector3(44,0.025,95),Vector3(45,0.015,0.1),paint)

func _junction(z: float) -> bool:
	for cross in STREET_Z:
		if absf(z-cross)<13: return true
	return false

func _building(pos: Vector3, floors: int, variant: int) -> void:
	var h := floors*3.2
	var facade := G.material("facade"+str(variant))
	G.box(self,pos+Vector3(0,h/2,0),Vector3(19,h,22),facade,true)
	G.box(self,pos+Vector3(0,h+0.2,0),Vector3(20,0.4,23),G.material("concrete"))
	for x in [-8.0,-4.0,0.0,4.0,8.0]:
		G.box(self,pos+Vector3(x,1.6,11.4),Vector3(0.4,3.2,0.6),G.material("plaster"))
	var awning := G.box(self,pos+Vector3(0,3.0,12),Vector3(20,0.15,2.2),G.material("tiles"))
	awning.rotation.x=0.12
	var shops := ["LANKA TEA & SPICE", "FORT MOTOR WORKS", "PETTAH TRADERS"]
	G.label(self,shops[variant],pos+Vector3(0,3.8,11.15),24)
	G.box(self,pos+Vector3(5,h+0.8,-5),Vector3(2,1.1,2),G.material("",Color(0.17,0.22,0.23)))
	for level in range(1,floors):
		G.box(self,pos+Vector3(0,level*3.2,11.1),Vector3(19,0.14,0.4),G.material("concrete"))

func _lamp(pos: Vector3) -> void:
	var m := G.material("",Color(0.14,0.17,0.17))
	G.box(self,pos+Vector3(0,3,0),Vector3(0.13,6,0.13),m)
	G.box(self,pos+Vector3(-0.7,6,0),Vector3(1.5,0.12,0.12),m)
	G.box(self,pos+Vector3(-1.3,5.9,0),Vector3(0.7,0.12,0.4),G.material("",Color(0.95,0.86,0.64)))

func _palm(pos: Vector3) -> void:
	G.box(self,pos+Vector3(0,3,0),Vector3(0.4,6,0.4),G.material("plaster",Color(0.48,0.39,0.23)))
	for i in range(6):
		var leaf := G.box(self,pos+Vector3(0,6,0),Vector3(0.65,0.12,5),G.material("",Color(0.18,0.37,0.13)))
		leaf.rotation=Vector3(0.2,i*TAU/6,0)

func _batch_geometry(source: Node3D = null) -> void:
	# Batch repeated static meshes by dimensions and material, keeping physical bodies.
	if source==null: source=self
	var groups := {}
	for child in source.get_children():
		if not child is MeshInstance3D or not child.mesh is BoxMesh: continue
		var key := str(child.mesh.size) + ":" + str(child.material_override.get_instance_id()) + ":" + str(floori(child.position.x/160)) + ":" + str(floori(child.position.z/160))
		if not groups.has(key): groups[key]=[]
		groups[key].append(child)
	for key in groups:
		var nodes: Array = groups[key]
		if nodes.size()<3: continue
		var batch := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=nodes[0].mesh
		mm.instance_count=nodes.size()
		batch.multimesh=mm
		batch.material_override=nodes[0].material_override
		batch.visibility_range_end=260
		source.add_child(batch)
		for i in range(nodes.size()):
			var n: MeshInstance3D=nodes[i]
			mm.set_instance_transform(i,n.transform)
			for body in n.get_children():
				if body is StaticBody3D:
					body.reparent(source,true)
			n.queue_free()


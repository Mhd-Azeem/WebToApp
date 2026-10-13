extends Node3D
## OSM-derived polygons; heights/facades/vegetation without tags are inferred.
const G = preload("res://scripts/geometry.gd")
const DATA = "res://data/akurana/world.json"
const ROAD_CLEARANCE = 0.13
var heights: Array = []
var mapped_roads: Array = []
var mapped_buildings: Array = []
var data: Dictionary = {}
var vegetation: Array[MultiMeshInstance3D] = []
var render_meshes: Array[GeometryInstance3D] = []
var terrain_count := 0
var building_count := 0
var batches := {}
var plant_cell:=Vector2i.ZERO

func _ready() -> void:
	var runtime_data:=DATA if OS.get_cmdline_user_args().has("--bake-world") else "res://data/akurana/world-runtime.json"
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(runtime_data))
	if not parsed is Dictionary or parsed.get("schema",0)!=2:
		push_error("Akurana processed map missing")
		return
	data=parsed
	heights=data.height_field
	mapped_roads=data.roads
	mapped_buildings=data.buildings
	if ResourceLoader.exists("res://data/akurana/environment.scn") and not OS.get_cmdline_user_args().has("--bake-world"):
		var baked: Node3D=load("res://data/akurana/environment.scn").instantiate()
		add_child(baked)
		for item in baked.find_children("*","GeometryInstance3D",true,false):
			render_meshes.append(item)
			if item is MultiMeshInstance3D and item.has_meta("vegetation"): vegetation.append(item)
		terrain_count=int(baked.get_meta("terrain_count",0))
		building_count=int(baked.get_meta("building_count",0))
	else:
		if not OS.get_cmdline_user_args().has("--bake-world"):
			push_error("Akurana baked environment missing; rebuild assets before exporting")
			return
		_generate_terrain()
		_generate_roads()
		_generate_buildings()
		_generate_vegetation()
		_generate_roadside()
		_flush_batches()
	# Photo-inspired Akurana market detailing is intentionally generated after
	# either baked or source map loading, so it appears in APK and Windows exports.
	_generate_town_street_details()

func _generate_town_street_details() -> void:
	# Approximate the supplied town photo: storefront awnings and fascia
	# on real OSM-derived footprints. Shop names are generic, not GIS facts.
	var canopy_mat:=G.material("",Color(.20,.27,.31))
	var accent_mats: Array[Material]=[
		G.material("",Color(.51,.13,.15)),
		G.material("",Color(.13,.34,.34)),
		G.material("",Color(.23,.32,.48)),
		G.material("",Color(.41,.28,.17))
	]
	var fascia:=G.material("",Color(.09,.105,.12))
	var pavement_mat:=G.material("concrete",Color(.54,.53,.49))
	var placed:=0
	for feature in mapped_buildings:
		if placed>=64: break
		if not bool(feature.get("shopfront_inferred",false)): continue
		var footprint: Array=feature.get("footprint",[])
		if footprint.size()<3: continue
		var center:=Vector2.ZERO
		for pt in footprint: center+=_v2(pt)
		center/=float(footprint.size())
		if center.distance_to(Vector2(-113,-25))>200: continue
		var edge_index:=posmod(int(feature.get("frontage",0)),footprint.size())
		var a:=_v2(footprint[edge_index])
		var b:=_v2(footprint[(edge_index+1)%footprint.size()])
		var edge:=b-a
		var length:=edge.length()
		if length<3.2 or length>27: continue
		var midpoint: Vector2=(a+b)*.5
		if road_distance_at(midpoint.x,midpoint.y)>26: continue
		var outward:=Vector2(-edge.y,edge.x).normalized()
		if Geometry2D.is_point_in_polygon(midpoint+outward*.35,PackedVector2Array(footprint.map(func(v): return _v2(v)))):
			outward=-outward
		var world_floor: float=height_at(midpoint.x,midpoint.y)
		var forward:=Vector3(outward.x,0,outward.y)
		var basis:=Basis(Vector3.UP,-atan2(edge.y,edge.x))
		var awning_position:=Vector3(midpoint.x,world_floor+2.75,midpoint.y)+forward*.65
		_batch("market_awning",awning_position,Vector3(length*.82,.10,1.40),accent_mats[placed%accent_mats.size()],basis)
		_batch("market_fascia",Vector3(midpoint.x,world_floor+3.15,midpoint.y)+forward*.13,Vector3(length*.78,.48,.12),fascia,basis)
		_batch("market_trim",Vector3(midpoint.x,world_floor+3.49,midpoint.y)+forward*.16,Vector3(length*.80,.07,.16),accent_mats[placed%accent_mats.size()],basis)
		# Narrow shopfront paving; visually connects the frontage with ground.
		_batch("market_paving",Vector3(midpoint.x,world_floor+.09,midpoint.y)+forward*.40,Vector3(length*.86,.12,.9),pavement_mat,basis)
		placed+=1
	_flush_batches()

func height_at(x: float,z: float) -> float:
	if heights.size()!=321*321: return 20.0
	var u:=clampf((x+640.0)/4.0,0,320)
	var v:=clampf((z+640.0)/4.0,0,320)
	var ix:=mini(floori(u),319)
	var iz:=mini(floori(v),319)
	var fx:=u-ix
	var fz:=v-iz
	var a:=float(heights[iz*321+ix])
	var b:=float(heights[iz*321+ix+1])
	var c:=float(heights[(iz+1)*321+ix])
	var d:=float(heights[(iz+1)*321+ix+1])
	# Exact same diagonal as the terrain collision, not a bilinear approximation.
	return a+(b-a)*fx+(c-a)*fz if fx+fz<=1 else d+(c-d)*(1-fx)+(b-d)*(1-fz)

func road_surface_at(x: float,z: float) -> float:
	return height_at(x,z)+ROAD_CLEARANCE

func road_distance_at(x: float,z: float) -> float:
	var best:=INF
	var point:=Vector2(x,z)
	for road in mapped_roads:
		var path: Array=road.path
		for i in range(path.size()-1):
			best=minf(best,point.distance_to(Geometry2D.get_closest_point_to_segment(point,_v2(path[i]),_v2(path[i+1]))))
	return best

func road_spawn_near(point: Vector2=Vector2(-113,-25)) -> Dictionary:
	var best:=INF
	var result: Dictionary={}
	for road in mapped_roads:
		var path: Array=road.path
		for i in range(path.size()-1):
			var a:=_v2(path[i])
			var b:=_v2(path[i+1])
			if a.distance_to(b)<0.1: continue
			var p:=Geometry2D.get_closest_point_to_segment(point,a,b)
			var distance:=point.distance_to(p)
			if distance<best:
				best=distance
				var direction: Vector2=(b-a).normalized()
				if str(road.oneway)=="-1": direction=-direction
				# In right-handed X-east/Z-south axes, this is the left travel lane.
				if float(road.width)>=5.5: p+=Vector2(direction.y,-direction.x)*float(road.width)*0.24
				result={"position":Vector3(p.x,road_surface_at(p.x,p.y)+1.5,p.y),"yaw":atan2(direction.x,direction.y),"distance":distance,"road_width":road.width}
	return result

func _v2(p: Array) -> Vector2:
	return Vector2(float(p[0]),float(p[1]))

func _vertex(p: Vector2,rise:=0.0) -> Vector3:
	return Vector3(p.x,height_at(p.x,p.y)+rise,p.y)

func _tool() -> SurfaceTool:
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool

func _triangle(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
	for p in [a,b,c]:
		tool.set_uv(Vector2(p.x,p.z)*0.25)
		tool.add_vertex(p)

func _quad(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
	_triangle(tool,a,b,c)
	_triangle(tool,c,b,d)

func _convex(points: PackedVector2Array) -> bool:
	var direction:=0.0
	for i in range(points.size()):
		var turn: float=(points[(i+1)%points.size()]-points[i]).cross(points[(i+2)%points.size()]-points[(i+1)%points.size()])
		if absf(turn)<.001: continue
		if direction!=0 and signf(turn)!=direction: return false
		direction=signf(turn)
	return true

func _finish(tool: SurfaceTool,mat: Material,solid: bool,kind: String) -> MeshInstance3D:
	tool.generate_normals()
	if mat is ShaderMaterial or (mat is StandardMaterial3D and mat.normal_enabled): tool.generate_tangents()
	tool.index()
	var mesh:=tool.commit()
	if mesh==null: return null
	var instance:=MeshInstance3D.new()
	instance.name=kind
	# Real tile-local origins make distance culling and LOD operate locally.
	var center:=mesh.get_aabb().get_center()
	var local_tool:=_tool()
	local_tool.append_from(mesh,0,Transform3D(Basis.IDENTITY,-center))
	local_tool.index()
	instance.mesh=local_tool.commit()
	instance.position=center
	instance.material_override=mat
	instance.visibility_range_end=600
	if kind in ["Terrain","Road","Shoulder","Marking"]: instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance,true)
	render_meshes.append(instance)
	if solid:
		var body:=StaticBody3D.new()
		body.name=kind+"Collision"
		var shape:=CollisionShape3D.new()
		var collision:=mesh.create_trimesh_shape()
		collision.backface_collision=true
		shape.shape=collision
		body.add_child(shape)
		add_child(body,true)
	return instance

func _generate_terrain() -> void:
	var mat:=ShaderMaterial.new()
	mat.shader=load("res://assets/akurana_ground.gdshader")
	mat.set_shader_parameter("grass_texture",load("res://assets/textures/akurana_grass.jpg"))
	mat.set_shader_parameter("soil_texture",load("res://assets/textures/akurana_soil.jpg"))
	mat.set_shader_parameter("ground_normal",load("res://assets/textures/akurana_ground_normal.jpg"))
	for z in range(-640,640,64):
		for x in range(-640,640,64):
			var tool:=_tool()
			for dz in range(0,64,4):
				for dx in range(0,64,4):
					var p:=Vector2(x+dx,z+dz)
					_quad(tool,_vertex(p),_vertex(p+Vector2(4,0)),_vertex(p+Vector2(0,4)),_vertex(p+Vector2(4,4)))
			_finish(tool,mat,true,"Terrain")
			terrain_count+=1

func _generate_roads() -> void:
	var asphalt:=G.material("asphalt",Color(.72,.72,.70)).duplicate() as StandardMaterial3D
	asphalt.resource_name="AkuranaAsphalt"
	asphalt.roughness=.92
	asphalt.normal_enabled=true
	asphalt.normal_texture=load("res://assets/textures/asphalt_normal.jpg")
	asphalt.normal_scale=.35
	asphalt.roughness_texture=load("res://assets/textures/asphalt_roughness.jpg")
	asphalt.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
	asphalt.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var gravel:=G.material("concrete",Color(.47,.40,.29))
	var paint:=G.material("",Color(.84,.82,.71))
	for tile in data.tiles:
		for kind in ["road","shoulder","marking"]:
			var points: Array=tile[kind]
			if points.is_empty(): continue
			var tool:=_tool()
			for i in range(0,points.size(),3):
				var a:=_v2(points[i])
				var b:=_v2(points[i+1])
				var c:=_v2(points[i+2])
				if (b-a).cross(c-a)<0:
					var swap:=b
					b=c
					c=swap
				var rise:=ROAD_CLEARANCE if kind=="road" else .15
				if kind=="shoulder":
					var raw_a: Array=points[i]
					var raw_b: Array=points[i+1]
					var raw_c: Array=points[i+2]
					# Recover corresponding taper heights after any winding swap.
					var rb:=float(raw_b[2]) if b==_v2(raw_b) else float(raw_c[2])
					var rc:=float(raw_c[2]) if c==_v2(raw_c) else float(raw_b[2])
					_triangle(tool,_vertex(a,float(raw_a[2])),_vertex(b,rb),_vertex(c,rc))
				else: _triangle(tool,_vertex(a,rise),_vertex(b,rise),_vertex(c,rise))
			_finish(tool,asphalt if kind=="road" else (paint if kind=="marking" else gravel),kind!="marking",kind.capitalize())

func _generate_buildings() -> void:
	var materials: Array[Material]=[G.material("plaster",Color(.81,.77,.66)),G.material("plaster",Color(.72,.78,.76)),G.material("plaster",Color(.88,.83,.71)),G.material("concrete",Color(.70,.67,.63))]
	for mat in materials:
		mat.uv1_triplanar=true
		mat.uv1_scale=Vector3(.25,.25,.25)
	var concrete:=G.material("concrete",Color(.56,.56,.53))
	concrete.uv1_triplanar=true
	concrete.uv1_scale=Vector3(.25,.25,.25)
	var roof:=G.material("tiles",Color(.49,.29,.20))
	var glass:=G.material("",Color(.16,.25,.28))
	glass.roughness=.22
	glass.metallic=.25
	var trim:=G.material("",Color(.68,.66,.58))
	var door_mat:=G.material("",Color(.27,.23,.18))
	var shutter:=G.material("",Color(.30,.37,.39))
	for feature in mapped_buildings:
		if not feature.holes.is_empty(): continue
		var polygon:=PackedVector2Array()
		var floor_y:=-INF
		var low_y:=INF
		for coord in feature.footprint:
			var p:=_v2(coord)
			polygon.append(p)
			floor_y=maxf(floor_y,height_at(p.x,p.y))
			low_y=minf(low_y,height_at(p.x,p.y))
		var frontage_index:=int(feature.frontage)
		if Geometry2D.is_polygon_clockwise(polygon):
			polygon.reverse()
			frontage_index=posmod(polygon.size()-2-frontage_index,polygon.size())
		# Check entire perimeter and interior at collision-grid resolution.
		for edge_index in range(polygon.size()):
			var a:=polygon[edge_index]
			var b:=polygon[(edge_index+1)%polygon.size()]
			# Exact breakpoints of the piecewise-linear collision field. Maxima
			# can occur where a footprint edge crosses a cell/diagonal boundary.
			for axis in [Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var start_value: float=a.dot(axis)
				var end_value: float=b.dot(axis)
				if absf(end_value-start_value)<.0001: continue
				for crossing in range(ceili(minf(start_value,end_value)/4.),floori(maxf(start_value,end_value)/4.)+1):
					var fraction: float=(float(crossing)*4.-start_value)/(end_value-start_value)
					var p:=a.lerp(b,clampf(fraction,0,1))
					floor_y=maxf(floor_y,height_at(p.x,p.y))
					low_y=minf(low_y,height_at(p.x,p.y))
		var bounds:=Rect2(polygon[0],Vector2.ZERO)
		for p in polygon: bounds=bounds.expand(p)
		for x in range(floori(bounds.position.x/4.)*4,ceili(bounds.end.x),4):
			for z in range(floori(bounds.position.y/4.)*4,ceili(bounds.end.y),4):
				if Geometry2D.is_point_in_polygon(Vector2(x,z),polygon):
					floor_y=maxf(floor_y,height_at(x,z))
					low_y=minf(low_y,height_at(x,z))
		if floor_y-low_y>5.0: continue
		floor_y+=.12
		var height:=float(feature.height)
		var indices:=Geometry2D.triangulate_polygon(polygon)
		if indices.is_empty(): continue
		var walls:=_tool()
		var foundation:=_tool()
		var roof_tool:=_tool()
		for i in range(polygon.size()):
			var a:=polygon[i]
			var b:=polygon[(i+1)%polygon.size()]
			_quad(walls,Vector3(a.x,floor_y,a.y),Vector3(b.x,floor_y,b.y),Vector3(a.x,floor_y+height,a.y),Vector3(b.x,floor_y+height,b.y))
			_quad(foundation,Vector3(a.x,low_y-.3,a.y),Vector3(b.x,low_y-.3,b.y),Vector3(a.x,floor_y,a.y),Vector3(b.x,floor_y,b.y))
			var edge:=b-a
			var inward:=Vector2(-edge.y,edge.x).normalized()
			if not Geometry2D.is_point_in_polygon((a+b)*.5+inward*.1,polygon): inward=-inward
			for level in range(int(feature.levels)):
				var count:=maxi(1,int(edge.length()/3.0))
				for slot in range(count):
					var p:=a.lerp(b,(float(slot)+.5)/float(count))-inward*.06
					var basis:=Basis(Vector3.UP,-atan2(edge.y,edge.x))
					var size:=Vector3(minf(1.15,edge.length()*.5),1.2,.08)
					var position:=Vector3(p.x,floor_y+float(level)*3+1.6,p.y)
					if level==0 and i==frontage_index:
						size.y=2.2
						position.y=floor_y+1.1
						_batch("door",position,size,shutter if feature.shopfront_inferred else door_mat,basis)
					else:
						_batch("window",position,size,glass,basis)
						for sign in [-1.,1.]:
							_batch("frame",position+basis.x*sign*(size.x*.5+.04),Vector3(.075,size.y+.15,.1),trim,basis)
							_batch("frame",position+Vector3(0,sign*(size.y*.5+.04),0),Vector3(size.x,.075,.1),trim,basis)
			if i==frontage_index and feature.shopfront_inferred and edge.length()>5:
				var p: Vector2=(a+b)*.5-inward*.1
				_batch("shop_sign",Vector3(p.x,floor_y+2.7,p.y),Vector3(minf(edge.length()*.8,5.),.48,.1),G.material("",Color(.20,.35,.38)),Basis(Vector3.UP,-atan2(edge.y,edge.x)))
		for i in range(0,indices.size(),3):
			var a:=polygon[indices[i]]
			var b:=polygon[indices[i+1]]
			var c:=polygon[indices[i+2]]
			if polygon.size()==4 and _convex(polygon):
				# Hipped treatment remains within the exact outline, without overhang.
				var center:=Vector2.ZERO
				for corner in polygon: center+=corner
				center/=float(polygon.size())
				if Geometry2D.is_point_in_polygon(center,polygon):
					# Build once below instead of overlapping flat triangles.
					if i==0:
						for edge_index in range(polygon.size()):
							var ra:=polygon[edge_index]
							var rb:=polygon[(edge_index+1)%polygon.size()]
							if (rb-ra).cross(center-ra)<0:
								var swap:=rb
								rb=ra
								ra=swap
							_triangle(roof_tool,Vector3(ra.x,floor_y+height,ra.y),Vector3(rb.x,floor_y+height,rb.y),Vector3(center.x,floor_y+height+1.1,center.y))
				else: _triangle(roof_tool,Vector3(a.x,floor_y+height,a.y),Vector3(b.x,floor_y+height,b.y),Vector3(c.x,floor_y+height,c.y))
			else: _triangle(roof_tool,Vector3(a.x,floor_y+height,a.y),Vector3(b.x,floor_y+height,b.y),Vector3(c.x,floor_y+height,c.y))
		var wall:=_finish(walls,materials[int(feature.id)%materials.size()],true,"Building")
		wall.set_meta("osm_id",feature.id)
		wall.set_meta("height_inferred",feature.height_inferred)
		_finish(foundation,concrete,true,"Foundation")
		_finish(roof_tool,roof,true,"Roof")
		building_count+=1

func _batch(kind: String,pos: Vector3,size: Vector3,mat: Material,basis:=Basis.IDENTITY) -> void:
	var cell:=plant_cell if kind.begins_with("plant_") else Vector2i(floori(pos.x/128),floori(pos.z/128))
	var key:="%s:%d:%d:%d" % [kind,cell.x,cell.y,mat.get_instance_id()]
	if not batches.has(key): batches[key]={"kind":kind,"mat":mat,"transforms":[]}
	batches[key].transforms.append(Transform3D(basis.scaled(size),pos))

func _generate_vegetation() -> void:
	var bark:=G.material("",Color(.28,.24,.17))
	var leaf:=G.material("",Color(.18,.29,.12))
	leaf.cull_mode=BaseMaterial3D.CULL_DISABLED
	for plant in data.plants:
		var p:=Vector3(float(plant[0]),height_at(float(plant[0]),float(plant[1])),float(plant[1]))
		var s:=float(plant[3])
		plant_cell=Vector2i(floori(p.x/128),floori(p.z/128))
		var variant:=int(plant[2])
		if variant==3 and int(absf(p.x+p.z))%5==0:
			_batch("plant_flower",p,Vector3.ONE*s,leaf)
			continue
		var slope:=Vector2(height_at(p.x+1,p.z)-height_at(p.x-1,p.z),height_at(p.x,p.z+1)-height_at(p.x,p.z-1)).length()*.5
		if slope>.6: continue
		if variant<2:
			var h:=7.0 if variant==0 else 2.8
			_batch("plant_trunk"+str(variant),p+Vector3(0,h*.5*s,0),Vector3(.25,h,.25)*s,bark)
			for angle in range(8 if variant==0 else 5):
				_batch("plant_frond"+str(variant),p+Vector3(0,h*s,0),Vector3(.65,1,5 if variant==0 else 2.8)*s,leaf,Basis.from_euler(Vector3(.26,float(angle)*TAU/(8. if variant==0 else 5.),0)))
		else:
			_batch("plant_trunk2",p+Vector3(0,2*s,0),Vector3(.3,4,.3)*s,bark)
			for offset in [Vector3(-.8,3.8,.3),Vector3(.8,4.2,-.4),Vector3(0,5,0)]:
				_batch("plant_crown2",p+offset*s,Vector3(3.2,2.8,3.2)*s,leaf)

func _frond_mesh() -> ArrayMesh:
	var tool:=_tool()
	for segment in range(10):
		var t0:=float(segment)/10.0
		var t1:=float(segment+1)/10.0
		var w0:=sin(t0*PI)*.5
		var w1:=sin(t1*PI)*.5
		var y0:=sin(t0*PI)*.22-t0*t0*.3
		var y1:=sin(t1*PI)*.22-t1*t1*.3
		_quad(tool,Vector3(-w0,y0,t0),Vector3(w0,y0,t0),Vector3(-w1,y1,t1),Vector3(w1,y1,t1))
	tool.generate_normals()
	tool.index()
	return tool.commit()

func _flush_batches() -> void:
	var cube:=BoxMesh.new()
	cube.size=Vector3.ONE
	var crown:=SphereMesh.new()
	crown.radius=.5
	crown.height=1.0
	crown.radial_segments=12
	crown.rings=6
	var trunk:=CylinderMesh.new()
	trunk.top_radius=.34
	trunk.bottom_radius=.5
	trunk.height=1
	trunk.radial_segments=10
	var frond:=_frond_mesh()
	var flower_scene: Node3D=load("res://assets/periwinkle/periwinkle_plant.gltf").instantiate()
	var flower_nodes: Array=flower_scene.find_children("*","MeshInstance3D",true,false)
	var flower: Mesh=flower_nodes[0].mesh
	for group in batches.values():
		var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=crown if str(group.kind).begins_with("plant_crown") else (trunk if str(group.kind).begins_with("plant_trunk") else (frond if str(group.kind).begins_with("plant_frond") else cube))
		if group.kind=="plant_flower": mm.mesh=flower
		mm.instance_count=group.transforms.size()
		var origin:=Vector3.ZERO
		for transform in group.transforms: origin+=transform.origin
		origin/=float(mm.instance_count)
		for i in range(mm.instance_count):
			var transform: Transform3D=group.transforms[i]
			transform.origin-=origin
			mm.set_instance_transform(i,transform)
		var instance:=MultiMeshInstance3D.new()
		instance.name=group.kind
		instance.multimesh=mm
		instance.position=origin
		instance.material_override=null if group.kind=="plant_flower" else group.mat
		instance.visibility_range_end=240
		if group.kind=="plant_flower": instance.visibility_range_end=70
		if group.kind=="plant_flower": instance.set_meta("flower",true)
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		render_meshes.append(instance)
		if str(group.kind).begins_with("plant_"):
			instance.set_meta("vegetation",true)
			instance.set_meta("stride",8 if group.kind=="plant_frond0" else (5 if group.kind=="plant_frond1" else (3 if group.kind=="plant_crown2" else 1)))
			vegetation.append(instance)
	batches.clear()
	flower_scene.free()

func _generate_roadside() -> void:
	var concrete:=G.material("concrete",Color(.55,.55,.51))
	var metal:=G.material("",Color(.22,.25,.25))
	for coord in data.get("poles_inferred",[]):
		var p:=_v2(coord)
		var y:=height_at(p.x,p.y)
		_batch("utility_pole",Vector3(p.x,y+3.5,p.y),Vector3(.18,7,.18),concrete)
		_batch("utility_arm",Vector3(p.x,y+6.3,p.y),Vector3(1.4,.08,.08),metal)
		for side in [-.5,0.,.5]:
			_batch("utility_insulator",Vector3(p.x+side,y+6.5,p.y),Vector3(.09,.3,.09),G.material("",Color(.25,.19,.13)))
		var body:=StaticBody3D.new()
		var shape:=CollisionShape3D.new()
		var resource:=CylinderShape3D.new()
		resource.radius=.12
		resource.height=7
		shape.shape=resource
		body.position=Vector3(p.x,y+3.5,p.y)
		body.add_child(shape)
		add_child(body)

func apply_graphics(draw_distance: float,density: float,texture_quality: int) -> void:
	for mesh in render_meshes:
		mesh.visibility_range_end=minf(draw_distance,70.0 if mesh.has_meta("flower") else 240.0) if mesh.has_meta("vegetation") else draw_distance
		var mat:=mesh.material_override as StandardMaterial3D
		if mesh.material_override is ShaderMaterial:
			mesh.material_override.set_shader_parameter("detail_normals",texture_quality>=2)
			mesh.material_override.set_shader_parameter("ground_normal",load("res://assets/textures/akurana_ground_normal.jpg") if texture_quality>=2 else null)
			mesh.material_override.set_shader_parameter("grass_texture",load("res://assets/textures/akurana_grass_low.jpg") if texture_quality==0 else load("res://assets/textures/akurana_grass.jpg"))
			mesh.material_override.set_shader_parameter("soil_texture",load("res://assets/textures/akurana_soil_low.jpg") if texture_quality==0 else load("res://assets/textures/akurana_soil.jpg"))
		if mat!=null:
			mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if texture_quality>=2 else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			if mat.resource_name=="AkuranaAsphalt":
				mat.albedo_texture=load("res://assets/textures/asphalt_low.jpg") if texture_quality==0 else load("res://assets/textures/asphalt.png")
				mat.normal_enabled=texture_quality>0
				mat.normal_texture=load("res://assets/textures/asphalt_normal_medium.jpg") if texture_quality==1 else (load("res://assets/textures/asphalt_normal.jpg") if texture_quality>=2 else null)
				mat.roughness_texture=load("res://assets/textures/asphalt_roughness_medium.jpg") if texture_quality==1 else (load("res://assets/textures/asphalt_roughness.jpg") if texture_quality>=2 else null)
	for mesh in vegetation:
		var stride:=int(mesh.get_meta("stride",1))
		mesh.multimesh.visible_instance_count=floori(float(mesh.multimesh.instance_count)/float(stride)*clampf(density,0,1))*stride


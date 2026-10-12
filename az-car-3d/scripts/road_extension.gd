extends Node3D
# Long, connected routes extending the original Colombo road grid.
const G = preload("res://scripts/geometry.gd")
const ROAD_WIDTH := 15.0
func _ready() -> void:
 var asphalt := G.material("asphalt")
 var soil := G.material("concrete", Color(0.49,0.55,0.38))
 var paint := G.material("",Color(0.92,0.89,0.72))
 var shoulder := G.material("concrete")
 # North/south routes join the original streets at z = +/-160.
 for x in [-96.0,0.0,96.0]:
  _strip(Vector3(x,0,-960),Vector3(x,0,-160),asphalt,shoulder,paint)
  _strip(Vector3(x,0,160),Vector3(x,0,960),asphalt,shoulder,paint)
 # Long east-west connectors provide loops instead of dead ends.
 for z in [-960.0,-640.0,-320.0,320.0,640.0,960.0]:
  _strip(Vector3(-96,0,z),Vector3(96,0,z),asphalt,shoulder,paint)
 # Connect rural east-side roads back to the city and to the southern highway.
 _strip(Vector3(160,0,160),Vector3(160,0,960),asphalt,shoulder,paint)
 _strip(Vector3(160,0,-960),Vector3(160,0,-160),asphalt,shoulder,paint)
 _strip(Vector3(96,0,-960),Vector3(160,0,-960),asphalt,shoulder,paint)
 _strip(Vector3(96,0,-640),Vector3(160,0,-640),asphalt,shoulder,paint)
 _strip(Vector3(96,0,640),Vector3(160,0,640),asphalt,shoulder,paint)
 _strip(Vector3(96,0,960),Vector3(160,0,960),asphalt,shoulder,paint)
 # Ground strips and sparse roadside scenery, avoiding dense mobile draw calls.
 for x in [-96.0,0.0,96.0,160.0]:
  for z in range(-960,961,160):
   if abs(z)<200: continue
   G.box(self,Vector3(x,-0.36,z),Vector3(92,0.45,160),soil,true)
   for side in [-1,1]:
    var px: float = x+side*26
    var h := 4.0+float(abs(z/160)%3)*2.0
    G.box(self,Vector3(px,h/2,z+35),Vector3(13,h,18),G.material("facade"+str(abs(z/160)%3)),true)
func _strip(a: Vector3,b: Vector3,asphalt: Material,shoulder: Material,paint: Material) -> void:
 # Short chunks keep mesh bounds near the road being driven; no far-away
 # center culling of an entire kilometre strip. Adjacent chunks share edges.
 var chunks := ceili(a.distance_to(b)/120.0)
 for chunk in range(chunks):
  _segment(a.lerp(b,float(chunk)/chunks),a.lerp(b,float(chunk+1)/chunks),asphalt,shoulder,paint)

func _segment(a: Vector3,b: Vector3,asphalt: Material,shoulder: Material,paint: Material) -> void:
 var d := b-a
 var length := d.length()
 var middle := (a+b)*0.5
 var along_z := absf(d.z)>absf(d.x)
 var size := Vector3(ROAD_WIDTH,0.12,length) if along_z else Vector3(length,0.12,ROAD_WIDTH)
 G.box(self,middle+Vector3(0,-0.06,0),size,asphalt,true)
 var edge := ROAD_WIDTH*0.5+1.4
 for side in [-1,1]:
  var offset := Vector3(side*edge,0,0) if along_z else Vector3(0,0,side*edge)
  var shoulder_size := Vector3(2.6,0.10,length) if along_z else Vector3(length,0.10,2.6)
  G.box(self,middle+offset+Vector3(0,-0.06,0),shoulder_size,shoulder,true)
 for i in range(int(length/20)):
  var t := (float(i)+0.5)*20.0/length
  var p := a.lerp(b,t)
  G.box(self,p+Vector3(0,0.012,0),Vector3(0.16,0.015,7) if along_z else Vector3(7,0.015,0.16),paint)

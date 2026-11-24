extends Node3D

const MODELS := ["res://assets/humans/male.glb", "res://assets/humans/female.glb"]
const HAIR := ["Hair_SimpleParted","Hair_Buzzed","Hair_Long","Hair_Buns"]
var animations: AnimationPlayer
var hair_attachment: BoneAttachment3D

func dress(model_index: int, tint := Color.WHITE, hairstyle := -1) -> void:
	var previous := animations.current_animation if is_instance_valid(animations) else "Idle"
	for child in get_children(): child.free()
	var model := (load(MODELS[clampi(model_index,0,1)]) as PackedScene).instantiate() as Node3D
	add_child(model)
	animations = model.find_children("*","AnimationPlayer",true,false).front()
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not tint.is_equal_approx(Color.WHITE) and mesh.name.to_lower().contains("superhero"):
			var material := mesh.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
			material.albedo_color=tint
			mesh.set_surface_override_material(0,material)
		# Imported skinned meshes use the shared glTF skin and texture resources.
		mesh.visibility_range_end=72.0
	for animation_name in animations.get_animation_list():
		if animation_name not in ["Interact","Jump_Land","Jump_Start","Sitting_Enter","Sitting_Exit"]:
			animations.get_animation(animation_name).loop_mode=Animation.LOOP_LINEAR
	_add_hair(model,model_index,hairstyle)
	play(previous if not previous.is_empty() else "Idle",0)

func _add_hair(model: Node3D, model_index: int, hairstyle: int) -> void:
	var bone: Skeleton3D=model.find_children("*","Skeleton3D",true,false).front()
	var head_index := bone.find_bone("Head")
	if head_index<0: return
	var offset := bone.get_bone_global_rest(head_index).affine_inverse()*bone.global_transform.affine_inverse()*model.global_transform
	hair_attachment=BoneAttachment3D.new()
	hair_attachment.bone_idx=head_index
	bone.add_child(hair_attachment)
	var hairstyles := (load("res://assets/humans/hairstyles.glb") as PackedScene).instantiate() as Node3D
	var style := clampi(hairstyle,0,3) if hairstyle>=0 else (2 if model_index==1 else 0)
	for mesh: MeshInstance3D in hairstyles.find_children("*","MeshInstance3D",true,false):
		if not mesh.name.begins_with(HAIR[style]): mesh.free()
		else: mesh.visibility_range_end=55.0
	hair_attachment.add_child(hairstyles)
	hairstyles.transform=offset

func play(requested: StringName, blend := 0.17) -> void:
	var clip := StringName(String(requested).trim_suffix("_Loop"))
	if animations != null and animations.current_animation != clip and animations.has_animation(clip):
		animations.play(clip,blend)

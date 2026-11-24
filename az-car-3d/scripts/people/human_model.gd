extends Node3D

const MODELS := ["res://assets/humans/male.glb", "res://assets/humans/female.glb"]
var animations: AnimationPlayer

func dress(model_index: int, tint := Color.WHITE) -> void:
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
	play("Idle_Loop",0)

func play(requested: StringName, blend := 0.17) -> void:
	var clip := StringName(String(requested).trim_suffix("_Loop"))
	if animations != null and animations.current_animation != clip and animations.has_animation(clip):
		animations.play(clip,blend)

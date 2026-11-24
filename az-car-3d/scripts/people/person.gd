extends CharacterBody3D

const HumanModel = preload("res://scripts/people/human_model.gd")
const HEIGHT := 1.76
const CROUCH_HEIGHT := 1.09
const RADIUS := 0.29
var model: Node3D
var capsule: CapsuleShape3D
var collider: CollisionShape3D
var walk_input := Vector2.ZERO
var camera_yaw := 0.0
var sprint := false
var crouch := false
var jump := false
var locked := false
var live := false
var swimming := false
var landed_time := 0.0

func _ready() -> void:
	collision_layer=8
	collision_mask=3
	floor_snap_length=0.38
	floor_max_angle=deg_to_rad(47)
	capsule=CapsuleShape3D.new()
	capsule.radius=RADIUS
	capsule.height=HEIGHT
	collider=CollisionShape3D.new()
	collider.shape=capsule
	collider.position.y=HEIGHT/2
	add_child(collider)
	model=HumanModel.new()
	add_child(model)
	set_live(false)

func set_live(value: bool) -> void:
	live=value
	collision_layer=8 if value else 0
	collider.set_deferred("disabled",not value)
	set_physics_process(value)
	velocity=Vector3.ZERO

func _physics_process(delta: float) -> void:
	if locked: return
	var floor_before := is_on_floor()
	var dry_ground := global_position.x > -139.0
	swimming=not dry_ground and absf(global_position.z)<1150 and global_position.y<0.12
	var current_crouch := crouch and not swimming
	if not current_crouch and capsule.height<HEIGHT:
		current_crouch=_head_blocked()
	var height := CROUCH_HEIGHT if current_crouch else HEIGHT
	if capsule.height != height:
		capsule.height=height
		collider.position.y=height/2
	var planar := Vector3(walk_input.x,0,walk_input.y).rotated(Vector3.UP,camera_yaw)
	var speed := 2.2
	if swimming or current_crouch: speed=1.55
	elif sprint: speed=5.5
	elif walk_input.length()>0.78: speed=3.45
	var desired := planar.limit_length()*speed
	velocity.x=move_toward(velocity.x,desired.x,delta*14)
	velocity.z=move_toward(velocity.z,desired.z,delta*14)
	if planar.length_squared()>0.015:
		model.rotation.y=lerp_angle(model.rotation.y,atan2(planar.x,planar.z),1.0-exp(-delta*15))
	if swimming:
		velocity.y=clampf((-0.34-global_position.y)*6.0,-2.0,2.0)
	elif not floor_before:
		velocity.y=maxf(-26.0,velocity.y-16.0*delta)
	elif jump and not current_crouch:
		velocity.y=5.2
		model.play("Jump_Start",0.08)
	jump=false
	var before_fall := velocity.y
	if not swimming and floor_before and planar.length_squared()>0.1:
		_try_step(Vector3(velocity.x,0,velocity.z)*delta)
	move_and_slide()
	if is_on_floor() and not floor_before and before_fall < -4.2:
		landed_time=0.30
		model.play("Jump_Land",0.08)
	landed_time=maxf(0,landed_time-delta)
	if landed_time<=0: _animate(current_crouch,speed)
	if global_position.y < -14.0:
		global_position=Vector3(-6,1,120)
		velocity=Vector3.ZERO

func _head_blocked() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*(CROUCH_HEIGHT-0.1),
		global_position+Vector3.UP*HEIGHT,3)
	query.exclude=[get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _try_step(motion: Vector3) -> void:
	if not test_move(global_transform,motion): return
	var lifted := global_transform.translated(Vector3.UP*0.30)
	if test_move(global_transform,Vector3.UP*0.30) or test_move(lifted,motion): return
	var result := KinematicCollision3D.new()
	if test_move(lifted.translated(motion),Vector3.DOWN*0.34,result) and result.get_normal().y>0.68:
		global_transform=lifted.translated(result.get_travel())

func _animate(low: bool, speed: float) -> void:
	var moving := Vector2(velocity.x,velocity.z).length()>0.18
	if swimming: model.play("Swim_Fwd_Loop" if moving else "Swim_Idle_Loop")
	elif not is_on_floor():
		if model.animations.current_animation!="Jump_Start": model.play("Jump_Loop")
	elif low: model.play("Crouch_Fwd_Loop" if moving else "Crouch_Idle_Loop")
	elif not moving: model.play("Idle_Loop")
	elif sprint: model.play("Sprint_Loop")
	else: model.play("Jog_Fwd_Loop" if speed>3 else "Walk_Loop")

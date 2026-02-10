extends Node
class_name CollisionManager

signal collision_changed

#region Parameters
@export var standing_height: float = 1.75
@export var crouching_height: float = 0.75
@export var crouch_shrinks_radius: bool = true
@export var crouching_radius_scale: float = 0.7
@export var sprint_grows_radius: bool = true
@export var sprinting_radius_scale: float = 1.2
#endregion

# References
var player: CharacterBody3D
var collision_shape: CollisionShape3D

# State
var is_crouched: bool = false
var is_sprinting: bool = false
var original_capsule_radius: float = 0.41


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player:
		collision_shape = player.get_node("CollisionShape") as CollisionShape3D
		_initialize_collision()


func _initialize_collision() -> void:
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		collision_shape.shape = collision_shape.shape.duplicate()
		var capsule = collision_shape.shape as CapsuleShape3D
		standing_height = capsule.height
		original_capsule_radius = capsule.radius
		collision_shape.position.y = standing_height / 2.0


func crouch() -> void:
	if is_crouched:
		return
	
	is_crouched = true
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = crouching_height
		capsule.radius = original_capsule_radius * crouching_radius_scale if crouch_shrinks_radius else original_capsule_radius
		collision_shape.position.y = crouching_height / 2.0
	
	collision_changed.emit()


func stand() -> void:
	if not is_crouched:
		return
	
	is_crouched = false
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = standing_height
		capsule.radius = original_capsule_radius
		collision_shape.position.y = standing_height / 2.0
	
	collision_changed.emit()


func set_sprinting(sprinting: bool) -> void:
	is_sprinting = sprinting
	if sprinting:
		_grow_radius()
	else:
		_restore_radius()
	
	collision_changed.emit()


func check_ceiling() -> bool:
	if not player:
		return false
	
	var space_state = player.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * crouching_height / 2.0,
		player.global_position + Vector3.UP * (standing_height / 2.0 + 0.2)
	)
	query.exclude = [player]
	
	var result = space_state.intersect_ray(query)
	return result.size() > 0


func _grow_radius() -> void:
	if not sprint_grows_radius:
		return
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.radius = original_capsule_radius * sprinting_radius_scale


func _restore_radius() -> void:
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		if is_crouched and crouch_shrinks_radius:
			capsule.radius = original_capsule_radius * crouching_radius_scale
		else:
			capsule.radius = original_capsule_radius

extends Node
class_name ItemViewer

signal viewing_started
signal viewing_ended

#region Parameters
@export var rotation_sensitivity: float = 0.005
@export var return_speed: float = 10.0
@export var min_distance: float = 0.25
@export var max_distance: float = 2.0
@export var scroll_speed: float = 0.1
@export var position_follow_speed: float = 8.0 # Lower = slower
@export var rotation_follow_speed: float = 5.0 # Lower = slower
#endregion

# References
var player: CharacterBody3D
var camera: Camera3D

# State
var is_viewing: bool = false
var is_rotating: bool = false
var is_returning: bool = false
var current_item_root: Node3D = null
var original_position: Vector3
var original_rotation: Vector3
var original_parent: Node
var current_distance: float = 0.5


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player:
		camera = player.get_node("CameraPivot/Camera3D") as Camera3D


func _process(delta: float) -> void:
	# Follow camera with inertia while viewing
	if is_viewing and current_item_root and camera:
		# Calculate target position in front of camera
		var target_pos = camera.global_position + camera.global_transform.basis * Vector3(0, 0, -current_distance)
		
		# Raycast from camera to target position to check for obstacles
		var space_state = player.get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(camera.global_position, target_pos)
		query.exclude = [player, current_item_root]
		query.collision_mask = 1 # Only check world geometry on layer 1
		
		var result = space_state.intersect_ray(query)
		if result:
			# Hit a wall - clamp position to just before the wall, thisll need adjustment or changing
			target_pos = result.position + (camera.global_position - result.position).normalized() * 0.1
		
		# Also enforce minimum distance from player
		var to_item = target_pos - player.global_position
		if to_item.length() < 0.3: # Min distance of 0.3 units
			target_pos = player.global_position + to_item.normalized() * 0.3
		
		# Smoothly move toward target (creates the inertia effect)
		current_item_root.global_position = current_item_root.global_position.lerp(target_pos, position_follow_speed * delta)
		
		# Only match camera rotation if NOT manually rotating
		if not is_rotating:
			# magic
			var clean_basis = current_item_root.global_transform.basis.orthonormalized()
			var current_quat = Quaternion(clean_basis)
			var target_quat = Quaternion(camera.global_transform.basis)
			var new_quat = current_quat.slerp(target_quat, rotation_follow_speed * delta)
			current_item_root.global_transform.basis = Basis(new_quat)
	
	# Lerp back to original if need
	if is_returning and current_item_root:
		current_item_root.global_position = current_item_root.global_position.lerp(original_position, return_speed * delta)
		
		# more magic
		var clean_basis = current_item_root.global_transform.basis.orthonormalized()
		var current_quat = Quaternion(clean_basis)
		var target_quat = Quaternion(Basis.from_euler(original_rotation))
		var new_quat = current_quat.slerp(target_quat, return_speed * delta)
		current_item_root.global_transform.basis = Basis(new_quat)
		
		var dist = current_item_root.global_position.distance_to(original_position)
		if dist < 0.01:
			current_item_root.global_position = original_position
			current_item_root.global_rotation = original_rotation
			is_returning = false
			current_item_root = null


func start_viewing(item_root: Node3D, restore_on_exit: bool = true) -> void:
	if is_viewing:
		return
	
	is_viewing = true
	current_item_root = item_root
	
	# Only store original transform if we're going to restore it
	if restore_on_exit:
		original_position = item_root.global_position
		original_rotation = item_root.global_rotation
		original_parent = item_root.get_parent()
	
	
	# Calculate initial distance
	var to_item = item_root.global_position - camera.global_position
	var camera_forward = - camera.global_transform.basis.z
	current_distance = to_item.dot(camera_forward)
	current_distance = clamp(current_distance, min_distance, max_distance)
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	HUD.hide_interaction_prompt()
	HUD.show_control_prompt("[Hold E] View Item | [RMB] Rotate | [Scroll] Distance")
	
	viewing_started.emit()


func exit_viewing() -> void:
	if not is_viewing or not current_item_root:
		return
	
	var item_to_restore = current_item_root
	var pos_to_restore = original_position
	var rot_to_restore = original_rotation
	var parent_to_restore = original_parent
	
	# Clear state befre starting return
	is_viewing = false
	is_rotating = false
	current_item_root = null
	original_parent = null
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	HUD.hide_control_prompt()
	
	viewing_ended.emit()
	
	# Only restore if we had a parent (meaning it's a static viewable)
	if parent_to_restore:
		# Start return
		_return_item_to_position(item_to_restore, pos_to_restore, rot_to_restore)


func _return_item_to_position(item: Node3D, target_pos: Vector3, target_rot: Vector3) -> void:
	# Animate return in a separate function so it doesn't interfere with new interactions
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(item, "global_position", target_pos, 0.5).set_ease(Tween.EASE_IN_OUT)
	
	# Use basis for rotation to avoid gimbal lock
	var target_basis = Basis.from_euler(target_rot)
	tween.tween_property(item, "global_transform:basis", target_basis, 0.5).set_ease(Tween.EASE_IN_OUT)


func handle_input(event: InputEvent) -> bool:
	if not is_viewing:
		return false
	
	if event.is_action_released("interact"):
		exit_viewing()
		return true
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_rotating = event.pressed
		return true
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			current_distance -= scroll_speed
			current_distance = clamp(current_distance, min_distance, max_distance)
			return true
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			current_distance += scroll_speed
			current_distance = clamp(current_distance, min_distance, max_distance)
			return true
	
	if event is InputEventMouseMotion and is_rotating:
		_rotate_item(event.relative)
		return true
	
	return false


func _rotate_item(mouse_delta: Vector2) -> void:
	if not current_item_root:
		return
	
	current_item_root.rotate_object_local(Vector3.UP, -mouse_delta.x * rotation_sensitivity)
	current_item_root.rotate_object_local(Vector3.RIGHT, -mouse_delta.y * rotation_sensitivity)

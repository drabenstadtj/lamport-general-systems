extends Node
class_name CameraController

#region Parameters
@export var mouse_sensitivity: float = 0.003
@export_range(-90.0, 0.0, 1.0) var camera_x_min: float = -60.0
@export_range(0.0, 90.0, 1.0) var camera_x_max: float = 60.0
@export var default_fov: float = 75.0
@export var sprint_fov: float = 85.0
@export var walk_fov: float = 75.0
@export var zoom_fov: float = 40.0
@export var fov_transition_speed: float = 8.0
@export var crouch_height: float = -0.5
@export var crouch_speed: float = 8.0
@export var strafe_lean_amount: float = 3.0  # Degrees to lean when strafing
@export var lean_speed: float = 8.0  # How fast to lean

#endregion
# Hit shake/knockback state
var _shake_trauma: float = 0.0
var _shake_intensity: float = 0.006  # radians
var _shake_decay: float = 4.0
@export var knockback_amount: float = 0.15  # radians of upward pitch kick
var _knockback_offset: float = 0.0
var _knockback_decay: float = 2.5

# Injury bob
var _injury_amount: float = 0.0
var _bob_phase: float = 0.0
@export var injury_bob_speed: float = 1.6     # cycles per second while moving
@export var injury_tilt: float = 2.5          # degrees of persistent roll toward injured side
@export var injury_bob_roll: float = 3.5      # degrees of roll swing on top of tilt

# References
var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D

# State
var camera_rotation: Vector2 = Vector2.ZERO
var mouse_motion: Vector2 = Vector2.ZERO
var is_zooming: bool = false
var is_locked: bool = false
var default_y_position: float = 0.0
var current_lean: float = 0.0
var is_player_sprinting: bool = false
var is_player_walking: bool = false

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player:
		camera_pivot = player.get_node("CameraPivot") as Node3D
		camera = player.get_node("CameraPivot/Camera3D") as Camera3D
		
		if camera_pivot:
			default_y_position = camera_pivot.position.y
		if camera:
			camera.fov = default_fov

func _physics_process(delta: float) -> void:
	if not is_locked:
		_update_rotation(delta)
	_update_fov(delta)
	_update_lean(delta)

func add_mouse_motion(motion: Vector2) -> void:
	if not is_locked:
		mouse_motion += motion

func set_zooming(zooming: bool) -> void:
	is_zooming = zooming

func lock_camera() -> void:
	is_locked = true
	mouse_motion = Vector2.ZERO

func unlock_camera() -> void:
	is_locked = false

func update_position(is_sprinting: bool, is_crouched: bool, is_walking: bool, delta: float) -> void:
	if not camera_pivot:
		return
	
	# Only handle crouch position
	var target_y = default_y_position + (crouch_height if is_crouched else 0.0)
	camera_pivot.position.y = lerp(camera_pivot.position.y, target_y, crouch_speed * delta)
	
	# Update FOV based on movement state
	_update_movement_fov(is_sprinting, is_walking)

func _update_rotation(delta: float) -> void:
	# Apply mouse input
	if mouse_motion != Vector2.ZERO:
		if player:
			player.rotation.y -= mouse_motion.x * mouse_sensitivity
		camera_rotation.x -= mouse_motion.y * mouse_sensitivity
		camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(camera_x_min), deg_to_rad(camera_x_max))
		mouse_motion = Vector2.ZERO

	# Decay knockback and shake every frame
	_knockback_offset = move_toward(_knockback_offset, 0.0, _knockback_decay * delta)
	_shake_trauma = max(_shake_trauma - _shake_decay * delta, 0.0)
	var shake := _shake_trauma * _shake_trauma

	if camera_pivot:
		camera_pivot.rotation.x = camera_rotation.x + _knockback_offset \
			+ randf_range(-_shake_intensity, _shake_intensity) * shake
		camera_pivot.rotation.y = randf_range(-_shake_intensity, _shake_intensity) * shake

func _update_movement_fov(is_sprinting: bool, is_walking: bool) -> void:
	is_player_sprinting = is_sprinting
	is_player_walking = is_walking

func _update_fov(delta: float) -> void:
	if not camera:
		return

	var target_fov: float
	if is_locked:
		target_fov = default_fov
	elif is_zooming:
		target_fov = zoom_fov
	elif is_player_sprinting:
		target_fov = sprint_fov
	elif is_player_walking:
		target_fov = walk_fov
	else:
		target_fov = default_fov

	camera.fov = lerp(camera.fov, target_fov, fov_transition_speed * delta)

func set_injury(hits_remaining: int, max_hits: int) -> void:
	_injury_amount = 1.0 - (float(hits_remaining) / float(max_hits))

func _update_lean(delta: float) -> void:
	if not camera_pivot:
		return

	var strafe_input = 0.0 if is_locked else Input.get_axis("move_left", "move_right")
	var target_lean = -strafe_input * strafe_lean_amount
	current_lean = lerp(current_lean, target_lean, lean_speed * delta)

	var injury_offset := 0.0
	if _injury_amount > 0.0:
		if player and player.velocity.length() > 0.5:
			_bob_phase += delta * injury_bob_speed * TAU
		injury_offset = injury_tilt * _injury_amount + sin(_bob_phase) * injury_bob_roll * _injury_amount

	camera_pivot.rotation_degrees.z = current_lean + injury_offset

func trigger_hit_shake() -> void:
	_shake_trauma = 1.0
	_knockback_offset = knockback_amount

func reset_effects() -> void:
	_shake_trauma = 0.0
	_knockback_offset = 0.0
	_injury_amount = 0.0
	_bob_phase = 0.0
	if camera_pivot:
		camera_pivot.rotation.x = camera_rotation.x
		camera_pivot.rotation.y = 0.0

func get_camera() -> Camera3D:
	return camera

func reset_transform() -> void:
	if camera:
		camera.transform = Transform3D()

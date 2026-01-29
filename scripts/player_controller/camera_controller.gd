extends Node
class_name CameraController

signal camera_rotated(rotation: Vector2)

#region Parameters
@export var mouse_sensitivity: float = 0.003
@export_range(-90.0, 0.0, 1.0) var camera_x_min: float = -60.0
@export_range(0.0, 90.0, 1.0) var camera_x_max: float = 60.0
@export var default_fov: float = 75.0
@export var sprint_fov: float = 85.0
@export var zoom_fov: float = 40.0
@export var fov_transition_speed: float = 8.0
@export var position_transition_speed: float = 10.0
#endregion

# References
var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var walking_camera_pos: Node3D
var standing_camera_pos: Node3D
var crouching_camera_pos: Node3D
var sprinting_camera_pos: Node3D

# State
var camera_rotation: Vector2 = Vector2.ZERO
var mouse_motion: Vector2 = Vector2.ZERO
var is_zooming: bool = false
var is_locked: bool = false


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player:
		camera_pivot = player.get_node("CameraPivot") as Node3D
		camera = player.get_node("CameraPivot/Camera3D") as Camera3D
		walking_camera_pos = player.get_node("WalkingCameraPosition") as Node3D
		standing_camera_pos = player.get_node("StandingCameraPosition") as Node3D
		crouching_camera_pos = player.get_node("CrouchingCameraPosition") as Node3D
		sprinting_camera_pos = player.get_node("SprintingCameraPosition") as Node3D
		
		_initialize_camera()


func _process(delta: float) -> void:
	if not is_locked:
		_update_rotation(delta)
	_update_fov(delta)


func _initialize_camera() -> void:
	if camera_pivot and standing_camera_pos:
		camera_pivot.position = standing_camera_pos.position
	if camera:
		camera.fov = default_fov


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
	
	var target_pos: Vector3
	
	if is_sprinting and sprinting_camera_pos:
		target_pos = sprinting_camera_pos.position
	elif is_crouched and crouching_camera_pos:
		target_pos = crouching_camera_pos.position
	elif is_walking and walking_camera_pos:
		target_pos = walking_camera_pos.position
	elif standing_camera_pos:
		target_pos = standing_camera_pos.position
	else:
		target_pos = camera_pivot.position
	
	camera_pivot.position = camera_pivot.position.lerp(target_pos, position_transition_speed * delta)


func _update_rotation(delta: float) -> void:
	if mouse_motion == Vector2.ZERO:
		return
	
	if player:
		player.rotation.y -= mouse_motion.x * mouse_sensitivity
	
	camera_rotation.x -= mouse_motion.y * mouse_sensitivity
	
	var min_rad = deg_to_rad(camera_x_min)
	var max_rad = deg_to_rad(camera_x_max)
	camera_rotation.x = clamp(camera_rotation.x, min_rad, max_rad)
	
	if camera_pivot:
		camera_pivot.rotation.x = camera_rotation.x
	
	camera_rotated.emit(camera_rotation)
	mouse_motion = Vector2.ZERO


func _update_fov(delta: float) -> void:
	if not camera:
		return
	
	var target_fov: float
	if is_zooming:
		target_fov = zoom_fov
	elif player and player.get("is_sprinting"):
		target_fov = sprint_fov
	else:
		target_fov = default_fov
	
	camera.fov = lerp(camera.fov, target_fov, fov_transition_speed * delta)


func get_camera() -> Camera3D:
	return camera


func reset_transform() -> void:
	if camera:
		camera.transform = Transform3D()

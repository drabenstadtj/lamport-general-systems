extends CharacterBody3D

# Movement parameters
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var friction: float = 10.0
@export var air_control: float = 3.0
@export var rotate_to_movement: bool = false
@export var rotation_speed: float = 10.0

# Camera parameters
@export var mouse_sensitivity: float = 0.003
@export var camera_x_min: float = -89.0
@export var camera_x_max: float = 89.0

# Collision parameters
@export var standing_height: float = 2.0
@export var crouching_height: float = 1.0
@export var standing_camera_height: float = 1.6 
@export var crouching_camera_height: float = 0.9 

# Terminal viewing parameters
@export var view_transition_speed: float = 5.0
@export var interaction_range: float = 3.0

@onready var state_machine: StateMachine = $StateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var interaction_raycast: RayCast3D
var mouse_motion: Vector2 = Vector2.ZERO
var is_crouched: bool = false
var camera_rotation: Vector2 = Vector2.ZERO

# Terminal viewing state
var is_viewing_terminal: bool = false
var current_terminal: NodeTerminal = null
var original_camera_transform: Transform3D
var original_pivot_transform: Transform3D
var target_camera_position: Vector3
var stored_velocity: Vector3 = Vector3.ZERO
var returning_from_view: bool = false
var return_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		standing_height = collision_shape.shape.height
		collision_shape.position.y = standing_height / 2.0
	
	if camera_pivot:
		camera_pivot.position.y = standing_camera_height
	
	# Setup interaction raycast
	interaction_raycast = RayCast3D.new()
	camera.add_child(interaction_raycast)
	interaction_raycast.target_position = Vector3(0, 0, -interaction_range)
	interaction_raycast.enabled = true
	interaction_raycast.collide_with_areas = false
	interaction_raycast.collide_with_bodies = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if not is_viewing_terminal:
			mouse_motion += event.relative
	
	if event.is_action_pressed("interact"):
		if is_viewing_terminal and current_terminal:
			stop_viewing_terminal()
		else:
			try_interact()
	
	if event.is_action_pressed("ui_cancel"):
		if is_viewing_terminal:
			stop_viewing_terminal()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if is_viewing_terminal:
		handle_viewing_mode(delta)
	else:
		handle_normal_mode(delta)

func handle_normal_mode(delta: float) -> void:
	if mouse_motion != Vector2.ZERO:
		rotate_camera(mouse_motion)
		mouse_motion = Vector2.ZERO
	
	if camera_pivot:
		var target_height = crouching_camera_height if is_crouched else standing_camera_height
		var current_pos = camera_pivot.position
		current_pos.y = lerp(current_pos.y, target_height, 10.0 * delta)
		camera_pivot.position = current_pos

func handle_viewing_mode(delta: float) -> void:
	if not current_terminal:
		return
	
	# Smoothly interpolate camera to viewing position
	camera.global_position = camera.global_position.lerp(
		target_camera_position, 
		view_transition_speed * delta
	)
	
	var look_at_pos = current_terminal.get_look_at_position()
	var current_transform = camera.global_transform
	var target_transform = current_transform.looking_at(look_at_pos, Vector3.UP)
	camera.global_transform = current_transform.interpolate_with(
		target_transform,
		view_transition_speed * delta
	)
	
	velocity = Vector3.ZERO

	
func rotate_camera(mouse_delta: Vector2) -> void:
	rotation.y -= mouse_delta.x * mouse_sensitivity
	camera_rotation.x -= mouse_delta.y * mouse_sensitivity
	camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(camera_x_min), deg_to_rad(camera_x_max))
	
	if camera_pivot:
		camera_pivot.rotation = Vector3(camera_rotation.x, 0, 0)
		
func crouch_down() -> void:
	if is_crouched:
		return
	
	is_crouched = true
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = crouching_height
		collision_shape.position.y = crouching_height / 2.0

func stand_up() -> void:
	if not is_crouched:
		return
	
	is_crouched = false
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = standing_height
		collision_shape.position.y = standing_height / 2.0

func check_ceiling() -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * crouching_height / 2.0,
		global_position + Vector3.UP * (standing_height / 2.0 + 0.2)
	)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func get_input_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

# ═══════════════════════════════════════════
# Terminal Interaction Functions
# ═══════════════════════════════════════════

func try_interact() -> void:
	if not interaction_raycast or not interaction_raycast.is_colliding():
		return
	
	var collider = interaction_raycast.get_collider()
	if not collider:
		return
	
	var terminal: NodeTerminal = null
	if collider is NodeTerminal:
		terminal = collider
	elif collider.get_parent() is NodeTerminal:
		terminal = collider.get_parent()
	
	if terminal:
		terminal.interact(self)

func start_viewing_terminal(terminal: NodeTerminal) -> void:
	is_viewing_terminal = true
	current_terminal = terminal
	
	original_camera_transform = camera.global_transform
	original_pivot_transform = camera_pivot.transform
	stored_velocity = velocity
	
	target_camera_position = terminal.get_camera_position()
	
	if state_machine:
		state_machine.set_physics_process(false)


func stop_viewing_terminal() -> void:
	if not is_viewing_terminal:
		return
	
	is_viewing_terminal = false
	
	if current_terminal:
		current_terminal.stop_viewing(self)
	
	if state_machine:
		state_machine.set_physics_process(true)
	
	# Smoothly return camera (or just snap it)
	camera.transform = Transform3D()
	
	current_terminal = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func get_looking_at_terminal() -> NodeTerminal:
	if not interaction_raycast or not interaction_raycast.is_colliding():
		return null
	
	var collider = interaction_raycast.get_collider()
	if not collider:
		return null
	
	if collider is NodeTerminal:
		return collider
	elif collider.get_parent() is NodeTerminal:
		return collider.get_parent()
	
	return null

extends CharacterBody3D

# Movement parameters
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var friction: float = 10.0
@export var air_control: float = 3.0
@export var rotate_to_movement: bool = false  # False for first-person
@export var rotation_speed: float = 10.0

# Camera parameters
@export var mouse_sensitivity: float = 0.003
@export var camera_x_min: float = -89.0  # Look down limit
@export var camera_x_max: float = 89.0   # Look up limit

# Collision parameters
@export var standing_height: float = 2.0
@export var crouching_height: float = 1.0
@export var standing_camera_height: float = 1.6 
@export var crouching_camera_height: float = 0.9 


@onready var state_machine: StateMachine = $StateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var mouse_motion: Vector2 = Vector2.ZERO

var is_crouched: bool = false
var camera_rotation: Vector2 = Vector2.ZERO
var initial_camera_height: float = 0.0

func _ready() -> void:
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Enable physics interpolation for smooth movement
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	
	# Store initial collision height
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		standing_height = collision_shape.shape.height
		
		# Position collision shape so bottom is at origin (feet)
		# Capsule center should be at half its height
		collision_shape.position.y = standing_height / 2.0
	
	# Set camera to standing height
	if camera_pivot:
		camera_pivot.position.y = standing_camera_height

func _input(event: InputEvent) -> void:
	# Just store mouse motion, don't rotate yet
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_motion += event.relative
	
	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Apply camera rotation in physics process
	if mouse_motion != Vector2.ZERO:
		rotate_camera(mouse_motion)
		mouse_motion = Vector2.ZERO
	
	# Camera height lerp
	if camera_pivot:
		var target_height = crouching_camera_height if is_crouched else standing_camera_height
		var current_pos = camera_pivot.position
		current_pos.y = lerp(current_pos.y, target_height, 10.0 * delta)
		camera_pivot.position = current_pos
		
func rotate_camera(mouse_delta: Vector2) -> void:
	# Rotate player left/right
	rotation.y -= mouse_delta.x * mouse_sensitivity
	
	# Rotate camera up/down
	camera_rotation.x -= mouse_delta.y * mouse_sensitivity
	camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(camera_x_min), deg_to_rad(camera_x_max))
	
	# Apply rotation using only X axis
	if camera_pivot:
		camera_pivot.rotation = Vector3(camera_rotation.x, 0, 0)
		
func crouch_down() -> void:
	if is_crouched:
		return
	
	is_crouched = true
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = crouching_height
		
		# Keep bottom of capsule at feet (origin)
		collision_shape.position.y = crouching_height / 2.0

func stand_up() -> void:
	if not is_crouched:
		return
	
	is_crouched = false
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = standing_height
		
		# Keep bottom of capsule at feet (origin)
		collision_shape.position.y = standing_height / 2.0

func check_ceiling() -> bool:
	# Raycast upward to check if there's room to stand
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

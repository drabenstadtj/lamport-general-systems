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
@export var standing_camera_height: float = 1.6  # Normal camera height when standing
@export var crouching_camera_height: float = 0.9  # Camera height when crouching


@onready var state_machine: StateMachine = $StateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var is_crouched: bool = false
var camera_rotation: Vector2 = Vector2.ZERO
var initial_camera_height: float = 0.0

func _ready() -> void:
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Store initial collision height
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		standing_height = collision_shape.shape.height
	
	# Set camera to standing height
	if camera_pivot:
		camera_pivot.position.y = standing_camera_height
		print("Camera starting at height: ", camera_pivot.position.y)

func _input(event: InputEvent) -> void:
	# Handle mouse movement for camera
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_camera(event.relative)
	
	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
func _process(delta: float) -> void:
	# Smoothly lerp camera height when crouching/standing
	if camera_pivot:
		# Use absolute heights instead of offset
		var target_height = crouching_camera_height if is_crouched else standing_camera_height
		
		camera_pivot.position.y = lerp(camera_pivot.position.y, target_height, 10.0 * delta)
		
func rotate_camera(mouse_delta: Vector2) -> void:
	# Rotate player left/right
	rotation.y -= mouse_delta.x * mouse_sensitivity
	
	# Rotate camera up/down
	camera_rotation.x -= mouse_delta.y * mouse_sensitivity
	camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(camera_x_min), deg_to_rad(camera_x_max))
	
	# Apply rotation to camera pivot
	if camera_pivot:
		camera_pivot.rotation.x = camera_rotation.x
		
func crouch_down() -> void:
	if is_crouched:
		return
	
	print("CROUCH_DOWN called - setting is_crouched to TRUE")
	is_crouched = true
	
	# Adjust collision shape - DON'T move it, keep it centered
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = crouching_height

func stand_up() -> void:
	if not is_crouched:
		return
	
	print("STAND_UP called - setting is_crouched to FALSE")
	is_crouched = false
	
	# Restore collision shape
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = standing_height
		# Remove this line: collision_shape.position.y = standing_height / 2.0

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

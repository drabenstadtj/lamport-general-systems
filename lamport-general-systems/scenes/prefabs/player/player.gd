extends CharacterBody3D

# Movement parameters
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var friction: float = 10.0
@export var acceleration: float = 8.0
@export var air_control: float = 3.0
@export var rotate_to_movement: bool = false
@export var rotation_speed: float = 10.0

# Camera parameters
@export var mouse_sensitivity: float = 0.003
@export_range(-90.0, 0.0, 1.0) var camera_x_min: float = -60.0
@export_range(0.0, 90.0, 1.0) var camera_x_max: float = 60.0

# FOV parameters
@export var default_fov: float = 75.0
@export var sprint_fov: float = 85.0
@export var zoom_fov: float = 40.0
@export var fov_transition_speed: float = 8.0

# Terminal viewing
@export var camera_transition_speed: float = 5.0
@export var peek_angle_limit: float = 45.0
@export var peek_sensitivity: float = 0.002
@export var snap_threshold_speed: float = 50.0  # Mouse speed to trigger snap
@export var snap_zones: Array[float] = [-30.0, 0.0, 30.0]  # Left, Center, Right (degrees)
@export var snap_strength: float = 8.0  # How fast it snaps to zones
@export var snap_tolerance: float = 25.0  # Degrees within zone to lock
@export var peek_over_height: float = 0.2  # How high camera moves when peeking over
@export var peek_over_threshold: float = 0.5  # Mouse movement threshold to trigger peek over (in radians)

# Collision parameters
@export var standing_height: float = 1.75
@export var crouching_height: float = 0.75
@export var crouch_shrinks_radius: bool = true
@export var crouching_radius_scale: float = 0.7
@export var sprint_grows_radius: bool = true
@export var sprinting_radius_scale: float = 1.2
var original_capsule_radius: float = 0.41

@onready var state_machine: StateMachine = $StateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var interaction_detector = $CameraPivot/Camera3D/InteractionRaycast

# Camera position markers
@onready var walking_camera_pos: Node3D = $WalkingCameraPosition
@onready var standing_camera_pos: Node3D = $StandingCameraPosition
@onready var crouching_camera_pos: Node3D = $CrouchingCameraPosition
@onready var sprinting_camera_pos: Node3D = $SprintingCameraPosition

var mouse_motion: Vector2 = Vector2.ZERO
var is_crouched: bool = false
var is_sprinting: bool = false
var is_zooming: bool = false 
var is_walking: bool = false
var camera_rotation: Vector2 = Vector2.ZERO

# Terminal viewing
enum PlayerMode { FREE, VIEWING_TERMINAL }
var player_mode: PlayerMode = PlayerMode.FREE
var viewing_terminal: Terminal = null
var target_camera_position: Vector3
var target_camera_look_at: Vector3
var peek_rotation: Vector2 = Vector2.ZERO
var target_peek_rotation: Vector2 = Vector2.ZERO  # Where peek wants to snap to
var last_mouse_velocity: Vector2 = Vector2.ZERO
var is_peeking_over: bool = false
var peek_over_amount: float = 0.0 

# Tutorial Tracking
var has_moved: bool = false

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		collision_shape.shape = collision_shape.shape.duplicate()
		var capsule = collision_shape.shape as CapsuleShape3D
		standing_height = capsule.height
		original_capsule_radius = capsule.radius
		collision_shape.position.y = standing_height / 2.0

	if camera_pivot and standing_camera_pos:
		camera_pivot.position = standing_camera_pos.position
	
	if camera:
		camera.fov = default_fov
	
	if has_node("AnimationTree"):
		var anim_tree = get_node("AnimationTree")
		anim_tree.active = true
		
func _input(event: InputEvent) -> void:
	# Handle terminal viewing mode
	if player_mode == PlayerMode.VIEWING_TERMINAL:
		# ESC to exit terminal
		if event.is_action_pressed("ui_cancel"):
			exit_terminal()
			return
		
		# Mouse movement for peeking around
		if event is InputEventMouseMotion:
			var mouse_velocity = event.relative
			last_mouse_velocity = mouse_velocity
			
			# Check for peek over (forward mouse movement = negative y)
			peek_rotation.y -= mouse_velocity.y * peek_sensitivity
			peek_rotation.y = clamp(peek_rotation.y, -peek_over_threshold, peek_over_threshold)
			
			# Remove the instant boolean toggle - we'll handle it smoothly in physics_process
			
			# Check if movement is fast enough to trigger horizontal snap
			var speed = mouse_velocity.length()
			if speed > snap_threshold_speed:
				var horizontal_direction = sign(mouse_velocity.x)
				snap_to_nearest_zone(horizontal_direction)
			else:
				# Normal horizontal peek movement
				peek_rotation.x -= mouse_velocity.x * peek_sensitivity
				
				# Clamp peek angles
				var peek_limit_rad = deg_to_rad(peek_angle_limit)
				peek_rotation.x = clamp(peek_rotation.x, -peek_limit_rad, peek_limit_rad)
			
			get_viewport().set_input_as_handled()
			return
		
		# Forward keyboard input to terminal UI
		if viewing_terminal and viewing_terminal.terminal_ui:
			if event is InputEventKey:
				viewing_terminal.terminal_ui._input(event)
				get_viewport().set_input_as_handled()
				return
		
		# Ignore interact button while viewing
		if event.is_action_pressed("interact"):
			return
		
		return
	
	# FREE MODE INPUT
	if event.is_action_pressed("ui_cancel"):
		toggle_mouse_mode()
		return
	
	if event.is_action_pressed("zoom"):
		is_zooming = true
		var tutorial_mgr = get_tree().get_first_node_in_group("tutorial_manager")
		if tutorial_mgr:
			tutorial_mgr.complete_step(tutorial_mgr.TutorialStep.ZOOM)
	if event.is_action_released("zoom"):
		is_zooming = false
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_motion += event.relative
	
	if event.is_action_pressed("interact"):
		if interaction_detector:
			interaction_detector.try_interact(self)

func find_closest_snap_zone(current_angle: float) -> float:
	"""Find the snap zone closest to the current angle."""
	var closest_zone = snap_zones[0]
	var min_distance = abs(current_angle - closest_zone)
	
	for zone in snap_zones:
		var distance = abs(current_angle - zone)
		if distance < min_distance:
			min_distance = distance
			closest_zone = zone
	
	return closest_zone

func snap_to_nearest_zone(direction: float) -> void:
	"""Snap to the nearest snap zone in the given direction."""
	var current_angle_deg = rad_to_deg(peek_rotation.x)
	
	# Find target zone
	var target_zone: float = 0.0
	
	if direction > 0:  # Moving right
		# Find nearest zone to the right
		for zone in snap_zones:
			if zone > current_angle_deg:
				target_zone = zone
				break
		# If no zone found, use rightmost
		if target_zone == 0.0:
			target_zone = snap_zones[-1]
	else:  # Moving left
		# Find nearest zone to the left
		for i in range(snap_zones.size() - 1, -1, -1):
			if snap_zones[i] < current_angle_deg:
				target_zone = snap_zones[i]
				break
		# If no zone found, use leftmost
		if target_zone == 0.0:
			target_zone = snap_zones[0]
	
	# Set target rotation
	target_peek_rotation.x = deg_to_rad(target_zone)
	# Keep vertical rotation the same
	target_peek_rotation.y = peek_rotation.y

func _physics_process(delta: float) -> void:
	# Handle camera for terminal viewing
	if player_mode == PlayerMode.VIEWING_TERMINAL:
		handle_terminal_camera(delta)
		velocity = Vector3.ZERO
		return
	
	# Free mode physics
	if mouse_motion != Vector2.ZERO:
		rotate_camera(mouse_motion)
		mouse_motion = Vector2.ZERO

	# Update walking state
	var input_dir = get_input_direction()
	is_walking = input_dir.length() > 0.1 and is_on_floor()
	
	# Tutorial: Check if player has moved
	if not has_moved and velocity.length() > 0.5:
		has_moved = true
		var tutorial_mgr = get_tree().get_first_node_in_group("tutorial_manager")
		if tutorial_mgr:
			tutorial_mgr.complete_step(tutorial_mgr.TutorialStep.MOVE_AROUND)

	# Camera position transitions
	if camera_pivot:
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
		
		camera_pivot.position = camera_pivot.position.lerp(target_pos, 10.0 * delta)
	
	# FOV transitions
	if camera:
		var target_fov: float
		if is_zooming:
			target_fov = zoom_fov
		elif is_sprinting:
			target_fov = sprint_fov
		else:
			target_fov = default_fov
		camera.fov = lerp(camera.fov, target_fov, fov_transition_speed * delta)

func handle_terminal_camera(delta: float) -> void:
	if not viewing_terminal or not camera:
		return
	
	# Smoothly interpolate peek_over_amount based on peek_rotation.y
	var target_peek_amount = 0.0
	if peek_rotation.y > peek_over_threshold * 0.5:
		target_peek_amount = 1.0
	elif peek_rotation.y < peek_over_threshold * 0.25:
		target_peek_amount = 0.0
	else:
		# in between
		var normalized = (peek_rotation.y - peek_over_threshold * 0.25) / (peek_over_threshold * 0.25)
		target_peek_amount = clamp(normalized, 0.0, 1.0)
	
	# lerp peek_over_amount
	peek_over_amount = lerp(peek_over_amount, target_peek_amount, 5.0 * delta)  # Adjust speed here
	
	# Check if we should snap horizontal to center
	var current_angle_deg_x = rad_to_deg(peek_rotation.x)
	var distance_to_center_x = abs(current_angle_deg_x)
	
	# Snap horizontal if within tolerance
	if distance_to_center_x < snap_tolerance:
		target_peek_rotation.x = 0.0
	else:
		target_peek_rotation.x = peek_rotation.x
	
	# Smoothly interpolate peek rotation to target
	var angle_diff = abs(peek_rotation.x - target_peek_rotation.x)
	var snap_tolerance_rad = deg_to_rad(snap_tolerance)
	
	# Use stronger interpolation when snapping to center
	var lerp_speed = snap_strength if angle_diff > snap_tolerance_rad * 0.1 else camera_transition_speed
	peek_rotation.x = lerp(peek_rotation.x, target_peek_rotation.x, lerp_speed * delta)
	
	# calculate camera position with smooth peek over offset
	var camera_target_pos = target_camera_position
	camera_target_pos += Vector3.UP * (peek_over_height * peek_over_amount)  
	
	# smooth move camera to terminal viewing position (with peek over)
	camera.global_position = camera.global_position.lerp(
		camera_target_pos,
		camera_transition_speed * delta
	)
	
	# Adjust look-at target to look UP slightly when peeking over
	var adjusted_look_at = target_camera_look_at
	adjusted_look_at += Vector3.UP * (0.2 * peek_over_amount) 
	
	# Calculate look direction with horizontal peek offset only
	var look_at_direction = (adjusted_look_at - camera.global_position).normalized()
	
	# Create a basis from the look direction
	var forward = look_at_direction
	var right = forward.cross(Vector3.UP).normalized()
	var up = right.cross(forward).normalized()
	
	# Apply only horizontal peek rotation
	var peek_basis = Basis()
	peek_basis = peek_basis.rotated(up, peek_rotation.x)  # Yaw (left/right) only
	
	var final_look_direction = peek_basis * forward
	var final_look_at = camera.global_position + final_look_direction
	
	# Smoothly rotate camera
	var current_transform = camera.global_transform
	var target_transform = current_transform.looking_at(final_look_at, Vector3.UP)
	camera.global_transform = current_transform.interpolate_with(
		target_transform,
		camera_transition_speed * delta
	)

func rotate_camera(mouse_delta: Vector2) -> void:
	rotation.y -= mouse_delta.x * mouse_sensitivity
	camera_rotation.x -= mouse_delta.y * mouse_sensitivity
	var min_rad = deg_to_rad(camera_x_min)
	var max_rad = deg_to_rad(camera_x_max)
	camera_rotation.x = clamp(camera_rotation.x, min_rad, max_rad)
	
	if camera_pivot:
		camera_pivot.rotation.x = camera_rotation.x

# Terminal interaction
func start_viewing_terminal(terminal: Terminal) -> void:
	player_mode = PlayerMode.VIEWING_TERMINAL
	viewing_terminal = terminal
	
	target_camera_position = terminal.get_camera_position()
	target_camera_look_at = terminal.get_look_at_position()
	
	peek_rotation = Vector2.ZERO
	target_peek_rotation = Vector2.ZERO
	peek_over_amount = 0.0
	
	if state_machine:
		state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Hide interaction prompt
	HUD.hide_interaction_prompt()
	HUD.show_control_prompt("[ESC] Exit Terminal")
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Tutorial: Notify terminal interaction
	var tutorial_mgr = get_tree().get_first_node_in_group("tutorial_manager")
	if tutorial_mgr:
		tutorial_mgr.complete_step(tutorial_mgr.TutorialStep.INTERACT_WITH_TERMINAL)

func exit_terminal() -> void:
	if viewing_terminal:
		viewing_terminal.stop_viewing(self)
	
	player_mode = PlayerMode.FREE
	viewing_terminal = null
	peek_rotation = Vector2.ZERO
	peek_over_amount = 0.0
	
	# Re-enable state machine
	if state_machine:
		state_machine.process_mode = Node.PROCESS_MODE_INHERIT
	
	if camera:
		camera.transform = Transform3D()
	
	HUD.hide_control_prompt()
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func toggle_mouse_mode() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Movement helpers

func set_sprinting(sprinting: bool) -> void:
	is_sprinting = sprinting
	if sprinting:
		grow_collision_radius()
	else:
		restore_collision_radius()

func set_walking(walking: bool) -> void:
	is_walking = walking
		
func crouch_down() -> void:
	if is_crouched:
		return
	
	is_crouched = true
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = crouching_height
		
		if crouch_shrinks_radius:
			capsule.radius = original_capsule_radius * crouching_radius_scale
		else:
			capsule.radius = original_capsule_radius
			
		collision_shape.position.y = crouching_height / 2.0

func stand_up() -> void:
	if not is_crouched:
		return
	
	is_crouched = false
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.height = standing_height
		capsule.radius = original_capsule_radius
		collision_shape.position.y = standing_height / 2.0

func grow_collision_radius() -> void:
	if not sprint_grows_radius:
		return
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		capsule.radius = original_capsule_radius * sprinting_radius_scale

func restore_collision_radius() -> void:
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule = collision_shape.shape as CapsuleShape3D
		if is_crouched and crouch_shrinks_radius:
			capsule.radius = original_capsule_radius * crouching_radius_scale
		else:
			capsule.radius = original_capsule_radius

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
	if player_mode == PlayerMode.VIEWING_TERMINAL:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

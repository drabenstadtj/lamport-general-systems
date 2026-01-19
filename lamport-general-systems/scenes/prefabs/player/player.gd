extends CharacterBody3D

#region Movement Parameters
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
#endregion

# Node References
@onready var state_machine: StateMachine = $StateMachine
@onready var interaction_detector = $CameraPivot/Camera3D/InteractionRaycast
@onready var terminal_viewer: TerminalViewer = $TerminalViewer
@onready var collision_manager: CollisionManager = $CollisionManager
@onready var camera_controller: CameraController = $CameraController
@onready var viewing_item_pos: Node3D = $CameraPivot/Camera3D/ItemViewPosition

# Movement State
var is_crouched: bool = false
var is_sprinting: bool = false
var is_walking: bool = false

# Tutorial Tracking
var has_moved: bool = false


# LIFECYCLE

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	
	_setup_animation()
	_connect_signals()


func _input(event: InputEvent) -> void:
	# Let terminal viewer handle input first if active
	if terminal_viewer and terminal_viewer.handle_input(event):
		return
	
	_handle_free_input(event)


func _process(delta: float) -> void:
	if collision_manager:
		camera_controller.update_position(
			is_sprinting,
			collision_manager.is_crouched,
			is_walking,
			delta
		)


func _physics_process(delta: float) -> void:
	# Skip movement if terminal viewing is active
	if terminal_viewer and terminal_viewer.is_viewing:
		velocity = Vector3.ZERO
		return
	
	_update_movement_state()


# SETUP

func _setup_animation() -> void:
	if has_node("AnimationTree"):
		var anim_tree = get_node("AnimationTree")
		anim_tree.active = true


func _connect_signals() -> void:
	if terminal_viewer:
		terminal_viewer.viewing_started.connect(_on_terminal_viewing_started)
		terminal_viewer.viewing_ended.connect(_on_terminal_viewing_ended)


# INPUT HANDLING

func _handle_free_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_mouse_mode()
		return
	
	if event.is_action_pressed("zoom"):
		if camera_controller:
			camera_controller.set_zooming(true)
		_notify_tutorial_zoom()
	
	if event.is_action_released("zoom"):
		if camera_controller:
			camera_controller.set_zooming(false)
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if camera_controller:
			camera_controller.add_mouse_motion(event.relative)
	
	if event.is_action_pressed("interact"):
		if interaction_detector:
			interaction_detector.try_interact(self)


# TERMINAL VIEWING

func start_viewing_terminal(terminal: Terminal) -> void:
	if terminal_viewer:
		terminal_viewer.start_viewing(terminal)


func _on_terminal_viewing_started() -> void:
	if camera_controller:
		camera_controller.lock_camera()


func _on_terminal_viewing_ended() -> void:
	if camera_controller:
		camera_controller.unlock_camera()
		camera_controller.reset_transform()


# MOVEMENT

func _update_movement_state() -> void:
	var input_dir = get_input_direction()
	is_walking = input_dir.length() > 0.1 and is_on_floor()
	
	if not has_moved and velocity.length() > 0.5:
		has_moved = true
		_notify_tutorial_movement()


func get_input_direction() -> Vector2:
	if terminal_viewer and terminal_viewer.is_viewing:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")


func set_sprinting(sprinting: bool) -> void:
	is_sprinting = sprinting
	if collision_manager:
		collision_manager.set_sprinting(sprinting)


func set_walking(walking: bool) -> void:
	is_walking = walking


# COLLISION (DELEGATE TO COMPONENT)

func crouch_down() -> void:
	if collision_manager:
		collision_manager.crouch()
		is_crouched = collision_manager.is_crouched


func stand_up() -> void:
	if collision_manager:
		collision_manager.stand()
		is_crouched = collision_manager.is_crouched


func check_ceiling() -> bool:
	if collision_manager:
		return collision_manager.check_ceiling()
	return false


# UTILITIES

func toggle_mouse_mode() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notify_tutorial_zoom() -> void:
	var tutorial_mgr = get_tree().get_first_node_in_group("tutorial_manager")
	if tutorial_mgr:
		tutorial_mgr.complete_step(tutorial_mgr.TutorialStep.ZOOM)


func _notify_tutorial_movement() -> void:
	var tutorial_mgr = get_tree().get_first_node_in_group("tutorial_manager")
	if tutorial_mgr:
		tutorial_mgr.complete_step(tutorial_mgr.TutorialStep.MOVE_AROUND)

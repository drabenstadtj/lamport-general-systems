extends CharacterBody3D

#region Movement Parameters
@export var walk_speed: float = 6.0
@export var run_speed: float = 10.0
@export var crouch_speed: float = 3.0
@export var jump_velocity: float = 5.5
@export var gravity: float = 15.0
@export var friction: float = 20.0
@export var acceleration: float = 15.0
@export var air_control: float = 8.0
#endregion

# Node References
@onready var state_machine: StateMachine = $StateMachine
@onready var interaction_detector = $CameraPivot/Camera3D/InteractionRaycast
@onready var terminal_viewer: TerminalViewer = $TerminalViewer
@onready var pda_viewer: PDAViewer = $PDAViewer
@onready var item_viewer: ItemViewer = $ItemViewer
@onready var collision_manager: CollisionManager = $CollisionManager
@onready var camera_controller: CameraController = $CameraController

# Movement State
var is_crouched: bool = false
var is_sprinting: bool = false
var is_walking: bool = false

func _ready() -> void:
	AIDirector.player = self
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Connect signals for terminal viewing
	if terminal_viewer:
		terminal_viewer.viewing_started.connect(_on_terminal_viewing_started)
		terminal_viewer.viewing_ended.connect(_on_terminal_viewing_ended)
	
	if pda_viewer:
		pda_viewer.viewing_started.connect(_on_pda_viewing_started)
		pda_viewer.viewing_ended.connect(_on_pda_viewing_ended)

func _on_terminal_viewing_started() -> void:
	if camera_controller:
		camera_controller.lock_camera()
	if interaction_detector:
		interaction_detector.enabled = false

func _on_terminal_viewing_ended() -> void:
	if camera_controller:
		camera_controller.unlock_camera()
	if interaction_detector:
		interaction_detector.enabled = true

func _on_pda_viewing_started() -> void:
	if camera_controller:
		camera_controller.lock_camera()
	if interaction_detector:
		interaction_detector.enabled = false

func _on_pda_viewing_ended() -> void:
	if camera_controller:
		camera_controller.unlock_camera()
	if interaction_detector:
		interaction_detector.enabled = true

func _input(event: InputEvent) -> void:
	if pda_viewer and pda_viewer.handle_input(event):
		return
	if terminal_viewer and terminal_viewer.handle_input(event):
		return
	if item_viewer and item_viewer.handle_input(event):
		return
	_handle_free_input(event)

func _process(delta: float) -> void:
	# Update camera crouch position via camera controller
	if collision_manager and camera_controller:
		camera_controller.update_position(is_sprinting, collision_manager.is_crouched, is_walking, delta)

func _physics_process(delta: float) -> void:
	if terminal_viewer and terminal_viewer.is_viewing:
		velocity = Vector3.ZERO
		return
	
	# Update walking state
	var input_dir = get_input_direction()
	is_walking = input_dir.length() > 0.1 and is_on_floor()

func _handle_free_input(event: InputEvent) -> void:
	if event.is_action_pressed("close"):
		get_tree().quit()
	
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	
	if event.is_action_pressed("zoom"):
		if camera_controller:
			camera_controller.set_zooming(true)
	
	if event.is_action_released("zoom"):
		if camera_controller:
			camera_controller.set_zooming(false)
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if camera_controller:
			camera_controller.add_mouse_motion(event.relative)
	
	if event.is_action_pressed("interact"):
		if interaction_detector:
			interaction_detector.try_interact(self)
			
	if event.is_action_pressed("open_pda"):  
		open_pda()

func start_viewing_terminal(terminal: Terminal) -> void:
	if terminal_viewer:
		terminal_viewer.start_viewing(terminal)

func open_pda() -> void:
	if pda_viewer:
		pda_viewer.start_viewing()

func get_input_direction() -> Vector2:
	if terminal_viewer and terminal_viewer.is_viewing:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func set_sprinting(sprinting: bool) -> void:
	is_sprinting = sprinting
	if collision_manager:
		collision_manager.set_sprinting(sprinting)

func crouch_down() -> void:
	if collision_manager:
		collision_manager.crouch()
		is_crouched = collision_manager.is_crouched

func stand_up() -> void:
	if collision_manager:
		collision_manager.stand()
		is_crouched = collision_manager.is_crouched

func check_ceiling() -> bool:
	return collision_manager.check_ceiling() if collision_manager else false

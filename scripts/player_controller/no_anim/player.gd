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
@onready var damage_component: DamageComponent = $DamageComponent
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio

@export_group("Footsteps")
@export var footstep_sounds: Array[AudioStream] = []

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
		
	if damage_component:
		damage_component.player_died.connect(_on_player_died)
		damage_component.hit_taken.connect(_on_hit_taken)

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
		
func _on_hit_taken(hits_remaining: int) -> void:
	if camera_controller:
		camera_controller.trigger_hit_shake()
	_update_hud_health(hits_remaining)

func _on_player_died() -> void:
	_update_hud_health(0)
	if camera_controller:
		camera_controller.reset_effects()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		await hud.fade_to_black(0.25)
	if SaveManager.has_save():
		await SceneManager.reload_current()
		_update_hud_health(damage_component.hits_remaining)
	else:
		damage_component.restore(damage_component.max_hits)
		_update_hud_health(damage_component.max_hits)
		print("[Player] no save found — resetting health in place")
	if hud:
		hud.fade_from_black(0.25)

func _update_hud_health(hits_remaining: int) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.update_health(hits_remaining, damage_component.max_hits)
	camera_controller.set_injury(hits_remaining, damage_component.max_hits)

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

func _physics_process(_delta: float) -> void:
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

func play_footstep(volume_db: float = 0.0) -> void:
	if footstep_sounds.is_empty() or not footstep_audio:
		return
	footstep_audio.stream = footstep_sounds[randi() % footstep_sounds.size()]
	footstep_audio.pitch_scale = randf_range(0.9, 1.1)
	footstep_audio.volume_db = volume_db
	footstep_audio.play()

func check_ceiling() -> bool:
	return collision_manager.check_ceiling() if collision_manager else false

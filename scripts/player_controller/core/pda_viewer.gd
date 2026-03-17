extends Node
class_name PDAViewer

signal viewing_started
signal viewing_ended

# References
var player: CharacterBody3D
var camera: Camera3D
var state_machine: StateMachine
var pda_ui: Control
@export var pda_model: Node3D
@export var pda_viewport: SubViewport

# State
var is_viewing: bool = false
var is_transitioning: bool = false

# Virtual mouse position on the 2D screen
var virtual_mouse_pos: Vector2 = Vector2.ZERO
@export var mouse_sensitivity: float = 0.5

# Positions
@export var hidden_position: Vector3 = Vector3(0, -1, 0.3)
@export var view_position: Vector3 = Vector3(0, 1.5, -0.25)
@export var hidden_rotation: Vector3 = Vector3(-45, 0, 0)
@export var view_rotation: Vector3 = Vector3(0, 0, 0)
@export var transition_speed: float = 8.0

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player:
		camera = player.get_node("CameraPivot/Camera3D") as Camera3D
		state_machine = player.get_node("StateMachine") as StateMachine
	
	if pda_model:
		pda_model.visible = false
		pda_model.position = hidden_position
	
	if pda_viewport:
		pda_viewport.gui_disable_input = false

func _process(delta: float) -> void:
	if is_transitioning:
		_update_pda_position(delta)

func _physics_process(delta: float) -> void:
	if not is_viewing or not player:
		return
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	if not player.is_on_floor():
		player.velocity.y -= 9.8 * delta
	else:
		player.velocity.y = 0.0
	player.move_and_slide()

func start_viewing() -> void:
	if is_viewing or is_transitioning:
		return

	is_viewing = true
	is_transitioning = true
	
	HUD.disable_cursor()

	if state_machine:
		state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	
	if pda_model:
		pda_model.visible = true
	
	# Center virtual mouse on screen
	if pda_viewport:
		virtual_mouse_pos = pda_viewport.size / 2.0
	
	HUD.hide_interaction_prompt()
	HUD.show_control_prompt("[ESC] Close PDA | Move mouse to navigate | [Click] to interact")
	
	# Keep mouse captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	viewing_started.emit()

func exit_viewing() -> void:
	if not is_viewing:
		return
	
	is_viewing = false
	is_transitioning = true
	
	HUD.enable_cursor()
	
	if state_machine:
		state_machine.process_mode = Node.PROCESS_MODE_INHERIT
	
	if pda_ui:
		pda_ui.visible = false
	
	HUD.hide_control_prompt()
	
	viewing_ended.emit()

func _update_pda_position(delta: float) -> void:
	if not pda_model:
		return
	
	var target_pos = view_position if is_viewing else hidden_position
	var target_rot = view_rotation if is_viewing else hidden_rotation
	
	pda_model.position = pda_model.position.lerp(target_pos, transition_speed * delta)
	pda_model.rotation_degrees = pda_model.rotation_degrees.lerp(target_rot, transition_speed * delta)
	
	if pda_model.position.distance_to(target_pos) < 0.01:
		pda_model.position = target_pos
		is_transitioning = false
		
		if is_viewing:
			if pda_ui:
				pda_ui.visible = true
		else:
			pda_model.visible = false

func handle_input(event: InputEvent) -> bool:
	if not is_viewing:
		return false
	
	if is_transitioning:
		return true
	
	# ESC or G to exit
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_G):
		exit_viewing()
		return true
	
	# Mouse movement updates virtual cursor position
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.relative)
		return true
	
	# Mouse clicks sent to viewport at virtual position
	if event is InputEventMouseButton:
		_send_mouse_click(event)
		return true
	
	# Keyboard input forwarded to viewport
	if event is InputEventKey:
		if pda_viewport:
			pda_viewport.push_input(event)
		return true
	
	if event.is_action_pressed("interact"):
		return true
	
	return false

func _handle_mouse_motion(relative: Vector2) -> void:
	if not pda_viewport:
		return
	
	# Move virtual mouse by relative amount
	virtual_mouse_pos += relative * mouse_sensitivity
	
	# Clamp to viewport bounds
	virtual_mouse_pos.x = clamp(virtual_mouse_pos.x, 0, pda_viewport.size.x)
	virtual_mouse_pos.y = clamp(virtual_mouse_pos.y, 0, pda_viewport.size.y)
	
	# Send motion event to viewport
	var motion_event = InputEventMouseMotion.new()
	motion_event.position = virtual_mouse_pos
	motion_event.relative = relative * mouse_sensitivity
	
	pda_viewport.push_input(motion_event)
	
func _send_mouse_click(event: InputEventMouseButton) -> void:
	if not pda_viewport:
		return
	
	var click_event = InputEventMouseButton.new()
	click_event.button_index = event.button_index
	click_event.pressed = event.pressed
	click_event.position = virtual_mouse_pos
	
	pda_viewport.push_input(click_event)

extends Node
class_name TerminalViewer

signal viewing_started
signal viewing_ended

#region Parameters
@export var camera_transition_speed: float = 5.0
@export var peek_angle_limit: float = 45.0
@export var peek_sensitivity: float = 0.002
@export var snap_threshold_speed: float = 50.0
@export var snap_zones: Array[float] = [-30.0, 0.0, 30.0]
@export var vertical_snap_zones: Array[float] = [-30.0, 0.0]
@export var snap_strength: float = 8.0
@export var snap_tolerance: float = 25.0
@export var peek_over_height: float = 0.2
@export var peek_over_threshold: float = 0.5
#endregion

# References
var player: CharacterBody3D
var camera: Camera3D
var state_machine: StateMachine

# State
var is_viewing: bool = false
var viewing_terminal: Node = null
var target_camera_position: Vector3
var target_camera_look_at: Vector3
var peek_rotation: Vector2 = Vector2.ZERO
var target_peek_rotation: Vector2 = Vector2.ZERO
var last_mouse_velocity: Vector2 = Vector2.ZERO
var peek_over_amount: float = 0.0


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player:
		camera = player.get_node("CameraPivot/Camera3D") as Camera3D
		state_machine = player.get_node("StateMachine") as StateMachine


func _process(delta: float) -> void:
	if is_viewing:
		_update_camera(delta)


func start_viewing(terminal: Node) -> void:
	is_viewing = true
	viewing_terminal = terminal
	
	target_camera_position = terminal.get_camera_position()
	target_camera_look_at = terminal.get_look_at_position()
	
	peek_rotation = Vector2.ZERO
	target_peek_rotation = Vector2.ZERO
	peek_over_amount = 0.0
	
	if state_machine:
		state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	
	HUD.hide_interaction_prompt()
	HUD.show_control_prompt("[ESC] Exit Terminal")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	viewing_started.emit()
	
	# Tutorial notification
	var tutorial_mgr = get_tree().get_first_node_in_group("tutorial_manager")
	if tutorial_mgr:
		tutorial_mgr.complete_step(tutorial_mgr.TutorialStep.INTERACT_WITH_TERMINAL)


func exit_viewing() -> void:
	if viewing_terminal:
		viewing_terminal.stop_viewing(player)
	
	is_viewing = false
	viewing_terminal = null
	peek_rotation = Vector2.ZERO
	peek_over_amount = 0.0
	
	if state_machine:
		state_machine.process_mode = Node.PROCESS_MODE_INHERIT
	
	if camera:
		camera.transform = Transform3D()
	
	HUD.hide_control_prompt()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	viewing_ended.emit()


func handle_input(event: InputEvent) -> bool:
	if not is_viewing:
		return false
	
	# ESC to exit
	if event.is_action_pressed("ui_cancel"):
		exit_viewing()
		return true
	
	# Mouse movement for peeking
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event.relative)
		return true
	
	# Forward keyboard input to terminal UI
	if viewing_terminal and viewing_terminal.terminal_ui:
		if event is InputEventKey:
			viewing_terminal.terminal_ui._input(event)
			return true
			
	# Forward mouse wheel to terminal UI too
	if viewing_terminal and viewing_terminal.terminal_ui:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				viewing_terminal.terminal_ui._unhandled_input(event) # or _input(event)
				return true
	
	# Ignore interact button while viewing
	if event.is_action_pressed("interact"):
		return true
	
	return false


func _handle_mouse_motion(mouse_velocity: Vector2) -> void:
	last_mouse_velocity = mouse_velocity
	
	var speed = mouse_velocity.length()
	
	# Vertical peek - down is free with snap, up triggers peek over
	peek_rotation.y -= mouse_velocity.y * peek_sensitivity
	var peek_down_limit = deg_to_rad(peek_angle_limit)
	peek_rotation.y = clamp(peek_rotation.y, -peek_down_limit, peek_over_threshold)
	
	# Vertical snap (only for downward looking)
	if peek_rotation.y < 0:
		if speed > snap_threshold_speed:
			var vertical_direction = sign(-mouse_velocity.y)
			_snap_to_nearest_vertical_zone(vertical_direction)
	
	# Horizontal peek with snap detection
	if speed > snap_threshold_speed:
		var horizontal_direction = sign(mouse_velocity.x)
		_snap_to_nearest_zone(horizontal_direction)
	else:
		peek_rotation.x -= mouse_velocity.x * peek_sensitivity
		var peek_limit_rad = deg_to_rad(peek_angle_limit)
		peek_rotation.x = clamp(peek_rotation.x, -peek_limit_rad, peek_limit_rad)


func _update_camera(delta: float) -> void:
	if not viewing_terminal or not camera:
		return
	
	_update_peek_over_amount(delta)
	_update_peek_rotation(delta)
	_update_camera_transform(delta)


func _update_peek_over_amount(delta: float) -> void:
	var target_peek_amount = 0.0
	
	if peek_rotation.y > peek_over_threshold * 0.5:
		target_peek_amount = 1.0
	elif peek_rotation.y < peek_over_threshold * 0.25:
		target_peek_amount = 0.0
	else:
		var normalized = (peek_rotation.y - peek_over_threshold * 0.25) / (peek_over_threshold * 0.25)
		target_peek_amount = clamp(normalized, 0.0, 1.0)
	
	peek_over_amount = lerp(peek_over_amount, target_peek_amount, 5.0 * delta)


func _update_peek_rotation(delta: float) -> void:
	# Horizontal snap
	var current_angle_deg = rad_to_deg(peek_rotation.x)
	var distance_to_center = abs(current_angle_deg)
	
	if distance_to_center < snap_tolerance:
		target_peek_rotation.x = 0.0
	else:
		target_peek_rotation.x = peek_rotation.x
	
	var angle_diff = abs(peek_rotation.x - target_peek_rotation.x)
	var snap_tolerance_rad = deg_to_rad(snap_tolerance)
	var lerp_speed = snap_strength if angle_diff > snap_tolerance_rad * 0.1 else camera_transition_speed
	
	peek_rotation.x = lerp(peek_rotation.x, target_peek_rotation.x, lerp_speed * delta)
	
	# Vertical snap (only when looking down)
	if peek_rotation.y < 0:
		var current_vert_deg = rad_to_deg(peek_rotation.y)
		var vert_distance_to_center = abs(current_vert_deg)
		
		if vert_distance_to_center < snap_tolerance:
			target_peek_rotation.y = 0.0
		else:
			target_peek_rotation.y = peek_rotation.y
		
		var vert_angle_diff = abs(peek_rotation.y - target_peek_rotation.y)
		var vert_lerp_speed = snap_strength if vert_angle_diff > snap_tolerance_rad * 0.1 else camera_transition_speed
		
		peek_rotation.y = lerp(peek_rotation.y, target_peek_rotation.y, vert_lerp_speed * delta)


func _update_camera_transform(delta: float) -> void:
	# Update position
	var camera_target_pos = target_camera_position + Vector3.UP * (peek_over_height * peek_over_amount)
	camera.global_position = camera.global_position.lerp(camera_target_pos, camera_transition_speed * delta)
	
	# Update rotation
	var adjusted_look_at = target_camera_look_at + Vector3.UP * (0.2 * peek_over_amount)
	var look_at_direction = (adjusted_look_at - camera.global_position).normalized()
	
	var forward = look_at_direction
	var right = forward.cross(Vector3.UP).normalized()
	var up = right.cross(forward).normalized()
	
	var peek_basis = Basis()
	peek_basis = peek_basis.rotated(up, peek_rotation.x)  # Horizontal
	
	# Apply downward rotation (only when looking down, not up)
	if peek_rotation.y < 0:
		peek_basis = peek_basis.rotated(right, peek_rotation.y)
	
	var final_look_direction = peek_basis * forward
	var final_look_at = camera.global_position + final_look_direction
	
	var current_transform = camera.global_transform
	var target_transform = current_transform.looking_at(final_look_at, Vector3.UP)
	camera.global_transform = current_transform.interpolate_with(target_transform, camera_transition_speed * delta)


func _snap_to_nearest_zone(direction: float) -> void:
	var current_angle_deg = rad_to_deg(peek_rotation.x)
	var target_zone: float = 0.0
	
	if direction > 0:
		for zone in snap_zones:
			if zone > current_angle_deg:
				target_zone = zone
				break
		if target_zone == 0.0:
			target_zone = snap_zones[-1]
	else:
		for i in range(snap_zones.size() - 1, -1, -1):
			if snap_zones[i] < current_angle_deg:
				target_zone = snap_zones[i]
				break
		if target_zone == 0.0:
			target_zone = snap_zones[0]
	
	target_peek_rotation.x = deg_to_rad(target_zone)
	target_peek_rotation.y = peek_rotation.y

func _snap_to_nearest_vertical_zone(direction: float) -> void:
	var current_angle_deg = rad_to_deg(peek_rotation.y)
	var target_zone: float = 0.0
	
	if direction > 0:  # Moving up (towards 0)
		for zone in vertical_snap_zones:
			if zone > current_angle_deg:
				target_zone = zone
				break
		if target_zone == 0.0 and current_angle_deg < 0:
			target_zone = vertical_snap_zones[-1]
	else:  # Moving down
		for i in range(vertical_snap_zones.size() - 1, -1, -1):
			if vertical_snap_zones[i] < current_angle_deg:
				target_zone = vertical_snap_zones[i]
				break
		if target_zone == 0.0:
			target_zone = vertical_snap_zones[0]
	
	target_peek_rotation.y = deg_to_rad(target_zone)

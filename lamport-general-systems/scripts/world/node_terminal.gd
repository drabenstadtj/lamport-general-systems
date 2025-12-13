extends Node3D
class_name NodeTerminal

@export var node_id: int = 0
@export var max_log_lines: int = 10

@onready var status_light = $StatusLight
@onready var terminal = $SubViewport/Terminal
@onready var interaction_area: Area3D = $InteractionArea
@onready var collision_body: StaticBody3D = $StaticBody3D
@onready var camera_position_marker: Node3D = $CameraPosition
@onready var camera_lookat_marker: Node3D = $CameraLookAt

var log_entries: Array[String] = []
var player_nearby: bool = false
var is_being_viewed: bool = false

func _ready():
	GameManager.register_node_terminal(node_id, self)
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_player_entered)
		interaction_area.body_exited.connect(_on_player_exited)

func _on_player_entered(body):
	if body.is_in_group("player"):
		player_nearby = true

func _on_player_exited(body):
	if body.is_in_group("player"):
		player_nearby = false

func can_interact() -> bool:
	return player_nearby and not is_being_viewed

func interact(player):
	if can_interact():
		start_viewing(player)
	elif is_being_viewed:
		stop_viewing(player)

func start_viewing(player):
	is_being_viewed = true
	player.start_viewing_terminal(self)
	
	# Enable terminal input when viewing
	if terminal:
		terminal.accept_input = true

func stop_viewing(player):
	is_being_viewed = false
	
	# Disable terminal input when not viewing
	if terminal:
		terminal.accept_input = false

func get_camera_position() -> Vector3:
	if camera_position_marker:
		return camera_position_marker.global_position
	# Fallback if no marker exists
	return global_position + Vector3(0, 0.5, 0.25)

func get_look_at_position() -> Vector3:
	if camera_lookat_marker:
		return camera_lookat_marker.global_position
	# Fallback if no marker exists
	return global_position + Vector3(0, 0.47, 0)

# ═══════════════════════════════════════════
# Logging System
# ═══════════════════════════════════════════

func add_log(message: String):
	if GameManager.network_state:
		var node = GameManager.network_state.get_node(node_id)
		if node and node.is_crashed():
			return
	
	var time = Time.get_ticks_msec() / 1000.0
	var timestamp = "%6.2f" % time
	var log_message = "[%s] %s" % [timestamp, message]
	
	# Add to local array for compatibility
	log_entries.append(log_message)
	if log_entries.size() > max_log_lines:
		log_entries.pop_front()
	
	# Pipe to terminal's system.log file
	if terminal:
		var current_log = terminal.get_file_content("system.log")
		if current_log != "":
			current_log += "\n"
		terminal.set_file_content("system.log", current_log + log_message)

func clear_logs():
	log_entries.clear()
	update_display()

func update_display():
	# Display is now handled by the terminal interface
	# This function is kept for compatibility but does nothing
	pass

func update_visuals():
	if not GameManager.network_state:
		return

	var node = GameManager.network_state.get_node(node_id)
	if not node:
		return

	match node.state:
		Enums.NodeState.HEALTHY:
			if status_light:
				status_light.light_color = Color.GREEN
				status_light.light_energy = 5.0

		Enums.NodeState.CRASHED:
			if status_light:
				status_light.light_color = Color.BLACK
				status_light.light_energy = 0.0

		Enums.NodeState.BYZANTINE:
			if status_light:
				status_light.light_color = Color.RED
				status_light.light_energy = 5.0

# ═══════════════════════════════════════════
# Signal Handlers (from BFTNode)
# ═══════════════════════════════════════════

func _on_message_sent(msg_type: String, target_id: int, value):
	if GameManager.network_state:
		var node = GameManager.network_state.get_node(node_id)
		if node and node.is_crashed():
			return
	
	var val_str = ""
	if value != null:
		val_str = " value=%s" % ("OPEN" if value == Enums.VoteValue.OPEN else "LOCKED")
	add_log("[DEBUG] send %s to=node%d%s" % [msg_type.to_lower(), target_id, val_str])

func _on_message_received(msg_type: String, from_id: int, value):
	if GameManager.network_state:
		var node = GameManager.network_state.get_node(node_id)
		if node and node.is_crashed():
			return
	
	var val_str = ""
	if value != null:
		val_str = " value=%s" % ("OPEN" if value == Enums.VoteValue.OPEN else "LOCKED")
	add_log("[DEBUG] recv %s from=node%d%s" % [msg_type.to_lower(), from_id, val_str])

func _on_state_changed(old_state: Enums.NodeState, new_state: Enums.NodeState):
	var state_names = ["active", "crashed", "compromised"]
	
	if old_state != Enums.NodeState.CRASHED:
		add_log("[ERROR] state transition: %s -> %s" % [state_names[old_state], state_names[new_state]])
	
	update_visuals()

func _on_vote_cast(vote_value: Enums.VoteValue):
	if GameManager.network_state:
		var node = GameManager.network_state.get_node(node_id)
		if node and node.is_crashed():
			return
	
	add_log("[INFO] voting: %s" % ("OPEN" if vote_value == Enums.VoteValue.OPEN else "LOCKED"))

func _on_decision_made(decision: Enums.VoteValue):
	if GameManager.network_state:
		var node = GameManager.network_state.get_node(node_id)
		if node and node.is_crashed():
			return
	
	add_log("[INFO] consensus decision: %s" % ("OPEN" if decision == Enums.VoteValue.OPEN else "LOCKED"))

# ═══════════════════════════════════════════
# Input Handling (for debugging/testing)
# ═══════════════════════════════════════════

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				if Input.is_key_pressed(KEY_0 + node_id) or Input.is_key_pressed(KEY_KP_0 + node_id):
					reboot()
			KEY_C:
				if Input.is_key_pressed(KEY_0 + node_id) or Input.is_key_pressed(KEY_KP_0 + node_id):
					crash()
			KEY_X:
				if Input.is_key_pressed(KEY_0 + node_id) or Input.is_key_pressed(KEY_KP_0 + node_id):
					corrupt()
			KEY_L:
				if Input.is_key_pressed(KEY_0 + node_id) or Input.is_key_pressed(KEY_KP_0 + node_id):
					clear_logs()

func reboot():
	GameManager.player_action(Enums.ActionType.REBOOT_NODE, node_id)
	
func crash():
	GameManager.player_action(Enums.ActionType.CRASH_NODE, node_id)

func corrupt():
	GameManager.player_action(Enums.ActionType.CORRUPT_NODE, node_id)

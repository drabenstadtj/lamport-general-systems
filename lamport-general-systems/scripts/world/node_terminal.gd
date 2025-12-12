extends Node3D
class_name NodeTerminal

@export var node_id: int = 0
@export var max_log_lines: int = 10
@export var camera_offset: Vector3 = Vector3(0, -.1, .25)
@export var look_at_offset: Vector3 = Vector3(0, 0.4, 0)  

@onready var status_light = $StatusLight
@onready var label = $SubViewport/MarginContainer/Label
@onready var interaction_area: Area3D = $InteractionArea
@onready var collision_body: StaticBody3D = $StaticBody3D

var log_entries: Array[String] = []
var player_nearby: bool = false
var is_being_viewed: bool = false

func _ready():
	label.text = "Node %d" % node_id
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

func stop_viewing(player):
	is_being_viewed = false

func get_camera_position() -> Vector3:
	return global_position + global_transform.basis * camera_offset
	
func get_look_at_position() -> Vector3:
	return global_position + global_transform.basis * look_at_offset

# ═══════════════════════════════════════════
# Logging System
# ═══════════════════════════════════════════

func add_log(message: String):
	if GameManager.network_manager:
		var node = GameManager.network_manager.get_node(node_id)
		if node and node.is_crashed():
			return
	
	var time = Time.get_ticks_msec() / 1000.0
	var timestamp = "%6.2f" % time
	log_entries.append("%s %s" % [timestamp, message])
	
	if log_entries.size() > max_log_lines:
		log_entries.pop_front()
	
	update_display()

func clear_logs():
	log_entries.clear()
	update_display()

func update_display():
	if GameManager.network_manager:
		var node = GameManager.network_manager.get_node(node_id)
		if node and node.is_crashed():
			label.text = ("node%d@consensus:~$ tail -f /var/log/bft.log\n[FATAL] Node status: CRASHED\n----------------------------------------\n[FATAL] Connection lost\n[FATAL] Log daemon stopped" % node_id).to_upper()
			return

	var display_text = "node%d@consensus:~$ tail -f /var/log/bft.log\n" % node_id

	if GameManager.network_manager:
		var node = GameManager.network_manager.get_node(node_id)
		if node:
			var state_str = ""
			match node.state:
				Enums.NodeState.HEALTHY:
					state_str = "[INFO] Node status: ACTIVE"
				Enums.NodeState.CRASHED:
					state_str = "[FATAL] Node status: CRASHED"
				Enums.NodeState.BYZANTINE:
					state_str = "[WARN] Node status: COMPROMISED"
			display_text += state_str + "\n"
	
	display_text += "----------------------------------------\n"
	
	if log_entries.is_empty():
		display_text += "[INFO] Awaiting network activity...\n"
	else:
		for entry in log_entries:
			display_text += entry + "\n"
	
	label.text = display_text.to_upper()

func update_visuals():
	if not GameManager.network_manager:
		return

	var node = GameManager.network_manager.get_node(node_id)
	if not node:
		return
	
	match node.state:
		Enums.NodeState.HEALTHY:
			status_light.light_color = Color.GREEN
			status_light.light_energy = 5.0
			label.modulate = Color.WHITE
		
		Enums.NodeState.CRASHED:
			status_light.light_color = Color.BLACK
			status_light.light_energy = 0.0
			label.modulate = Color.DARK_GRAY
			update_display()
		
		Enums.NodeState.BYZANTINE:
			status_light.light_color = Color.RED
			status_light.light_energy = 5.0
			label.modulate = Color(1, 0.5, 0.5)
	
	update_display()

# ═══════════════════════════════════════════
# Signal Handlers (from BFTNode)
# ═══════════════════════════════════════════

func _on_message_sent(msg_type: String, target_id: int, value):
	if GameManager.network_manager:
		var node = GameManager.network_manager.get_node(node_id)
		if node and node.is_crashed():
			return
	
	var val_str = ""
	if value != null:
		val_str = " value=%s" % ("OPEN" if value == Enums.VoteValue.OPEN else "LOCKED")
	add_log("[DEBUG] send %s to=node%d%s" % [msg_type.to_lower(), target_id, val_str])

func _on_message_received(msg_type: String, from_id: int, value):
	if GameManager.network_manager:
		var node = GameManager.network_manager.get_node(node_id)
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
	if GameManager.network_manager:
		var node = GameManager.network_manager.get_node(node_id)
		if node and node.is_crashed():
			return
	
	add_log("[INFO] voting: %s" % ("OPEN" if vote_value == Enums.VoteValue.OPEN else "LOCKED"))

func _on_decision_made(decision: Enums.VoteValue):
	if GameManager.network_manager:
		var node = GameManager.network_manager.get_node(node_id)
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

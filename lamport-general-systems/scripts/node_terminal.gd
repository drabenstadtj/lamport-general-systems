extends Node
class_name NodeTerminal

signal state_changed(new_state)
signal log_added(message)

@export var node_id: int = 0
@export var max_log_lines: int = 10

var log_entries: Array[String] = []
var current_state: Enums.NodeState = Enums.NodeState.HEALTHY

func _ready():
	GameManager.register_node_terminal(node_id, self)

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
	
	log_entries.append(log_message)
	if log_entries.size() > max_log_lines:
		log_entries.pop_front()
	
	log_added.emit(log_message)

func clear_logs():
	log_entries.clear()

func update_state():
	if not GameManager.network_state:
		return

	var node = GameManager.network_state.get_node(node_id)
	if not node:
		return

	var new_state = node.state
	if new_state != current_state:
		current_state = new_state
		state_changed.emit(new_state)

func update_visuals():
	"""Called by BFTNode when state changes. Triggers state_changed signal for connected visual components."""
	update_state()

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
	
	update_state()

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
# Action Functions
# ═══════════════════════════════════════════

func reboot():
	GameManager.player_action(Enums.ActionType.REBOOT_NODE, node_id)
	
func crash():
	GameManager.player_action(Enums.ActionType.CRASH_NODE, node_id)

func corrupt():
	GameManager.player_action(Enums.ActionType.CORRUPT_NODE, node_id)

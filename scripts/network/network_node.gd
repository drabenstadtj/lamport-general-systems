extends RefCounted
class_name NetworkNode

# Signals for observing node behavior
signal message_sent(msg_type: String, target_id: int, value)
signal message_received(msg_type: String, from_id: int, value)
signal state_changed(old_state: Enums.NodeState, new_state: Enums.NodeState)
signal vote_cast(vote_value: Enums.VoteValue)
signal decision_made(decision: Enums.VoteValue)

var id: int
var state: Enums.NodeState
var filesystem: Dictionary = {}

# Message interception/spoofing
var spoofed_messages: Dictionary = {}  # {target_id: VoteValue} - override value sent to specific targets
var intercept_mode: bool = false  # When true, log extra info about messages

func _init(node_id: int, initial_state = Enums.NodeState.HEALTHY):
	id = node_id
	state = initial_state
	_init_filesystem()

func _init_filesystem():
	# Create default filesystem structure for this node
	filesystem = {
		"type": "dir",
		"children": {
			"home": {
				"type": "dir",
				"children": {
					"user": {
						"type": "dir",
						"children": {
							"logs": {
								"type": "dir",
								"children": {
									"consensus.log": {
										"type": "file",
										"content": "",
										"read_only": false
									},
									"messages.log": {
										"type": "file",
										"content": "",
										"read_only": false
									}
								}
							}
						}
					}
				}
			}
		}
	}

func append_to_log(log_name: String, line: String) -> bool:
	# Helper to append to logs/consensus.log or logs/messages.log
	var logs_dir = filesystem["children"]["home"]["children"]["user"]["children"]["logs"]["children"]
	var log_file = log_name + ".log"
	if logs_dir.has(log_file):
		var node = logs_dir[log_file]
		if node["content"] != "" and not node["content"].ends_with("\n"):
			node["content"] += "\n"
		node["content"] += line + "\n"
		return true
	return false

# State Queries

func is_healthy() -> bool:
	return state == Enums.NodeState.HEALTHY

func is_crashed() -> bool:
	return state == Enums.NodeState.CRASHED

func is_byzantine() -> bool:
	return state == Enums.NodeState.BYZANTINE

func is_powered_down() -> bool:
	return state == Enums.NodeState.POWERED_DOWN

func is_operational() -> bool:
	return state == Enums.NodeState.HEALTHY or state == Enums.NodeState.BYZANTINE

func is_offline() -> bool:
	return state == Enums.NodeState.POWERED_DOWN or state == Enums.NodeState.CRASHED

# State Modification

func set_state(new_state: Enums.NodeState):
	if state == new_state:
		return  # No change
	
	var old_state = state
	state = new_state
	
	# Emit signal so anything listening can react
	state_changed.emit(old_state, new_state)

# Message/Vote Logging (for consensus visualization)

func log_send(msg_type: String, target_id: int, value = null):
	var value_str = _vote_str(value) if value != null else ""
	append_to_log("messages", "[TX] %s -> Node %d : %s" % [msg_type, target_id, value_str])
	message_sent.emit(msg_type, target_id, value)

func log_receive(msg_type: String, from_id: int, value = null):
	var value_str = _vote_str(value) if value != null else ""
	append_to_log("messages", "[RX] %s <- Node %d : %s" % [msg_type, from_id, value_str])
	message_received.emit(msg_type, from_id, value)

func log_vote(vote_value: Enums.VoteValue):
	append_to_log("consensus", "[VOTE] Cast: %s" % _vote_str(vote_value))
	vote_cast.emit(vote_value)

func log_decision(decision: Enums.VoteValue):
	append_to_log("consensus", "[DECISION] Local decision: %s" % _vote_str(decision))
	decision_made.emit(decision)

func log_blocked(msg_type: String, from_id: int):
	append_to_log("messages", "[BLOCKED] %s from Node %d was blocked!" % [msg_type, from_id])

func log_consensus_start(proposal: Enums.VoteValue):
	append_to_log("consensus", "--- CONSENSUS ROUND STARTED ---")
	append_to_log("consensus", "[PROPOSAL] Commander proposes: %s" % _vote_str(proposal))

func log_consensus_end(success: bool, result_value, confidence: float, reason: String = ""):
	append_to_log("consensus", "--- CONSENSUS ROUND ENDED ---")
	if success:
		append_to_log("consensus", "[RESULT] SUCCESS: %s (%.0f%% confidence)" % [_vote_str(result_value), confidence * 100])
	else:
		append_to_log("consensus", "[RESULT] FAILED: %s" % reason)

func log_state_change(new_state: Enums.NodeState):
	var state_name = Enums.NodeState.keys()[new_state]
	append_to_log("consensus", "[STATE] Changed to: %s" % state_name)

func _vote_str(value) -> String:
	if value == Enums.VoteValue.OPEN:
		return "OPEN"
	return "LOCKED"

# Message Spoofing/Interception

func set_spoof(target_id: int, value: Enums.VoteValue):
	spoofed_messages[target_id] = value
	append_to_log("messages", "[SPOOF] Set override for Node %d -> %s" % [target_id, _vote_str(value)])

func clear_spoof(target_id: int):
	if spoofed_messages.has(target_id):
		spoofed_messages.erase(target_id)
		append_to_log("messages", "[SPOOF] Cleared override for Node %d" % target_id)

func clear_all_spoofs():
	spoofed_messages.clear()
	append_to_log("messages", "[SPOOF] Cleared all overrides")

func get_spoofed_value(target_id: int, original_value: Enums.VoteValue) -> Enums.VoteValue:
	if spoofed_messages.has(target_id):
		var spoofed = spoofed_messages[target_id]
		append_to_log("messages", "[SPOOF] Sending %s to Node %d (original: %s)" % [_vote_str(spoofed), target_id, _vote_str(original_value)])
		return spoofed
	return original_value

func has_spoof_for(target_id: int) -> bool:
	return spoofed_messages.has(target_id)

func get_all_spoofs() -> Dictionary:
	return spoofed_messages.duplicate()

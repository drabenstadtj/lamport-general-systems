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

func _init(node_id: int, initial_state = Enums.NodeState.HEALTHY):
	id = node_id
	state = initial_state

# State Queries

func is_healthy() -> bool:
	return state == Enums.NodeState.HEALTHY

func is_crashed() -> bool:
	return state == Enums.NodeState.CRASHED

func is_byzantine() -> bool:
	return state == Enums.NodeState.BYZANTINE

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
	message_sent.emit(msg_type, target_id, value)

func log_receive(msg_type: String, from_id: int, value = null):
	message_received.emit(msg_type, from_id, value)

func log_vote(vote_value: Enums.VoteValue):
	vote_cast.emit(vote_value)

func log_decision(decision: Enums.VoteValue):
	decision_made.emit(decision)

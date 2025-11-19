extends RefCounted
class_name BFTNode

signal message_sent(msg_type: String, target_id: int, value)
signal message_received(msg_type: String, from_id: int, value)
signal state_changed(old_state: Enums.NodeState, new_state: Enums.NodeState)
signal vote_cast(vote_value: Enums.VoteValue)
signal decision_made(decision: Enums.VoteValue)

var id: int
var state: Enums.NodeState
var game_object = null  # Reference to NodeTerminal in 3D world

func _init(node_id: int, initial_state = Enums.NodeState.HEALTHY):
	id = node_id
	state = initial_state

func is_healthy() -> bool:
	return state == Enums.NodeState.HEALTHY

func is_crashed() -> bool:
	return state == Enums.NodeState.CRASHED

func is_byzantine() -> bool:
	return state == Enums.NodeState.BYZANTINE

func set_state(new_state: Enums.NodeState):
	print("BFTNode %d: set_state called, changing from %s to %s" % [id, state, new_state])
	var old_state = state
	state = new_state
	
	# Emit state change signal
	state_changed.emit(old_state, new_state)
	
	print("BFTNode %d: game_object is: %s" % [id, game_object])
	if game_object:
		print("BFTNode %d: calling game_object.update_visuals()" % id)
		game_object.update_visuals()
	else:
		print("BFTNode %d: game_object is null, can't update visuals!" % id)

func link_game_object(obj):
	game_object = obj
	# Connect signals to the terminal if it has the right methods
	if obj.has_method("_on_message_sent"):
		message_sent.connect(obj._on_message_sent)
	if obj.has_method("_on_message_received"):
		message_received.connect(obj._on_message_received)
	if obj.has_method("_on_state_changed"):
		state_changed.connect(obj._on_state_changed)
	if obj.has_method("_on_vote_cast"):
		vote_cast.connect(obj._on_vote_cast)
	if obj.has_method("_on_decision_made"):
		decision_made.connect(obj._on_decision_made)

# Helper methods to emit signals
func log_send(msg_type: String, target_id: int, value = null):
	message_sent.emit(msg_type, target_id, value)

func log_receive(msg_type: String, from_id: int, value = null):
	message_received.emit(msg_type, from_id, value)

func log_vote(vote_value: Enums.VoteValue):
	vote_cast.emit(vote_value)

func log_decision(decision: Enums.VoteValue):
	decision_made.emit(decision)

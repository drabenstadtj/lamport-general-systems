extends RefCounted
class_name BFTNodeAgent

# ===== SIGNALS =====
signal message_sent(msg: BFTMessage)
signal consensus_reached(value: Enums.VoteValue)
signal state_changed(old_state: Enums.NodeState, new_state: Enums.NodeState)
signal vote_cast(vote_value: Enums.VoteValue)
signal decision_made(decision: Enums.VoteValue)

# ===== NODE PROPERTIES =====
var id: int
var state: Enums.NodeState
var f: int  # Fault tolerance parameter
var game_object = null  # Reference to NodeTerminal in 3D world

# ===== MESSAGE INBOXES (per round) =====
var received_pre_prepares: Array[BFTMessage] = []
var received_prepares: Array[BFTMessage] = []
var received_commits: Array[BFTMessage] = []

# ===== ROUND STATE =====
var current_round: int = 0
var my_prepare_value = null  # Enums.VoteValue or null
var my_commit_value = null  # Enums.VoteValue or null
var has_sent_prepare: bool = false
var has_sent_commit: bool = false
var final_decision = null  # Enums.VoteValue or null

# ===== INITIALIZATION =====
func _init(node_id: int, fault_tolerance: int):
	id = node_id
	f = fault_tolerance
	state = Enums.NodeState.HEALTHY

# ===== STATE CHECKS =====
func is_healthy() -> bool:
	return state == Enums.NodeState.HEALTHY

func is_crashed() -> bool:
	return state == Enums.NodeState.CRASHED

func is_byzantine() -> bool:
	return state == Enums.NodeState.BYZANTINE

func set_state(new_state: Enums.NodeState):
	if state == new_state:
		return

	var old_state = state
	state = new_state
	state_changed.emit(old_state, new_state)

	if game_object and game_object.has_method("update_visuals"):
		game_object.update_visuals()

func link_game_object(obj):
	game_object = obj

# ===== PHASE 1: RECEIVE PRE-PREPARE (from commander) =====
func receive_pre_prepare(msg: BFTMessage):
	if is_crashed():
		return

	# Store the pre-prepare message
	received_pre_prepares.append(msg)

	# Log to terminal
	if game_object and game_object.has_method("add_log"):
		var value_str = "OPEN" if msg.proposed_value == Enums.VoteValue.OPEN else "LOCKED"
		game_object.add_log("← PRE-PREP: %s from Node %d" % [value_str, msg.sender_id])

	# Defer PREPARE broadcast to avoid message ordering issues
	# (Let all PRE-PREPARE messages be delivered first)
	if not has_sent_prepare:
		var prepare_value = msg.proposed_value

		# Byzantine nodes might lie
		if is_byzantine():
			prepare_value = _apply_byzantine_behavior(prepare_value)

		my_prepare_value = prepare_value
		has_sent_prepare = true

		# Defer the broadcast to next frame
		call_deferred("_send_prepare_deferred", prepare_value)

# ===== PHASE 2: RECEIVE PREPARE (from other nodes) =====
func receive_prepare(msg: BFTMessage):
	if is_crashed():
		return

	# Store the prepare message
	received_prepares.append(msg)

	# Log to terminal
	if game_object and game_object.has_method("add_log"):
		var value_str = "OPEN" if msg.proposed_value == Enums.VoteValue.OPEN else "LOCKED"
		game_object.add_log("← PREPARE: %s from Node %d" % [value_str, msg.sender_id])

	# Check if I have 2f+1 PREPARE messages for the same value
	if has_sent_commit:
		return  # Already committed

	var quorum = 2 * f + 1
	var counts = _count_unique_senders(received_prepares)

	# Do I see a quorum for any value?
	for value in counts.keys():
		if counts[value] >= quorum:
			# I can commit to this value!
			var commit_value = value

			# Byzantine nodes might commit to wrong value anyway
			if is_byzantine():
				commit_value = _apply_byzantine_behavior(commit_value)

			my_commit_value = commit_value
			has_sent_commit = true

			var commit_msg = BFTMessage.new(
				BFTMessage.MessageType.COMMIT,
				id,
				-1,  # broadcast
				commit_value,
				current_round
			)

			# Count my own commit
			received_commits.append(commit_msg)

			# Log outgoing message
			if game_object and game_object.has_method("add_log"):
				var value_str = "OPEN" if commit_value == Enums.VoteValue.OPEN else "LOCKED"
				game_object.add_log("→ COMMIT: %s (broadcast)" % value_str)

			decision_made.emit(commit_value)
			message_sent.emit(commit_msg)

			# Check if consensus reached immediately after sending commit
			_check_for_consensus()
			break

# ===== DEFERRED MESSAGE SENDING =====
func _send_prepare_deferred(prepare_value):
	var prepare_msg = BFTMessage.new(
		BFTMessage.MessageType.PREPARE,
		id,
		-1,  # broadcast to all
		prepare_value,
		current_round
	)

	# Count my own prepare message
	received_prepares.append(prepare_msg)

	# Log outgoing message
	if game_object and game_object.has_method("add_log"):
		var value_str = "OPEN" if prepare_value == Enums.VoteValue.OPEN else "LOCKED"
		game_object.add_log("→ PREPARE: %s (broadcast)" % value_str)

	vote_cast.emit(prepare_value)
	message_sent.emit(prepare_msg)

# ===== HELPER: CHECK FOR CONSENSUS =====
func _check_for_consensus():
	# Check if I see 2f+1 COMMIT messages for any value
	if final_decision != null:
		return  # Already decided

	var quorum = 2 * f + 1
	var counts = _count_unique_senders(received_commits)

	# Do I see a quorum for any value?
	for value in counts.keys():
		if counts[value] >= quorum:
			# Consensus reached!
			final_decision = value

			# Log final decision
			if game_object and game_object.has_method("add_log"):
				var value_str = "OPEN" if value == Enums.VoteValue.OPEN else "LOCKED"
				game_object.add_log("✓ DECIDED: %s" % value_str)

			consensus_reached.emit(value)
			return

# ===== PHASE 3: RECEIVE COMMIT (from other nodes) =====
func receive_commit(msg: BFTMessage):
	if is_crashed():
		return

	# Store the commit message
	received_commits.append(msg)

	# Log to terminal
	if game_object and game_object.has_method("add_log"):
		var value_str = "OPEN" if msg.proposed_value == Enums.VoteValue.OPEN else "LOCKED"
		game_object.add_log("← COMMIT: %s from Node %d" % [value_str, msg.sender_id])

	# Check for consensus after receiving this commit
	_check_for_consensus()

# ===== BYZANTINE BEHAVIOR =====
func _apply_byzantine_behavior(value: Enums.VoteValue) -> Enums.VoteValue:
	# Byzantine nodes flip the value (deterministic)
	return Enums.VoteValue.LOCKED if value == Enums.VoteValue.OPEN else Enums.VoteValue.OPEN

# ===== HELPER: COUNT UNIQUE SENDERS =====
func _count_unique_senders(messages: Array[BFTMessage]) -> Dictionary:
	var counts = {
		Enums.VoteValue.OPEN: 0,
		Enums.VoteValue.LOCKED: 0
	}
	var seen_senders: Dictionary = {}

	for msg in messages:
		# Only count one message per sender per value
		var key = "%d_%d" % [msg.sender_id, msg.proposed_value]
		if not seen_senders.has(key):
			seen_senders[key] = true
			counts[msg.proposed_value] += 1

	return counts

# ===== ROUND MANAGEMENT =====
func reset_for_new_round():
	received_pre_prepares.clear()
	received_prepares.clear()
	received_commits.clear()
	my_prepare_value = null
	my_commit_value = null
	has_sent_prepare = false
	has_sent_commit = false
	final_decision = null
	current_round += 1

func get_decision():  # Returns Enums.VoteValue or null
	return final_decision

func has_decided() -> bool:
	return final_decision != null

# ===== COMMANDER BEHAVIOR =====
# Called when this node is the commander
func broadcast_proposal_as_commander(proposal: Enums.VoteValue, all_nodes: Array):
	if is_crashed():
		return

	if game_object and game_object.has_method("add_log"):
		var value_str = "OPEN" if proposal == Enums.VoteValue.OPEN else "LOCKED"
		game_object.add_log("→ PROPOSING: %s" % value_str)

	# Byzantine commander can send different values to different nodes
	for node in all_nodes:
		if node.id == id:
			continue  # Don't send to self

		if node.is_crashed():
			continue  # Don't send to crashed nodes

		# Byzantine commander might send different values to different nodes
		var sent_value = proposal
		if is_byzantine():
			# Randomly flip for each recipient
			if randf() > 0.5:
				sent_value = _apply_byzantine_behavior(proposal)

		var msg = BFTMessage.new(
			BFTMessage.MessageType.PRE_PREPARE,
			id,
			node.id,
			sent_value,
			current_round
		)

		# Emit the message - NetworkManager will route it
		message_sent.emit(msg)

	# Commander also participates in PREPARE phase
	if not has_sent_prepare:
		var prepare_value = proposal
		if is_byzantine():
			prepare_value = _apply_byzantine_behavior(prepare_value)

		my_prepare_value = prepare_value
		has_sent_prepare = true
		call_deferred("_send_prepare_deferred", prepare_value)

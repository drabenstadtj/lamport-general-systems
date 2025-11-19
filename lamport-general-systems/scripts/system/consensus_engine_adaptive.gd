extends RefCounted
class_name ConsensusEngineAdaptive

var network_state: NetworkState
var failed_rounds_count: int = 0
var failsafe_threshold: int = 10
var failsafe_active: bool = false
var current_door_state: Enums.VoteValue = Enums.VoteValue.LOCKED
var current_round: int = 0

# Adaptive thresholds per attempt (round -> confidence)
const THRESHOLDS := {
	1: 0.80, # OM(0)
	2: 0.75, # OM(1)
	3: 0.70, # OM(2)
	4: 0.65  # OM(3)
}
const MAX_ROUNDS := 4

# Message storage (for UI/logging)
var pre_prepare_messages: Array[BFTMessage] = []
var prepare_messages: Array[BFTMessage] = []
var commit_messages: Array[BFTMessage] = []

func _init(net_state: NetworkState):
	network_state = net_state

func run_consensus_round(commander_proposal: Enums.VoteValue, verbose := true) -> Dictionary:
	if verbose:
		print("\n=== ADAPTIVE CONSENSUS ROUND %d ===" % current_round)

	# reset storage
	pre_prepare_messages.clear()
	prepare_messages.clear()
	commit_messages.clear()

	# pre-checks
	var healthy_count := network_state.count_healthy_nodes()
	var required := 2 * network_state.f + 1
	if healthy_count < required:
		if verbose:
			print("FAILED: Insufficient healthy nodes (%d < %d)" % [healthy_count, required])
		_increment_fail("Insufficient healthy nodes")
		return {
			"success": false,
			"reason": "Insufficient healthy nodes",
			"phase_reached": "pre-check"
		}

	var commander = network_state.get_commander()
	if not commander.is_healthy():
		if verbose:
			print("FAILED: Commander (Node 0) is not healthy")
		_increment_fail("Commander not healthy")
		return {
			"success": false,
			"reason": "Commander is not healthy",
			"phase_reached": "pre-check"
		}

	# attempts 1..MAX_ROUNDS with increasing OM depth and decreasing threshold
	var attempts: Array = []
	var n_nodes := network_state.nodes.size()
	if verbose:
		print("Nodes: %d | f=%d" % [n_nodes, network_state.f])
		print("Command: %s" % (_vstr(commander_proposal)))

	for attempt_round in range(1, MAX_ROUNDS + 1):
		var m := attempt_round - 1 # OM(m)
		if verbose:
			print("\n--- Attempt %d: OM(%d) ---" % [attempt_round, m])

		# Execute OM(m) and collect reported votes per node
		var reported_votes: Dictionary = _execute_om(commander_proposal, m, verbose)

		# Convert to counts and confidence
		var conf_info := _calculate_confidence(reported_votes)
		var threshold: float = THRESHOLDS[attempt_round]

		var attempt_summary := {
			"round": attempt_round,
			"protocol": "OM(%d)" % m,
			"votes": conf_info.votes,                  # {OPEN: count, LOCKED: count}
			"confidence": conf_info.confidence,        # 0..1
			"threshold": threshold,                    # 0..1
			"consensus_value": conf_info.majority      # Enums.VoteValue or null
		}
		attempts.append(attempt_summary)

		if verbose:
			_display_attempt(attempt_summary)

		# Success: majority matches command and passes threshold
		if conf_info.majority == commander_proposal and conf_info.confidence >= threshold:
			if verbose:
				print("✓ CONSENSUS ACHIEVED in Attempt %d (OM(%d)) | Confidence=%.1f%%"
					% [attempt_round, m, conf_info.confidence * 100.0])
			current_door_state = commander_proposal
			failed_rounds_count = 0
			current_round += 1
			return {
				"success": true,
				"agreed_value": commander_proposal,
				"consensus": commander_proposal,
				"rounds_used": attempt_round,
				"confidence": conf_info.confidence,
				"attempts": attempts,
				"door_status": commander_proposal,
				"phase_reached": "complete",
				"pre_prepare_count": pre_prepare_messages.size(),
				"prepare_count": prepare_messages.size(),
				"commit_count": commit_messages.size()
			}

		# Early fail: strong consensus on the wrong value
		if conf_info.majority != null and conf_info.majority != commander_proposal and conf_info.confidence >= 0.70:
			if verbose:
				print("✗ STRONG CONSENSUS ON WRONG VALUE: network chose %s (≥70%% confidence)"
					% _vstr(conf_info.majority))
			_increment_fail("Byzantine nodes preventing correct consensus")
			return {
				"success": false,
				"consensus": conf_info.majority,
				"rounds_used": attempt_round,
				"confidence": conf_info.confidence,
				"attempts": attempts,
				"door_status": Enums.VoteValue.LOCKED,
				"reason": "Byzantine nodes preventing correct consensus",
				"phase_reached": "complete",
				"pre_prepare_count": pre_prepare_messages.size(),
				"prepare_count": prepare_messages.size(),
				"commit_count": commit_messages.size()
			}

		# Else escalate to next OM depth

	# All attempts failed
	if verbose:
		print("\n✗ CONSENSUS FAILED after OM(%d). Confidence insufficient." % (MAX_ROUNDS - 1))
	_increment_fail("Unable to reach confident consensus")
	return {
		"success": false,
		"consensus": null,
		"rounds_used": MAX_ROUNDS,
		"confidence": 0.0,
		"attempts": attempts,
		"door_status": Enums.VoteValue.LOCKED,
		"reason": "Unable to reach confident consensus",
		"phase_reached": "complete",
		"pre_prepare_count": pre_prepare_messages.size(),
		"prepare_count": prepare_messages.size(),
		"commit_count": commit_messages.size()
	}

# ------------------------
# OM(m) execution
# ------------------------

# In ConsensusEngineAdaptive, update _execute_om to log messages:

func _execute_om(command_value: Enums.VoteValue, m: int, verbose: bool) -> Dictionary:
	pre_prepare_messages.clear()
	prepare_messages.clear()
	commit_messages.clear()

	# Phase: PRE-PREPARE (commander -> all non-crashed)
	var commander = network_state.get_commander()
	if verbose:
		print("Phase PRE-PREPARE: commander broadcasts %s" % _vstr(command_value))
	
	for node in network_state.nodes:
		if node.is_crashed():
			continue
		var received := command_value
		var msg = BFTMessage.new(BFTMessage.MessageType.PRE_PREPARE, commander.id, node.id, received, current_round)
		pre_prepare_messages.append(msg)
		
		# Log the message exchange
		commander.log_send("PRE-PREP", node.id, received)
		node.log_receive("PRE-PREP", commander.id, received)

	# Relay rounds (m times)
	for r in range(m):
		_relay_round(verbose)

	# Local decisions per node
	var reported: Dictionary = {}
	for node in network_state.nodes:
		if node.is_crashed():
			continue
		var decision = _node_decision(node.id)
		if decision == null:
			continue
		
		# Log the decision
		node.log_decision(decision)
		
		var report = decision
		if node.is_byzantine():
			report = Enums.VoteValue.LOCKED if decision == Enums.VoteValue.OPEN else Enums.VoteValue.OPEN
		
		# Log the vote cast
		node.log_vote(report)
		reported[node.id] = report

	# For UI parity, synthesize COMMIT messages
	for sender_id in reported.keys():
		var v: Enums.VoteValue = reported[sender_id]
		var sender = network_state.get_node(sender_id)
		for receiver in network_state.nodes:
			if receiver.is_crashed():
				continue
			commit_messages.append(BFTMessage.new(BFTMessage.MessageType.COMMIT, sender_id, receiver.id, v, current_round))
			
			# Log commit messages
			sender.log_send("COMMIT", receiver.id, v)
			receiver.log_receive("COMMIT", sender_id, v)

	return reported

func _relay_round(verbose: bool) -> void:
	var to_send: Dictionary = {}
	for node in network_state.nodes:
		if node.is_crashed():
			continue
		var received = _get_pre_prepare_value_for_node(node.id)
		if received == null:
			continue
		var out_val = received
		if node.is_byzantine():
			out_val = Enums.VoteValue.LOCKED if received == Enums.VoteValue.OPEN else Enums.VoteValue.OPEN
		to_send[node.id] = out_val

	# Deliver broadcasts
	for sender_id in to_send.keys():
		var sender = network_state.get_node(sender_id)
		for recv in network_state.nodes:
			if recv.is_crashed():
				continue
			if recv.id == sender_id:
				continue
			var v: Enums.VoteValue = to_send[sender_id]
			prepare_messages.append(BFTMessage.new(BFTMessage.MessageType.PREPARE, sender_id, recv.id, v, current_round))
			
			# Log prepare messages
			sender.log_send("PREPARE", recv.id, v)
			recv.log_receive("PREPARE", sender_id, v)

	if verbose:
		var open_count := 0
		var lock_count := 0
		for m in prepare_messages:
			if m.proposed_value == Enums.VoteValue.OPEN:
				open_count += 1
			elif m.proposed_value == Enums.VoteValue.LOCKED:
				lock_count += 1
		print("  Relay total PREPARE so far: OPEN=%d LOCKED=%d" % [open_count, lock_count])

func _node_decision(node_id: int):
	# Build unique-sender view: commander msg + one per unique sender
	var open_c := 0
	var lock_c := 0

	# commander to this node
	var c_val = _get_pre_prepare_value_for_node(node_id)
	if c_val != null:
		if c_val == Enums.VoteValue.OPEN: open_c += 1
		else: lock_c += 1

	# unique senders
	var seen: Dictionary = {}
	for msg in prepare_messages:
		if msg.receiver_id != node_id:
			continue
		if seen.has(msg.sender_id):
			continue
		seen[msg.sender_id] = true
		if msg.proposed_value == Enums.VoteValue.OPEN:
			open_c += 1
		else:
			lock_c += 1

	# tie-break to LOCKED
	if open_c > lock_c:
		return Enums.VoteValue.OPEN
	elif lock_c >= open_c:
		return Enums.VoteValue.LOCKED
	return null

func _get_pre_prepare_value_for_node(node_id: int):
	for msg in pre_prepare_messages:
		if msg.receiver_id == node_id:
			return msg.proposed_value
	return null

# ------------------------
# Confidence and reporting
# ------------------------

func _calculate_confidence(reported_votes: Dictionary) -> Dictionary:
	# reported_votes: {node_id: VoteValue}
	var counts := {
		Enums.VoteValue.OPEN: 0,
		Enums.VoteValue.LOCKED: 0
	}
	var total := 0
	for node_id in reported_votes.keys():
		var v: Enums.VoteValue = reported_votes[node_id]
		counts[v] += 1
		total += 1

	var majority = null  # Will be Enums.VoteValue or null
	var max_count := 0
	for v in counts.keys():
		if counts[v] > max_count:
			max_count = counts[v]
			majority = v

	var confidence := 0.0
	if total > 0:
		confidence = float(max_count) / float(total)

	return {
		"votes": counts,
		"majority": majority,
		"confidence": confidence
	}

func _display_attempt(attempt: Dictionary) -> void:
	var votes: Dictionary = attempt["votes"]
	print("  Protocol: %s" % attempt["protocol"])
	print("  Votes: OPEN=%d LOCKED=%d" % [votes[Enums.VoteValue.OPEN], votes[Enums.VoteValue.LOCKED]])
	print("  Confidence: %.1f%% | Threshold: %.1f%%"
		% [attempt["confidence"] * 100.0, attempt["threshold"] * 100.0])
	if attempt["consensus_value"] != null:
		print("  Majority: %s" % _vstr(attempt["consensus_value"]))

# ------------------------
# Failsafe and helpers
# ------------------------

func _increment_fail(reason: String) -> void:
	failed_rounds_count += 1
	check_failsafe()
	if failsafe_active:
		print("Failsafe active | reason: %s" % reason)

func check_failsafe():
	if failed_rounds_count >= failsafe_threshold:
		trigger_failsafe()

func trigger_failsafe():
	failsafe_active = true
	print("\n🚨 FAILSAFE ACTIVATED - Manual override enabled")

func _vstr(v: Enums.VoteValue) -> String:
	return "OPEN" if v == Enums.VoteValue.OPEN else "LOCKED"

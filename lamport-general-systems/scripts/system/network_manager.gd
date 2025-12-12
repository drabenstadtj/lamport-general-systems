extends RefCounted
class_name NetworkManager

# ===== SIGNALS =====
signal consensus_achieved(value: Enums.VoteValue)
signal consensus_failed(reason: String)
signal round_started(round_number: int)
signal round_completed(result: Dictionary)

# ===== NETWORK STATE =====
var nodes: Array[BFTNodeAgent] = []
var f: int  # Fault tolerance parameter
var current_round: int = 0

# ===== FAILSAFE TRACKING =====
var failed_rounds_count: int = 0
var failsafe_threshold: int = 10
var failsafe_active: bool = false
var current_door_state: Enums.VoteValue = Enums.VoteValue.LOCKED

# ===== SECURITY LEVELS =====
var current_level: Enums.SecurityLevel = Enums.SecurityLevel.MAINTENANCE
var security_lockdown: bool = false
var defense_timer: int = 0

# ===== INITIALIZATION =====
func _init(fault_tolerance: int):
	f = fault_tolerance
	var n = 3 * f + 1  # Total nodes needed for f fault tolerance

	print("NetworkManager: Creating %d nodes with f=%d" % [n, f])

	for i in range(n):
		var node = BFTNodeAgent.new(i, f)
		node.message_sent.connect(_on_node_sent_message)
		node.consensus_reached.connect(_on_node_consensus)
		nodes.append(node)

# ===== NODE ACCESS =====
func get_node(node_id: int) -> BFTNodeAgent:
	if node_id >= 0 and node_id < nodes.size():
		return nodes[node_id]
	return null

func get_commander() -> BFTNodeAgent:
	return nodes[0]

func count_healthy_nodes() -> int:
	var count = 0
	for node in nodes:
		if node.is_healthy():
			count += 1
	return count

# ===== MESSAGE ROUTING =====
func _on_node_sent_message(msg: BFTMessage):
	# Route the message to all appropriate recipients
	if msg.receiver_id == -1:
		# Broadcast to all nodes except sender
		for node in nodes:
			if node.id == msg.sender_id:
				continue
			_deliver_message(node, msg)
	else:
		# Send to specific node
		var receiver = get_node(msg.receiver_id)
		if receiver:
			_deliver_message(receiver, msg)

func _deliver_message(receiver: BFTNodeAgent, msg: BFTMessage):
	# Could add network simulation here (delays, drops, reordering)
	# For now, deliver immediately

	match msg.type:
		BFTMessage.MessageType.PRE_PREPARE:
			receiver.receive_pre_prepare(msg)
		BFTMessage.MessageType.PREPARE:
			receiver.receive_prepare(msg)
		BFTMessage.MessageType.COMMIT:
			receiver.receive_commit(msg)

# ===== CONSENSUS TRACKING =====
var consensus_votes: Dictionary = {}

func _on_node_consensus(value: Enums.VoteValue):
	# Track how many nodes have reached consensus
	if not consensus_votes.has(value):
		consensus_votes[value] = 0
	consensus_votes[value] += 1

	# Check if we have global consensus (2f+1 nodes agree)
	var quorum = 2 * f + 1
	if consensus_votes[value] >= quorum:
		print("NetworkManager: GLOBAL CONSENSUS REACHED: %s" % ("OPEN" if value == Enums.VoteValue.OPEN else "LOCKED"))
		current_door_state = value
		failed_rounds_count = 0
		consensus_achieved.emit(value)

# ===== START CONSENSUS ROUND =====
func run_consensus_round(proposal: Enums.VoteValue) -> Dictionary:
	print("\n=== NetworkManager: CONSENSUS ROUND %d ===" % current_round)
	print("Proposal: %s" % ("OPEN" if proposal == Enums.VoteValue.OPEN else "LOCKED"))

	# Reset all nodes for new round
	for node in nodes:
		node.reset_for_new_round()

	consensus_votes.clear()
	round_started.emit(current_round)

	# Pre-flight checks
	var healthy_count = count_healthy_nodes()
	var required = 2 * f + 1

	if healthy_count < required:
		print("FAILED: Insufficient healthy nodes (%d < %d)" % [healthy_count, required])
		_increment_fail("Insufficient healthy nodes")
		return {
			"success": false,
			"reason": "Insufficient healthy nodes",
			"phase_reached": "pre-check",
			"healthy_count": healthy_count,
			"required": required
		}

	var commander = get_commander()
	if not commander.is_healthy():
		print("FAILED: Commander (Node 0) is not healthy")
		_increment_fail("Commander not healthy")
		return {
			"success": false,
			"reason": "Commander is not healthy",
			"phase_reached": "pre-check"
		}

	# Commander initiates by broadcasting PRE-PREPARE
	print("\n--- Phase 1: PRE-PREPARE ---")
	commander.broadcast_proposal_as_commander(proposal, nodes)

	# The rest happens automatically via message passing!
	# Nodes will:
	# 1. Receive PRE-PREPARE and send PREPARE
	# 2. Receive enough PREPAREs and send COMMIT
	# 3. Receive enough COMMITs and emit consensus_reached

	print("\n--- Phases 2 & 3: PREPARE and COMMIT (autonomous) ---")
	print("Nodes are making decisions independently...")

	# Wait for deferred PREPARE messages to be sent (frame 1)
	await Engine.get_main_loop().process_frame
	print("DEBUG: After frame 1 - checking node states...")
	for node in nodes:
		print("  Node %d: sent_prepare=%s, sent_commit=%s, decided=%s" % [node.id, node.has_sent_prepare, node.has_sent_commit, node.has_decided()])

	# Wait for COMMIT messages to be processed (frame 2)
	await Engine.get_main_loop().process_frame
	print("DEBUG: After frame 2 - checking node states...")
	for node in nodes:
		print("  Node %d: sent_prepare=%s, sent_commit=%s, decided=%s, prepares=%d, commits=%d" % [node.id, node.has_sent_prepare, node.has_sent_commit, node.has_decided(), node.received_prepares.size(), node.received_commits.size()])

	var result = _check_consensus_result(proposal)
	current_round += 1
	round_completed.emit(result)
	return result

# Helper to check if consensus was reached
func _check_consensus_result(proposal: Enums.VoteValue) -> Dictionary:
	var decided_nodes = 0
	var decisions = {
		Enums.VoteValue.OPEN: 0,
		Enums.VoteValue.LOCKED: 0
	}

	for node in nodes:
		if node.is_crashed():
			continue

		if node.has_decided():
			decided_nodes += 1
			var decision = node.get_decision()
			decisions[decision] += 1

	print("\nConsensus Results:")
	print("  Nodes decided: %d" % decided_nodes)
	print("  Decided OPEN: %d" % decisions[Enums.VoteValue.OPEN])
	print("  Decided LOCKED: %d" % decisions[Enums.VoteValue.LOCKED])

	var quorum = 2 * f + 1

	# Check if we have consensus
	if decisions[Enums.VoteValue.OPEN] >= quorum:
		print("✓ CONSENSUS: OPEN")
		current_door_state = Enums.VoteValue.OPEN
		failed_rounds_count = 0
		return {
			"success": true,
			"agreed_value": Enums.VoteValue.OPEN,
			"phase_reached": "complete",
			"decided_nodes": decided_nodes,
			"votes": decisions
		}
	elif decisions[Enums.VoteValue.LOCKED] >= quorum:
		print("✓ CONSENSUS: LOCKED")
		current_door_state = Enums.VoteValue.LOCKED
		failed_rounds_count = 0
		return {
			"success": true,
			"agreed_value": Enums.VoteValue.LOCKED,
			"phase_reached": "complete",
			"decided_nodes": decided_nodes,
			"votes": decisions
		}
	else:
		print("✗ NO CONSENSUS")
		_increment_fail("No consensus reached")
		return {
			"success": false,
			"reason": "No consensus reached",
			"phase_reached": "complete",
			"decided_nodes": decided_nodes,
			"votes": decisions
		}

# ===== FAILSAFE MANAGEMENT =====
func _increment_fail(reason: String):
	failed_rounds_count += 1
	print("Failed rounds: %d/%d" % [failed_rounds_count, failsafe_threshold])
	check_failsafe()
	if failsafe_active:
		print("Failsafe active | reason: %s" % reason)

func check_failsafe():
	if failed_rounds_count >= failsafe_threshold:
		trigger_failsafe()

func trigger_failsafe():
	if not failsafe_active:
		failsafe_active = true
		print("\n🚨 FAILSAFE ACTIVATED - Manual override enabled")

# ===== SECURITY LEVEL TRANSITIONS =====
func check_level_transitions():
	var healthy = count_healthy_nodes()
	var total = nodes.size()

	match current_level:
		Enums.SecurityLevel.NORMAL:
			if healthy >= total:  # All nodes healthy
				print("Security level: NORMAL → MAINTENANCE (all nodes restored)")
				current_level = Enums.SecurityLevel.MAINTENANCE

		Enums.SecurityLevel.MAINTENANCE:
			if healthy < total:  # Some nodes compromised
				print("Security level: MAINTENANCE → NORMAL (compromise detected)")
				current_level = Enums.SecurityLevel.NORMAL

extends RefCounted
class_name ConsensusEngine

var network_state: NetworkState
var failed_rounds_count: int = 0
var failsafe_threshold: int = 10
var failsafe_active: bool = false
var current_door_state: Enums.VoteValue = Enums.VoteValue.LOCKED
var current_round: int = 0

# Message storage for current round
var pre_prepare_messages: Array[BFTMessage] = []
var prepare_messages: Array[BFTMessage] = []
var commit_messages: Array[BFTMessage] = []

func _init(net_state: NetworkState):
	network_state = net_state

func run_consensus_round(commander_proposal: Enums.VoteValue) -> Dictionary:
	print("\n=== CONSENSUS ROUND %d ===" % current_round)
	
	# Clear message storage
	pre_prepare_messages.clear()
	prepare_messages.clear()
	commit_messages.clear()
	
	# Check if enough healthy nodes
	var healthy_count = network_state.count_healthy_nodes()
	var required = 2 * network_state.f + 1
	
	if healthy_count < required:
		print("FAILED: Insufficient healthy nodes (%d < %d)" % [healthy_count, required])
		failed_rounds_count += 1
		check_failsafe()
		return {
			"success": false,
			"reason": "Insufficient healthy nodes",
			"phase_reached": "pre-check"
		}
	
	# Check if commander is healthy
	var commander = network_state.get_commander()
	if not commander.is_healthy():
		print("FAILED: Commander (Node 0) is not healthy")
		failed_rounds_count += 1
		check_failsafe()
		return {
			"success": false,
			"reason": "Commander is not healthy",
			"phase_reached": "pre-check"
		}
	
	# PHASE 1: PRE-PREPARE
	print("\n--- Phase 1: PRE-PREPARE ---")
	if not phase_1_pre_prepare(commander_proposal):
		failed_rounds_count += 1
		check_failsafe()
		return {
			"success": false,
			"reason": "Pre-prepare phase failed",
			"phase_reached": "pre-prepare"
		}
	
	# PHASE 2: PREPARE
	print("\n--- Phase 2: PREPARE ---")
	if not phase_2_prepare():
		failed_rounds_count += 1
		check_failsafe()
		return {
			"success": false,
			"reason": "Prepare phase failed",
			"phase_reached": "prepare"
		}
	
	# PHASE 3: COMMIT
	print("\n--- Phase 3: COMMIT ---")
	var consensus_value = phase_3_commit()
	if consensus_value == null:
		failed_rounds_count += 1
		check_failsafe()
		return {
			"success": false,
			"reason": "Commit phase failed - no consensus",
			"phase_reached": "commit"
		}
	
	# SUCCESS!
	print("\n✓ CONSENSUS REACHED: %s" % ("OPEN" if consensus_value == Enums.VoteValue.OPEN else "LOCKED"))
	current_door_state = consensus_value
	failed_rounds_count = 0
	current_round += 1
	
	return {
		"success": true,
		"agreed_value": consensus_value,
		"phase_reached": "complete",
		"pre_prepare_count": pre_prepare_messages.size(),
		"prepare_count": prepare_messages.size(),
		"commit_count": commit_messages.size()
	}

# PHASE 1: Commander broadcasts proposal to all nodes
func phase_1_pre_prepare(proposal: Enums.VoteValue) -> bool:
	var commander = network_state.get_commander()
	
	print("Commander (Node 0) proposes: %s" % ("OPEN" if proposal == Enums.VoteValue.OPEN else "LOCKED"))
	
	for node in network_state.nodes:
		if node.is_crashed():
			continue
		
		var received_value = proposal
		
		if commander.is_byzantine():
			received_value = Enums.VoteValue.OPEN if randf() > 0.5 else Enums.VoteValue.LOCKED
			print("  → Node %d receives: %s (Byzantine commander lying!)" % [node.id, "OPEN" if received_value == Enums.VoteValue.OPEN else "LOCKED"])
		else:
			print("  → Node %d receives: %s" % [node.id, "OPEN" if received_value == Enums.VoteValue.OPEN else "LOCKED"])
		
		# Create message
		var msg = BFTMessage.new(BFTMessage.MessageType.PRE_PREPARE, commander.id, node.id, received_value, current_round)
		pre_prepare_messages.append(msg)
	
	return pre_prepare_messages.size() > 0

# PHASE 2: All nodes broadcast what they received
func phase_2_prepare() -> bool:
	print("All nodes broadcast what they received from commander...")
	
	# Each node (except crashed) sends PREPARE messages
	for node in network_state.nodes:
		if node.is_crashed():
			continue
		
		# What did this node receive in phase 1?
		var received_value = get_pre_prepare_value_for_node(node.id)
		if received_value == null:
			continue  # Node didn't receive pre-prepare
		
		# Node broadcasts what it received to all other nodes
		for other_node in network_state.nodes:
			if other_node.is_crashed():
				continue
			
			var broadcast_value = received_value
			
			# Byzantine nodes might lie about what they received
			if node.is_byzantine():
				# Byzantine node sends different messages to different recipients
				broadcast_value = Enums.VoteValue.OPEN if randf() > 0.5 else Enums.VoteValue.LOCKED
				print("    Byzantine Node %d → Node %d: %s (lying)" % [node.id, other_node.id, "OPEN" if broadcast_value == Enums.VoteValue.OPEN else "LOCKED"])
			
			# Create message from node.id TO other_node.id
			var msg = BFTMessage.new(BFTMessage.MessageType.PREPARE, node.id, other_node.id, broadcast_value, current_round)
			prepare_messages.append(msg)
	
	# Print summary
	var prepare_for_open = prepare_messages.filter(func(m): return m.proposed_value == Enums.VoteValue.OPEN).size()
	var prepare_for_locked = prepare_messages.filter(func(m): return m.proposed_value == Enums.VoteValue.LOCKED).size()
	print("  PREPARE messages: %d for OPEN, %d for LOCKED" % [prepare_for_open, prepare_for_locked])
	
	# Phase succeeds if any messages were sent
	return prepare_messages.size() > 0

# PHASE 3: All nodes commit to the value they see consensus on
func phase_3_commit():
	print("Nodes commit to values they see majority for...")
	
	# Each node examines PREPARE messages and decides what to commit to
	for node in network_state.nodes:
		if node.is_crashed():
			continue
		
		# Count PREPARE messages this node received
		var value_counts = count_prepare_messages_for_node(node.id)
		
		# Does this node see 2f+1 messages for a value?
		var commit_value = null
		if value_counts[Enums.VoteValue.OPEN] >= 2 * network_state.f + 1:
			commit_value = Enums.VoteValue.OPEN
		elif value_counts[Enums.VoteValue.LOCKED] >= 2 * network_state.f + 1:
			commit_value = Enums.VoteValue.LOCKED
		
		if commit_value != null:
			# Byzantine nodes might commit to random values anyway
			if node.is_byzantine():
				commit_value = Enums.VoteValue.OPEN if randf() > 0.5 else Enums.VoteValue.LOCKED
			
			print("  Node %d commits: %s" % [node.id, "OPEN" if commit_value == Enums.VoteValue.OPEN else "LOCKED"])
			
			# Broadcast commit to all other nodes
			for other_node in network_state.nodes:
				if other_node.is_crashed():
					continue
				
				# Create COMMIT message FROM node TO other_node
				var msg = BFTMessage.new(BFTMessage.MessageType.COMMIT, node.id, other_node.id, commit_value, current_round)
				commit_messages.append(msg)
	
	# Final consensus: count COMMIT messages (counting unique senders only)
	var commit_counts = {
		Enums.VoteValue.OPEN: 0,
		Enums.VoteValue.LOCKED: 0
	}
	
	var counted_senders = {}
	for msg in commit_messages:
		# Only count one commit per sender (avoid counting duplicates)
		if not counted_senders.has(msg.sender_id):
			commit_counts[msg.proposed_value] += 1
			counted_senders[msg.sender_id] = true
	
	print("  COMMIT messages: %d for OPEN, %d for LOCKED" % [commit_counts[Enums.VoteValue.OPEN], commit_counts[Enums.VoteValue.LOCKED]])
	
	# Need 2f+1 commits for consensus
	if commit_counts[Enums.VoteValue.OPEN] >= 2 * network_state.f + 1:
		return Enums.VoteValue.OPEN
	elif commit_counts[Enums.VoteValue.LOCKED] >= 2 * network_state.f + 1:
		return Enums.VoteValue.LOCKED
	
	# No consensus reached
	return null

# Get what value a specific node received in PRE-PREPARE
func get_pre_prepare_value_for_node(node_id: int):
	# Search for the message that was sent TO this specific node
	for msg in pre_prepare_messages:
		if msg.receiver_id == node_id:
			return msg.proposed_value
	return null 

# Count PREPARE messages a node would see
func count_prepare_messages_for_node(node_id: int) -> Dictionary:
	var counts = {
		Enums.VoteValue.OPEN: 0,
		Enums.VoteValue.LOCKED: 0
	}
	
	# Count messages from different senders
	var senders_seen = {}
	for msg in prepare_messages:
		# Only count one message per sender (prevent double-counting)
		if not senders_seen.has(msg.sender_id):
			counts[msg.proposed_value] += 1
			senders_seen[msg.sender_id] = true
	
	return counts

func check_failsafe():
	if failed_rounds_count >= failsafe_threshold:
		trigger_failsafe()

func trigger_failsafe():
	failsafe_active = true
	print("\n🚨 FAILSAFE ACTIVATED - Manual override enabled")

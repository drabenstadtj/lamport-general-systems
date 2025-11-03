extends Node
class_name BFTNode

# Node Identity
var node_id: int
var neighbors: Array[BFTNode] = []
var is_source: bool = false

# State Variables
var corrupted: bool = false
var active: bool = true
var believed_state = null
var message_history: Array = []

# System Configuration
var N: int = 7
var M: int = 2
var auth_mode: String = "unsigned"
var decision_type: String = "binary"
var state_space: Array = [0, 1]
var max_rounds: int = 3

# Message buffer
var incoming_buffer: Array = []

# Heartbeat System
var heartbeat_interval: float = 0.5
var heartbeat_timeout: float = 2.0
var last_heartbeat_sent: float = 0.0
var last_heartbeat_received: Dictionary = {}
var suspected_dead: Array = []
var heartbeat_initialized: bool = false

# Signals
signal message_sent(sender_id: int, receiver_id: int, message: Dictionary)
signal round_completed(round_num: int)
signal protocol_finished(decision)
signal heartbeat_sent(sender_id: int)
signal heartbeat_received(sender_id: int, from_id: int)
signal node_suspected_dead(node_id: int, suspected_by: int)
signal node_recovered(node_id: int, detected_by: int)

func _process(delta):
	# Don't do anything until properly initialized
	if not active or not heartbeat_initialized:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Send heartbeat periodically
	if current_time - last_heartbeat_sent >= heartbeat_interval:
		send_heartbeat()
		last_heartbeat_sent = current_time
	
	# Check for dead nodes (throttled to avoid spam)
	if int(current_time * 2) % 2 == 0:
		check_heartbeat_timeouts()

func send_heartbeat():
	if not active:
		return
	
	for neighbor in neighbors:
		if neighbor and neighbor != self and neighbor.active:
			neighbor.receive_heartbeat(node_id)
	
	heartbeat_sent.emit(node_id)

func receive_heartbeat(from_id: int):
	if not active:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Initialize tracking if not already
	if not last_heartbeat_received.has(from_id):
		last_heartbeat_received[from_id] = current_time
		return
	
	last_heartbeat_received[from_id] = current_time
	
	# Check if node was suspected dead but is now alive
	if from_id in suspected_dead:
		suspected_dead.erase(from_id)
		node_recovered.emit(from_id, node_id)
		print("Node %d: Detected Node %d has recovered" % [node_id, from_id])
	
	heartbeat_received.emit(node_id, from_id)

func check_heartbeat_timeouts():
	if not active:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for neighbor_id in last_heartbeat_received.keys():
		if neighbor_id == node_id:
			continue
		
		var time_since_heartbeat = current_time - last_heartbeat_received[neighbor_id]
		
		if time_since_heartbeat > heartbeat_timeout:
			if neighbor_id not in suspected_dead:
				suspected_dead.append(neighbor_id)
				node_suspected_dead.emit(neighbor_id, node_id)
				print("Node %d: Suspected Node %d is dead (no heartbeat for %.1fs)" % [node_id, neighbor_id, time_since_heartbeat])

func is_node_alive(node_id_to_check: int) -> bool:
	return node_id_to_check not in suspected_dead

func get_alive_neighbors() -> Array[BFTNode]:
	var alive: Array[BFTNode] = []
	for neighbor in neighbors:
		if neighbor and neighbor != self and is_node_alive(neighbor.node_id):
			alive.append(neighbor)
	return alive

func initialize_node(initial_value = null):
	active = true
	message_history.clear()
	incoming_buffer.clear()
	suspected_dead.clear()
	
	# Reset heartbeat tracking using ACTUAL neighbors
	var current_time = Time.get_ticks_msec() / 1000.0
	last_heartbeat_sent = current_time
	last_heartbeat_received.clear()
	
	# Only track neighbors that actually exist
	for neighbor in neighbors:
		if neighbor and neighbor != self:
			last_heartbeat_received[neighbor.node_id] = current_time
	
	# NOW enable heartbeat system
	heartbeat_initialized = true
	
	if is_source:
		believed_state = initial_value
	else:
		believed_state = null

func run_protocol():
	for round in range(max_rounds + 1):
		if not active:
			break
		
		await broadcast_phase(round)
		await get_tree().create_timer(0.1).timeout
		update_belief(round)
		round_completed.emit(round)
	
	var final_decision = finalize_decision()
	protocol_finished.emit(final_decision)
	return final_decision

func broadcast_phase(round: int):
	if corrupted:
		byzantine_broadcast(round)
	else:
		honest_broadcast(round)

func honest_broadcast(round: int):
	var message = create_message(believed_state, round)
	
	for neighbor in get_alive_neighbors():
		if neighbor.active:
			send_message(neighbor, message)

func byzantine_broadcast(round: int):
	if auth_mode == "unsigned":
		for neighbor in neighbors:
			if neighbor and neighbor != self and neighbor.active:
				var fake_state = choose_malicious_state(neighbor, round)
				var message = create_message(fake_state, round)
				send_message(neighbor, message)
	else:
		var message = create_message(believed_state, round)
		for neighbor in neighbors:
			if neighbor and neighbor != self and neighbor.active:
				if not should_withhold(neighbor, round):
					send_message(neighbor, message)

func send_message(recipient: BFTNode, message: Dictionary):
	recipient.incoming_buffer.append(message)
	message_sent.emit(node_id, recipient.node_id, message)

func receive_messages(round: int) -> Array:
	var incoming_messages = []
	
	for msg in incoming_buffer:
		if msg.round == round:
			if is_node_alive(msg.sender):
				incoming_messages.append(msg)
			else:
				print("Node %d: Ignoring message from suspected dead node %d" % [node_id, msg.sender])
	
	message_history.append({
		"round": round,
		"messages": incoming_messages
	})
	
	incoming_buffer = incoming_buffer.filter(func(msg): return msg.round != round)
	return incoming_messages

func update_belief(round: int):
	if corrupted:
		believed_state = choose_arbitrary_state()
	else:
		believed_state = compute_honest_belief(round)

func compute_honest_belief(round: int):
	var current_messages = receive_messages(round)
	
	if current_messages.is_empty():
		return believed_state
	
	if decision_type == "binary":
		return compute_majority(current_messages)
	else:
		return compute_plurality(current_messages)

func compute_majority(messages: Array):
	var count_0 = 0
	var count_1 = 0
	
	for msg in messages:
		if msg.state == 0:
			count_0 += 1
		else:
			count_1 += 1
	
	return 1 if count_1 > count_0 else 0

func compute_plurality(messages: Array):
	var vote_counts = {}
	
	for msg in messages:
		var state = msg.state
		if not vote_counts.has(state):
			vote_counts[state] = 0
		vote_counts[state] += 1
	
	var max_votes = 0
	var winner = null
	
	for state in vote_counts.keys():
		if vote_counts[state] > max_votes:
			max_votes = vote_counts[state]
			winner = state
	
	return winner if winner != null else state_space[0]

func finalize_decision():
	if not active:
		return null
	
	var all_messages = []
	for entry in message_history:
		all_messages.append_array(entry.messages)
	
	if corrupted:
		return choose_arbitrary_state()
	else:
		if decision_type == "binary":
			return compute_majority(all_messages)
		else:
			return compute_plurality(all_messages)

func create_message(state, round: int) -> Dictionary:
	return {
		"sender": node_id,
		"state": state,
		"round": round,
		"timestamp": Time.get_ticks_msec()
	}

func simulate_crash():
	active = false
	heartbeat_initialized = false
	print("Node %d crashed!" % node_id)

func simulate_recovery():
	if not active:
		active = true
		suspected_dead.clear()
		
		# Re-initialize heartbeat tracking
		var current_time = Time.get_ticks_msec() / 1000.0
		last_heartbeat_sent = current_time
		for neighbor in neighbors:
			if neighbor and neighbor != self:
				last_heartbeat_received[neighbor.node_id] = current_time
		
		heartbeat_initialized = true
		print("Node %d recovered!" % node_id)

func choose_malicious_state(target_neighbor: BFTNode, round: int):
	if target_neighbor.node_id % 2 == 0:
		return 0
	else:
		return 1

func should_withhold(neighbor: BFTNode, round: int) -> bool:
	return randf() < 0.3

func choose_arbitrary_state():
	return state_space[randi() % state_space.size()]

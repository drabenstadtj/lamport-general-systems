extends Node
class_name BFTNetworkManager

var nodes: Array[BFTNode] = []
var results: Array = []

# Heartbeat monitoring
var heartbeat_monitor_enabled: bool = true
var dead_nodes: Array = []  # Nodes that have been detected as dead

signal network_ready()
signal consensus_reached(value)
signal consensus_failed(decisions: Array)
signal node_crashed(node_id: int)
signal node_recovered(node_id: int)
signal heartbeat_activity(sender_id: int, receiver_id: int)

func setup_network(num_nodes: int, num_corrupted: int, initial_value):
	# Clear existing nodes
	for node in nodes:
		node.queue_free()
	nodes.clear()
	results.clear()
	dead_nodes.clear()
	
	# Create nodes
	for i in range(num_nodes):
		var node = BFTNode.new()
		node.name = "BFTNode_" + str(i)
		node.node_id = i
		node.is_source = (i == 0)
		node.N = num_nodes
		node.M = num_corrupted
		node.max_rounds = num_corrupted + 1
		
		add_child(node)
		nodes.append(node)
		
		# Important: Set processing enabled
		node.set_process(true)
	
	# Mark some nodes as corrupted
	for i in range(num_corrupted):
		var corrupt_index = i + 1  # Don't corrupt the source
		if corrupt_index < num_nodes:
			nodes[corrupt_index].corrupted = true
	
	# Create fully connected network
	for node in nodes:
		node.neighbors = nodes.duplicate()
	
	# Initialize all nodes
	for node in nodes:
		node.initialize_node(initial_value)
		
		# Connect signals for monitoring
		node.protocol_finished.connect(_on_node_finished.bind(node))
		
		# Connect heartbeat signals
		if heartbeat_monitor_enabled:
			node.heartbeat_sent.connect(_on_heartbeat_sent)
			node.heartbeat_received.connect(_on_heartbeat_received)
			node.node_suspected_dead.connect(_on_node_suspected_dead)
			node.node_recovered.connect(_on_node_detected_alive)
	
	network_ready.emit()
	print("Network setup complete: %d nodes, %d corrupted" % [num_nodes, num_corrupted])
	print("Heartbeat system: %s" % ("ENABLED" if heartbeat_monitor_enabled else "DISABLED"))

func run_protocol():
	print("Starting BFT protocol...")
	results.clear()
	
	# Start all nodes
	for node in nodes:
		node.run_protocol()

func crash_node(node_id: int):
	var node = get_node_by_id(node_id)
	if node and node.active:
		node.simulate_crash()
		if node_id not in dead_nodes:
			dead_nodes.append(node_id)
		node_crashed.emit(node_id)
		print("Network Manager: Node %d crashed" % node_id)

func recover_node(node_id: int):
	var node = get_node_by_id(node_id)
	if node and not node.active:
		node.simulate_recovery()
		dead_nodes.erase(node_id)
		node_recovered.emit(node_id)
		print("Network Manager: Node %d recovered" % node_id)

func crash_random_node():
	var active_nodes = []
	for node in nodes:
		if node.active and not node.is_source:  # Don't crash the source
			active_nodes.append(node)
	
	if active_nodes.size() > 0:
		var random_node = active_nodes[randi() % active_nodes.size()]
		crash_node(random_node.node_id)

func get_network_status() -> Dictionary:
	var status = {
		"total": nodes.size(),
		"active": 0,
		"crashed": 0,
		"corrupted": 0,
		"honest": 0
	}
	
	for node in nodes:
		if node.active:
			status.active += 1
		else:
			status.crashed += 1
		
		if node.corrupted:
			status.corrupted += 1
		else:
			status.honest += 1
	
	return status

func print_network_status():
	var status = get_network_status()
	print("\n--- Network Status ---")
	print("Total: %d | Active: %d | Crashed: %d" % [status.total, status.active, status.crashed])
	print("Honest: %d | Corrupted: %d" % [status.honest, status.corrupted])
	
	if dead_nodes.size() > 0:
		print("Detected dead nodes: %s" % str(dead_nodes))

# Heartbeat signal handlers
func _on_heartbeat_sent(sender_id: int):
	# You can add logging or visualization here
	pass

func _on_heartbeat_received(receiver_id: int, from_id: int):
	heartbeat_activity.emit(from_id, receiver_id)

func _on_node_suspected_dead(suspected_id: int, detected_by: int):
	if suspected_id not in dead_nodes:
		dead_nodes.append(suspected_id)
	print("Network Manager: Node %d detected as dead (by Node %d)" % [suspected_id, detected_by])

func _on_node_detected_alive(recovered_id: int, detected_by: int):
	dead_nodes.erase(recovered_id)
	print("Network Manager: Node %d detected as alive again (by Node %d)" % [recovered_id, detected_by])

func _on_node_finished(decision, node: BFTNode):
	results.append({
		"node_id": node.node_id,
		"corrupted": node.corrupted,
		"active": node.active,
		"decision": decision
	})
	
	# Check if all active nodes finished
	var active_count = 0
	for n in nodes:
		if n.active:
			active_count += 1
	
	if results.size() >= active_count:
		check_consensus()

func check_consensus():
	var honest_decisions = []
	
	for result in results:
		if not result.corrupted and result.active:
			honest_decisions.append(result.decision)
	
	print("\n=== Protocol Results ===")
	for result in results:
		var status = "CORRUPTED" if result.corrupted else ("CRASHED" if not result.active else "HONEST")
		print("Node %d [%s]: %s" % [result.node_id, status, str(result.decision)])
	
	if honest_decisions.is_empty():
		print("\nNo honest nodes active!")
		consensus_failed.emit([])
		return
	
	var first_decision = honest_decisions[0]
	var all_agree = true
	
	for decision in honest_decisions:
		if decision != first_decision:
			all_agree = false
			break
	
	if all_agree:
		print("\n✓ CONSENSUS ACHIEVED: %s" % str(first_decision))
		consensus_reached.emit(first_decision)
	else:
		print("\n✗ CONSENSUS FAILED")
		print("Honest decisions: %s" % str(honest_decisions))
		consensus_failed.emit(honest_decisions)

func get_node_by_id(id: int) -> BFTNode:
	for node in nodes:
		if node.node_id == id:
			return node
	return null

func set_heartbeat_enabled(enabled: bool):
	heartbeat_monitor_enabled = enabled
	print("Heartbeat monitoring: %s" % ("ENABLED" if enabled else "DISABLED"))

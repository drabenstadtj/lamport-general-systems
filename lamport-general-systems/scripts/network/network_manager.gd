extends Node

var network_state: NetworkState
var consensus_engine
var current_turn: int = 0
var _initialized: bool = false

# Default values (can be overridden)
var f_value: int = 1
var network_id: String = "default"
var num_nodes: int = 0

signal node_state_changed(node_id: int, old_state: Enums.NodeState, new_state: Enums.NodeState)
signal consensus_completed(result: Dictionary)
signal turn_completed(turn_number: int)
signal game_won(win_type: String)

func _ready():
	add_to_group("network_manager")

func initialize_from_scene():
	"""Call this from your scene after it loads"""
	if _initialized:
		print("WARNING: Already initialized, skipping")
		return
	
	# Look for a NetworkConfig node in the scene
	var config = get_tree().get_first_node_in_group("network_config")
	if config:
		f_value = config.f_value
		network_id = config.network_id
		print("NetworkManager: Using config from scene (f=%d, id=%s)" % [f_value, network_id])
	
	initialize_network()

func initialize_network():
	_initialized = true
	var physical_node_ids = discover_physical_servers()
	
	# Calculate minimum required nodes for BFT
	var min_required = 3 * f_value + 1
	
	# Determine total nodes needed (remove 'var' to use the class variable)
	num_nodes = max(min_required, physical_node_ids.size())  # Changed this line
	
	# Validate we have enough
	if physical_node_ids.size() < min_required:
		push_error("NetworkManager: Not enough physical servers! Found %d, need at least %d (for f=%d)" % [physical_node_ids.size(), min_required, f_value])
		return
	
	print("NetworkManager: Initializing network (f=%d, nodes=%d, physical=%d)" % [f_value, num_nodes, physical_node_ids.size()])
	
	# Create the BFT network with enough nodes
	network_state = NetworkState.new(f_value, num_nodes)
	consensus_engine = ConsensusEngineAdaptive.new(network_state)
	
	# Verify all physical servers have corresponding logical nodes
	for node_id in physical_node_ids:
		if node_id >= num_nodes:
			push_warning("NetworkManager: Physical server has node_id %d but only %d logical nodes exist!" % [node_id, num_nodes])
	
	current_turn = 0
	print("NetworkManager: Ready!")

func discover_physical_servers() -> Array[int]:
	"""Scan the scene for all Server nodes and collect their node_ids."""
	var node_ids: Array[int] = []
	
	# Find all Server nodes in the scene
	var servers = get_tree().get_nodes_in_group("server")
	
	for server in servers:
		if server.has_method("get_node_id") or "node_id" in server:
			var nid = server.node_id if "node_id" in server else server.get_node_id()
			if nid >= 0:  # Only count active nodes
				node_ids.append(nid)
	
	# Sort and remove duplicates
	node_ids.sort()
	var unique_ids: Array[int] = []
	for id in node_ids:
		if unique_ids.is_empty() or unique_ids[-1] != id:
			unique_ids.append(id)
	
	print("Discovered %d physical servers with node_ids: %s" % [unique_ids.size(), unique_ids])
	return unique_ids


# Direct Node Actions (called by terminals or physical interactions)

func crash_node(node_id: int) -> bool:
	var node = network_state.get_node(node_id)
	
	if not node or node.is_crashed():
		return false
	
	node.set_state(Enums.NodeState.CRASHED)
	node_state_changed.emit(node_id, Enums.NodeState.HEALTHY, Enums.NodeState.CRASHED)
	_advance_turn()
	return true

func reboot_node(node_id: int) -> bool:
	var node = network_state.get_node(node_id)
	
	if not node or not node.is_crashed():
		return false
	
	node.set_state(Enums.NodeState.HEALTHY)
	node_state_changed.emit(node_id, Enums.NodeState.CRASHED, Enums.NodeState.HEALTHY)
	_advance_turn()
	return true

func corrupt_node(node_id: int) -> bool:
	var node = network_state.get_node(node_id)
	
	if not node or not node.is_healthy():
		return false
	
	node.set_state(Enums.NodeState.BYZANTINE)
	node_state_changed.emit(node_id, Enums.NodeState.HEALTHY, Enums.NodeState.BYZANTINE)
	_advance_turn()
	return true



# Consensus

func run_consensus(proposal: Enums.VoteValue) -> Dictionary:
	print("\n=== CONSENSUS ROUND ===")
	var result = consensus_engine.run_consensus_round(proposal)
	consensus_completed.emit(result)
	
	# Check for door opening via consensus
	if result.get("success", false):
		var agreed_value = result.get("agreed_value", Enums.VoteValue.LOCKED)
		if agreed_value == Enums.VoteValue.OPEN:
			game_won.emit("consensus")
	
	return result

# Internal

func _advance_turn():
	network_state.check_level_transitions()
	current_turn += 1
	turn_completed.emit(current_turn)

# Query Interface

func get_network_node(node_id: int) -> NetworkNode:
	return network_state.get_node(node_id) if network_state else null

func get_network_health() -> Dictionary:
	if not network_state:
		return {}
	
	var healthy = 0
	var crashed = 0
	var byzantine = 0
	
	for node in network_state.nodes:
		match node.state:
			Enums.NodeState.HEALTHY: healthy += 1
			Enums.NodeState.CRASHED: crashed += 1
			Enums.NodeState.BYZANTINE: byzantine += 1
	
	return {
		"healthy": healthy,
		"crashed": crashed,
		"byzantine": byzantine,
		"total": network_state.nodes.size(),
		"f": network_state.f
	}

func get_consensus_state() -> Dictionary:
	if not consensus_engine:
		return {}
	
	return {
		"current_door_state": consensus_engine.current_door_state,
		"failed_rounds": consensus_engine.failed_rounds_count if consensus_engine.has("failed_rounds_count") else 0,
		"failsafe_active": consensus_engine.failsafe_active if consensus_engine.has("failsafe_active") else false
	}

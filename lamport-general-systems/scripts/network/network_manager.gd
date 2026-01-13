# network_manager.gd
extends Node
class_name NetworkManager

# Configuration
@export var network_id: String = "default_network"
@export var f_value: int = 1
@export var num_nodes: int = 7

# Core systems
var network_state: NetworkState
var consensus_engine

# Game state
var current_turn: int = 0

# Signals for other systems to react
signal node_state_changed(node_id: int, old_state: Enums.NodeState, new_state: Enums.NodeState)
signal consensus_completed(result: Dictionary)
signal turn_completed(turn_number: int)
signal game_won(win_type: String)

func _ready():
	add_to_group("network_manager")
	initialize_network()

func initialize_network():
	print("NetworkManager: Initializing network (f=%d, nodes=%d)" % [f_value, num_nodes])
	
	# Create the BFT network
	network_state = NetworkState.new(f_value)
	consensus_engine = ConsensusEngineAdaptive.new(network_state)
	
	current_turn = 0
	print("NetworkManager: Ready!")

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

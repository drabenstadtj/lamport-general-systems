extends Node

var network_state: NetworkState
var consensus_engine: ConsensusEngine
var current_turn: int = 0

# Registry of 3D objects
var node_terminals: Dictionary = {}
var door_object = null

var action_handler: PlayerActionHandler

signal turn_completed(turn_info)
signal game_won(path_type)

func _ready():
	print("GameManager initialized")

func initialize_game(f_value: int):
	print("Initializing game with f=%d" % f_value)
	network_state = NetworkState.new(f_value)
	consensus_engine = ConsensusEngine.new(network_state)
	action_handler = PlayerActionHandler.new(network_state, consensus_engine)
	current_turn = 0
	
	# Re-link all registered terminals to their nodes
	for node_id in node_terminals:
		var terminal = node_terminals[node_id]
		var node = network_state.get_node(node_id)
		if node:
			node.link_game_object(terminal)
	
	print("Game ready!")

func register_node_terminal(node_id: int, terminal):
	node_terminals[node_id] = terminal
	print("Registered terminal for node %d" % node_id)

func register_door(door):
	door_object = door
	print("Door registered")

func get_game_status() -> Dictionary:
	return {
		"turn": current_turn,
		"nodes_registered": node_terminals.size()
	}

# Player action interface
func player_action(action_type: Enums.ActionType, node_id: int = -1, door_value = null):
	var result = null
	
	match action_type:
		Enums.ActionType.REBOOT_NODE:
			result = action_handler.reboot_node(node_id)
		Enums.ActionType.CRASH_NODE:
			result = action_handler.crash_node(node_id)
		Enums.ActionType.CORRUPT_NODE:
			result = action_handler.corrupt_node(node_id)
		Enums.ActionType.COMMAND_DOOR:
			result = action_handler.command_door(door_value)
		Enums.ActionType.EXPLOIT_DOOR:
			result = action_handler.exploit_door()
	
	if result and result.success:
		execute_turn(result)
	else:
		print("Action failed: ", result.message)

func execute_turn(action_result: Dictionary):
	print("\n=== TURN %d ===" % (current_turn + 1))
	print("Action: ", action_result.message)
	
	# Check if this action opened the door (win condition)
	if action_result.get("door_opened", false):
		var win_type = action_result.get("win_type", "unknown")
		if win_type == "restoration":
			print("\nRestoration Path - Door opened via authorized access")
			game_won.emit("restoration")
		elif win_type == "sabotage":
			print("\nSabotage Path - Door forced open via failsafe exploit")
			game_won.emit("sabotage")
	
	# Run consensus round (unless the action was a door command/exploit)
	var action_type = action_result.get("action_type", "")
	if action_type != "door":
		var consensus_result = consensus_engine.run_consensus_round(Enums.VoteValue.OPEN)
		
		if door_object:
			door_object.update_state(consensus_engine.current_door_state)
		
		if consensus_result.success:
			print("Consensus SUCCESS: Door is now %s" % ("OPEN" if consensus_result.agreed_value == Enums.VoteValue.OPEN else "LOCKED"))
		else:
			print("Consensus FAILED: %s (Failed rounds: %d/10)" % [consensus_result.reason, consensus_result.get("failed_count", 0)])
		
		# Check level transitions
		network_state.check_level_transitions()
		
		# Reset round tracking
		action_handler.reset_round_tracking()
		
		# Emit signal with consensus info
		var turn_info = {
			"turn": current_turn,
			"action_result": action_result,
			"consensus_result": consensus_result,
			"current_level": network_state.current_level,
			"door_state": consensus_engine.current_door_state
		}
		turn_completed.emit(turn_info)
	else:
		# Door action - no consensus round
		var turn_info = {
			"turn": current_turn,
			"action_result": action_result,
			"current_level": network_state.current_level,
			"door_state": consensus_engine.current_door_state
		}
		turn_completed.emit(turn_info)
	
	# Increment turn
	current_turn += 1

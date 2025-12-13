extends Node

var network_state: NetworkState
var consensus_engine
var current_turn: int = 0

var node_terminals: Dictionary = {}
var door_object = null

var action_handler: PlayerActionHandler

signal turn_completed(turn_info)
signal game_won(path_type)
signal consensus_completed(consensus_result)

# Toggle which engine to use
const USE_ADAPTIVE := true

func _ready():
	print("GameManager initialized")

func _input(event):
	# Check for keypress to run consensus at any time
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_MINUS:
				# Run consensus for OPEN
				run_consensus_manually(Enums.VoteValue.OPEN)
			KEY_EQUAL:
				# Run consensus for LOCKED
				run_consensus_manually(Enums.VoteValue.LOCKED)

func initialize_game(f_value: int):
	print("Initializing game with f=%d" % f_value)
	network_state = NetworkState.new(f_value)

	if USE_ADAPTIVE:
		consensus_engine = ConsensusEngineAdaptive.new(network_state)
	else:
		consensus_engine = ConsensusEngineClassic.new(network_state)

	action_handler = PlayerActionHandler.new(network_state, consensus_engine)
	current_turn = 0

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

func player_action(action_type: Enums.ActionType, node_id: int = -1, door_value = null):
	var result: Dictionary

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
		_:
			print("Unknown action")
			return

	if result and result.get("success", false):
		execute_turn(result)
	else:
		print("Action failed: %s" % result.get("message", "unknown"))

func execute_turn(action_result: Dictionary):
	print("\n=== TURN %d ===" % (current_turn + 1))
	print("Action: %s" % action_result.get("message", ""))

	# Door win check
	if action_result.get("door_opened", false):
		var win_type = action_result.get("win_type", "unknown")
		if win_type == "restoration":
			print("\nRestoration Path - Door opened via authorized access")
			game_won.emit("restoration")
		elif win_type == "sabotage":
			print("\nSabotage Path - Door forced open via failsafe exploit")
			game_won.emit("sabotage")

	# NO automatic consensus - removed the automatic consensus logic
	# User can press keys to run consensus whenever they want
	
	# Just update states and complete the turn
	network_state.check_level_transitions()
	action_handler.reset_round_tracking()
	
	var turn_info = {
		"turn": current_turn,
		"action_result": action_result,
		"current_level": network_state.current_level,
		"door_state": consensus_engine.current_door_state
	}
	turn_completed.emit(turn_info)
	
	current_turn += 1
	print("\nTurn complete. You can perform another action or run consensus (SPACE/R/T).")

# Manual consensus trigger
func run_consensus_manually(proposal: Enums.VoteValue = Enums.VoteValue.OPEN):
	if not consensus_engine:
		print("ERROR: Game not initialized. Cannot run consensus.")
		return

	print("\n=== MANUAL CONSENSUS TRIGGERED ===")
	print("Proposing: %s" % ("OPEN" if proposal == Enums.VoteValue.OPEN else "LOCKED"))

	# Log consensus start on all nodes
	for terminal in node_terminals.values():
		terminal.add_log("═══ CONSENSUS START ═══")

	var consensus_result: Dictionary = consensus_engine.run_consensus_round(proposal)

	if door_object:
		door_object.update_state(consensus_engine.current_door_state)

	if consensus_result.get("success", false):
		var agreed = consensus_result.get("agreed_value", Enums.VoteValue.LOCKED)
		print("Consensus SUCCESS: Door is now %s" % ("OPEN" if agreed == Enums.VoteValue.OPEN else "LOCKED"))
		
		# Log success on all nodes
		for terminal in node_terminals.values():
			terminal.add_log("✓ CONSENSUS OK")
		
		if agreed == Enums.VoteValue.OPEN:
			print("\nDoor opened through consensus")
			game_won.emit("consensus")
	else:
		var reason = consensus_result.get("reason", "Unknown")
		print("Consensus FAILED: %s" % reason)
		
		# Log failure on all nodes
		for terminal in node_terminals.values():
			terminal.add_log("✗ CONSENSUS FAIL")
		
		if consensus_engine.failsafe_active:
			print("⚠️ FAILSAFE IS NOW ACTIVE")

	consensus_completed.emit(consensus_result)
	print("\nConsensus complete.")

# Additional helper methods for external control
func get_consensus_state() -> Dictionary:
	return {
		"current_door_state": consensus_engine.current_door_state,
		"failed_rounds": consensus_engine.failed_rounds_count,
		"failsafe_active": consensus_engine.failsafe_active,
		"failsafe_threshold": consensus_engine.failsafe_threshold
	}

func get_network_health() -> Dictionary:
	var healthy = 0
	var crashed = 0
	var byzantine = 0

	for node in network_state.nodes:
		if node.is_healthy():
			healthy += 1
		elif node.is_crashed():
			crashed += 1
		elif node.is_byzantine():
			byzantine += 1

	return {
		"healthy": healthy,
		"crashed": crashed,
		"byzantine": byzantine,
		"total": network_state.nodes.size(),
		"f": network_state.f,
		"required_for_consensus": 2 * network_state.f + 1
	}

func get_node_terminal(node_id: int) -> NodeTerminal:
	return node_terminals.get(node_id)

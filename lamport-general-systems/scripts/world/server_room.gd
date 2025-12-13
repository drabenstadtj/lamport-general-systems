extends Node3D

@onready var status_label = $SubViewportContainer/SubViewport/CanvasLayer/StatusLabel
@export var f: int = 1
@export var num_nodes: int = 7

# NodeTerminals will be created for each server
var node_terminals: Array[NodeTerminal] = []

func _ready():
	# Create NodeTerminals first
	create_node_terminals()

	# Initialize the game with BFT network
	GameManager.initialize_game(f)

	# Refresh visuals after network is initialized
	refresh_all_terminals()

	# Connect signals
	GameManager.turn_completed.connect(_on_turn_completed)
	GameManager.game_won.connect(_on_game_won)
	GameManager.consensus_completed.connect(_on_consensus_completed)

	update_status()

	print("\n=== CONTROLS ===")
	print("Node actions (hold number key 0-2):")
	print("  R = Reboot node")
	print("  C = Crash node")
	print("  X = Corrupt node")
	print("\nConsensus actions:")
	print("  - (minus) = Run consensus for OPEN")
	print("  = (equals) = Run consensus for LOCKED")
	print("\nDoor actions:")
	print("  O = Command door OPEN (requires Maintenance level)")
	print("  E = Exploit door (requires failsafe active)")
	print("================\n")

func create_node_terminals():
	"""Create NodeTerminal instances for each node in the network."""
	for i in range(num_nodes):
		var terminal = NodeTerminal.new()
		terminal.node_id = i
		terminal.name = "NodeTerminal%d" % i
		add_child(terminal)
		node_terminals.append(terminal)
		print("Created NodeTerminal for node %d" % i)

func refresh_all_terminals():
	for terminal in GameManager.node_terminals.values():
		terminal.update_visuals()

func _on_turn_completed(_turn_info):
	update_status()
	refresh_all_terminals()

func _on_consensus_completed(_consensus_result):
	update_status()
	refresh_all_terminals()

func _on_game_won(path_type):
	status_label.text = "VICTORY: %s path!" % path_type.to_upper()
	status_label.add_theme_color_override("font_color", Color.GOLD)

func update_status():
	var status = GameManager.get_game_status()
	var level_name = ["", "MAINTENANCE", "NORMAL", "DEFENSIVE"][GameManager.network_state.current_level]
	var door_state = "OPEN" if GameManager.consensus_engine.current_door_state == Enums.VoteValue.OPEN else "LOCKED"

	var base_status = "Turn: %d | Level: %s | Door: %s | Healthy: %d | Crashed: %d | Byzantine: %d | Failed: %d/10" % [
		status["turn"],
		level_name,
		door_state,
		GameManager.network_state.count_healthy_nodes(),
		GameManager.network_state.count_crashed_nodes(),
		GameManager.network_state.count_byzantine_nodes(),
		GameManager.consensus_engine.failed_rounds_count
	]

	if GameManager.door_object:
		if GameManager.door_object.can_command():
			base_status += "\n[O] Command Door Open (Maintenance Mode)"
		elif GameManager.door_object.can_exploit():
			base_status += "\n[E] Exploit Door (Failsafe Active)"

	status_label.text = base_status

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_O:
				print("\n>>> Player commanding door OPEN")
				GameManager.player_action(Enums.ActionType.COMMAND_DOOR, -1, Enums.VoteValue.OPEN)
			#KEY_E:
				#print("\n>>> Player exploiting door")
				#GameManager.player_action(Enums.ActionType.EXPLOIT_DOOR)

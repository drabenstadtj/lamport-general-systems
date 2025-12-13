extends Node
class_name NetworkInitializer

## Minimal network initializer - just creates NodeTerminals and initializes GameManager
## Use this instead of the full server_room.gd if you don't need the debug UI

@export var f: int = 1
@export var num_nodes: int = 7

func _ready():
	# Create NodeTerminals first
	create_node_terminals()

	# Initialize the game with BFT network
	GameManager.initialize_game(f)

	# Connect to important signals
	GameManager.turn_completed.connect(_on_turn_completed)
	GameManager.consensus_completed.connect(_on_consensus_completed)

	print("Network initialized: f=%d, nodes=%d" % [f, num_nodes])

	# Wait a frame then force all server boxes to update their lights
	await get_tree().process_frame
	refresh_all_server_boxes()

func create_node_terminals():
	"""Create NodeTerminal instances for each node in the network."""
	for i in range(num_nodes):
		var terminal = NodeTerminal.new()
		terminal.node_id = i
		terminal.name = "NodeTerminal%d" % i
		add_child(terminal)

func _on_turn_completed(_turn_info):
	# Refresh all terminal visuals (which also triggers ServerBox updates via signals)
	for terminal in GameManager.node_terminals.values():
		terminal.update_visuals()

func _on_consensus_completed(_consensus_result):
	# Refresh all terminal visuals (which also triggers ServerBox updates via signals)
	for terminal in GameManager.node_terminals.values():
		terminal.update_visuals()

func refresh_all_server_boxes():
	"""Force all ServerBox instances to update their visuals."""
	var server_boxes = get_tree().get_nodes_in_group("server_boxes")
	for box in server_boxes:
		if box.has_method("update_visuals"):
			box.update_visuals()

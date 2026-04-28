extends Node
class_name NetworkConfig


@export var f_value: int = 1
@export var network_id: String = "default_network"

## Array of integers, each corresponding to initally crashed node id
@export var initially_crashed_nodes: Array[int] = []
## Array of integers, each corresponding to initally powered down node id
@export var initially_powered_off_nodes: Array[int] = []
## Array of integers, each corresponding to initially byzantine node id
@export var initially_byzantine_nodes: Array[int] = []

func _ready():
	add_to_group("network_config")

	await get_tree().process_frame

	NetworkManager.initialize_from_scene()

	# Apply initial node states after initialization
	for node_id in initially_crashed_nodes:
		var node = NetworkManager.get_network_node(node_id)
		if node:
			node.set_state(Enums.NodeState.ERROR)
			NetworkManager.node_state_changed.emit(node_id, Enums.NodeState.ONLINE, Enums.NodeState.ERROR)

	for node_id in initially_powered_off_nodes:
		var node = NetworkManager.get_network_node(node_id)
		if node:
			node.set_state(Enums.NodeState.OFFLINE)
			NetworkManager.node_state_changed.emit(node_id, Enums.NodeState.ONLINE, Enums.NodeState.OFFLINE)

	for node_id in initially_byzantine_nodes:
		var node = NetworkManager.get_network_node(node_id)
		if node:
			node.set_state(Enums.NodeState.COMPROMISED)
			NetworkManager.node_state_changed.emit(node_id, Enums.NodeState.ONLINE, Enums.NodeState.COMPROMISED)
	
	# Signal that everything is ready
	NetworkManager.all_nodes_ready.emit()
	print("[NetworkConfig] All nodes initialized and ready.")

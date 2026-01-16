extends Node
class_name NetworkConfig

@export var f_value: int = 1
@export var network_id: String = "default_network"
@export var initially_crashed_nodes: Array[int] = []  
@export var initially_powered_off_nodes: Array[int] = []  

func _ready():
	add_to_group("network_config")
	
	await get_tree().process_frame
	
	NetworkManager.initialize_from_scene()
	
	# Apply initial node states after initialization
	for node_id in initially_crashed_nodes:
		NetworkManager.crash_node(node_id)
	
	for node_id in initially_powered_off_nodes:
		var node = NetworkManager.get_network_node(node_id)
		if node:
			node.set_state(Enums.NodeState.CRASHED)

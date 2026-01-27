extends Interactable
class_name PowerButtonInteractable

var server: Server = null

func _ready():
	server = _find_server(get_parent())
	
	# Wait for all nodes to be ready
	await NetworkManager.all_nodes_ready
	
	_update_prompt()

func _find_server(node: Node) -> Server:
	if node is Server:
		return node
	if node.get_parent():
		return _find_server(node.get_parent())
	return null

func _on_interact(_player):
	if server:
		server.toggle_power()
		_update_prompt()
		# Force HUD to update immediately
		HUD.show_interaction_prompt(get_prompt())

func _update_prompt():
	if not server or not server.is_active:
		enabled = false
		if HUD:
			HUD.hide_interaction_prompt()
		return
	
	enabled = true
	
	# Check the server's power state directly
	var node = NetworkManager.get_network_node(server.node_id)
	if node and node.is_byzantine():
		# Byzantine nodes can't be interacted with
		enabled = false
		return
	
	# Use the server's power state for the prompt
	if server.get_power_state():
		prompt_text = "Press %s to Power Off"
	else:
		prompt_text = "Press %s to Power On"

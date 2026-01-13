# power_button_interactable.gd
extends Interactable
class_name PowerButtonInteractable

var server: Server = null

func _ready():
	server = _find_server(get_parent())
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
	if not server:
		enabled = false
		return
	
	enabled = true
	if server.get_power_state():
		prompt_text = "Press %s to Power Off"
	else:
		prompt_text = "Press %s to Power On"

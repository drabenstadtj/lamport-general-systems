extends Node3D
class_name NodeTerminal

@export var node_id: int = 0

@onready var status_light = $StatusLight
@onready var label = $SubViewport/Label

func _ready():
	label.text = "Node %d" % node_id
	
	# Register with GameManager 
	GameManager.register_node_terminal(node_id, self)

func update_visuals():
	print("update_visuals called for Node %d" % node_id)
	
	# Check if game is initialized
	if not GameManager.network_state:
		print("  -> network_state is null!")
		return
	
	var node = GameManager.network_state.get_node(node_id)
	if not node:
		print("  -> node is null!")
		return
	
	print("  -> Node %d state is: %s" % [node_id, node.state])
	
	match node.state:
		Enums.NodeState.HEALTHY:
			print("  -> Setting light to GREEN")
			status_light.light_color = Color.GREEN
			status_light.light_energy = 5.0
			label.modulate = Color.WHITE
		
		Enums.NodeState.CRASHED:
			print("  -> Setting light to BLACK (OFF)")
			status_light.light_color = Color.BLACK
			status_light.light_energy = 0.0
			label.modulate = Color.DARK_GRAY
		
		Enums.NodeState.BYZANTINE:
			print("  -> Setting light to RED")
			status_light.light_color = Color.RED
			status_light.light_energy = 5.0
			label.modulate = Color(1, 0.5, 0.5)

func _input(event):
	# Simple keyboard controls for testing
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				if Input.is_key_pressed(KEY_0 + node_id) or Input.is_key_pressed(KEY_KP_0 + node_id):
					reboot()
			KEY_C:
				if Input.is_key_pressed(KEY_0 + node_id) or Input.is_key_pressed(KEY_KP_0 + node_id):
					crash()
			KEY_X:
				if Input.is_key_pressed(KEY_0 + node_id) or Input.is_key_pressed(KEY_KP_0 + node_id):
					corrupt()

func reboot():
	print("Player rebooting Node %d" % node_id)
	GameManager.player_action(Enums.ActionType.REBOOT_NODE, node_id)
	
func crash():
	print("Player crashing Node %d" % node_id)
	GameManager.player_action(Enums.ActionType.CRASH_NODE, node_id)

func corrupt():
	print("Player corrupting Node %d" % node_id)
	GameManager.player_action(Enums.ActionType.CORRUPT_NODE, node_id)

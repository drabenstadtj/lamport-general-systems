extends Node
class_name ServerBox

@export var node_id: int = -1
@export var is_active: bool = false

@onready var status_light = $StatusLight

var node_terminal: NodeTerminal = null
var is_powered_on: bool = true

func _ready():
	add_to_group("server_boxes")
	
	if is_active and node_id >= 0:
		await get_tree().process_frame
		await get_tree().process_frame
		
		node_terminal = GameManager.get_node_terminal(node_id)
		if node_terminal:
			node_terminal.state_changed.connect(_on_state_changed)
			node_terminal.log_added.connect(_on_log_added)
			update_visuals()
			print("ServerBox: Node %d status light initialized" % node_id)
	else:
		if status_light:
			status_light.light_energy = 0.0
			status_light.visible = false

func update_visuals():
	if not GameManager.network_state:
		return
	
	var node = GameManager.network_state.get_node(node_id)
	if not node:
		return
	
	is_powered_on = (node.state != Enums.NodeState.CRASHED)
	
	match node.state:
		Enums.NodeState.HEALTHY:
			if status_light:
				status_light.visible = true
				status_light.light_color = Color.GREEN
				status_light.light_energy = 5.0
		Enums.NodeState.CRASHED:
			if status_light:
				status_light.visible = true
				status_light.light_color = Color.BLACK
				status_light.light_energy = 0.0
		Enums.NodeState.BYZANTINE:
			if status_light:
				status_light.visible = true
				status_light.light_color = Color.RED
				status_light.light_energy = 5.0

func _on_state_changed(new_state):
	update_visuals()

func _on_log_added(message: String):
	pass

func toggle_power() -> void:
	if is_powered_on:
		power_off()
	else:
		power_on()

func power_off() -> void:
	if not is_active or node_id < 0:
		return
	
	is_powered_on = false
	
	if not node_terminal:
		node_terminal = GameManager.get_node_terminal(node_id)
		if not node_terminal:
			return
	
	node_terminal.crash()
	await get_tree().process_frame
	update_visuals()

func power_on() -> void:
	if not is_active or node_id < 0:
		return
	
	is_powered_on = true
	
	if not node_terminal:
		node_terminal = GameManager.get_node_terminal(node_id)
		if not node_terminal:
			return
	
	node_terminal.reboot()
	await get_tree().process_frame
	update_visuals()

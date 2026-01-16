extends Node
class_name Server

@export var is_active: bool = false
@export var node_id: int = -1
@export var is_powered_on: bool = true

@onready var status_light = $StatusLight

func _ready():
	# If not active, turn off the light 
	if not is_active:
		if status_light:
			status_light.visible = false
			status_light.light_energy = 0.0
	else:
		add_to_group("server")
		
		# Wait for NetworkManager autoload to initialize
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Connect to the autoload
		NetworkManager.node_state_changed.connect(_on_node_state_changed)
		
		# Sync initial state
		sync_with_network_state()
		update_status_light()

func sync_with_network_state():
	var node = NetworkManager.get_network_node(node_id)
	if node:
		match node.state:
			Enums.NodeState.HEALTHY:
				is_powered_on = true
			Enums.NodeState.CRASHED:
				is_powered_on = false
			Enums.NodeState.BYZANTINE:
				is_powered_on = true
		
		update_status_light()

@warning_ignore("unused_parameter")
func _on_node_state_changed(changed_node_id: int, old_state: Enums.NodeState, new_state: Enums.NodeState):
	if changed_node_id != node_id:
		return
	
	match new_state:
		Enums.NodeState.HEALTHY:
			is_powered_on = true
		Enums.NodeState.CRASHED:
			is_powered_on = false
		Enums.NodeState.BYZANTINE:
			is_powered_on = true
	
	update_status_light()

func update_status_light():
	if not status_light:
		return
	
	if not is_active:
		status_light.visible = false
		status_light.light_energy = 0.0
		return
	
	status_light.visible = true
	
	# Use network state from autoload
	var node = NetworkManager.get_network_node(node_id)
	if node:
		match node.state:
			Enums.NodeState.HEALTHY:
				status_light.light_color = Color.GREEN
				status_light.light_energy = 5.0
			Enums.NodeState.CRASHED:
				status_light.light_color = Color.RED
				status_light.light_energy = 5.0
			Enums.NodeState.BYZANTINE:
				status_light.light_color = Color.YELLOW
				status_light.light_energy = 5.0
	else:
		# Fallback if node not found
		if is_powered_on:
			status_light.light_color = Color.GREEN
			status_light.light_energy = 5.0
		else:
			status_light.light_color = Color.RED
			status_light.light_energy = 5.0

func toggle_power():
	if not is_active:
		return
	
	# Toggle between crashed and healthy
	var node = NetworkManager.get_network_node(node_id)
	if node:
		if node.is_crashed():
			NetworkManager.reboot_node(node_id)
		elif node.is_healthy():
			NetworkManager.crash_node(node_id)

func get_power_state() -> bool:
	return is_powered_on

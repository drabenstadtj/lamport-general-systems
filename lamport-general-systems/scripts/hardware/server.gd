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
		
		# Wait for NetworkManager to be fully ready
		await NetworkManager.all_nodes_ready
		
		# Connect to state changes
		NetworkManager.node_state_changed.connect(_on_node_state_changed)
		
		# Sync initial state
		sync_with_network_state()
		update_status_light()
		
		# After syncing, update any power buttons
		await get_tree().process_frame
		var power_button = find_power_button()
		if power_button:
			power_button._update_prompt()

func sync_with_network_state():
	var node = NetworkManager.get_network_node(node_id)
	if node:
		match node.state:
			Enums.NodeState.HEALTHY:
				is_powered_on = true
			Enums.NodeState.CRASHED:
				is_powered_on = true
			Enums.NodeState.POWERED_DOWN:
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
			is_powered_on = true
		Enums.NodeState.POWERED_DOWN:
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
	
	var node = NetworkManager.get_network_node(node_id)
	if node:
		match node.state:
			Enums.NodeState.HEALTHY:
				status_light.light_color = Color.GREEN
				status_light.light_energy = 5.0
			Enums.NodeState.CRASHED:
				status_light.light_color = Color.RED
				status_light.light_energy = 5.0
			Enums.NodeState.POWERED_DOWN:
				status_light.light_color = Color.BLACK
				status_light.light_energy = 0.0  # Light is OFF
			Enums.NodeState.BYZANTINE:
				status_light.light_color = Color.YELLOW
				status_light.light_energy = 5.0
	else:
		# Fallback
		if is_powered_on:
			status_light.light_color = Color.GREEN
			status_light.light_energy = 5.0
		else:
			status_light.light_color = Color.BLACK
			status_light.light_energy = 0.0

func toggle_power():
	if not is_active:
		return
	
	var node = NetworkManager.get_network_node(node_id)
	if node:
		if node.is_powered_down():
			# Power on
			NetworkManager.power_on_node(node_id)
		elif node.is_crashed() or node.is_healthy():
			# Power off (turn it off n (maybe) turn it back on again)
			NetworkManager.power_off_node(node_id)

func find_power_button() -> PowerButtonInteractable:
	# Search children for PowerButtonInteractable
	for child in get_children():
		if child is PowerButtonInteractable:
			return child
		var result = _find_power_button_recursive(child)
		if result:
			return result
	return null

func _find_power_button_recursive(node: Node) -> PowerButtonInteractable:
	for child in node.get_children():
		if child is PowerButtonInteractable:
			return child
		var result = _find_power_button_recursive(child)
		if result:
			return result
	return null

func get_power_state() -> bool:
	return is_powered_on

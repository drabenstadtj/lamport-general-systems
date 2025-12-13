extends Node3D
class_name ServerBox

@export var node_id: int = -1
@export var is_active: bool = false

@onready var status_light = $StatusLight

var node_terminal: NodeTerminal = null

func _ready():
	if is_active and node_id >= 0:
		await get_tree().process_frame
		
		node_terminal = GameManager.get_node_terminal(node_id)
		if node_terminal:
			node_terminal.state_changed.connect(_on_state_changed)
			node_terminal.log_added.connect(_on_log_added)
			
			# Set initial state
			update_visuals()
	else:
		# Inactive node - turn off the light
		if status_light:
			status_light.light_energy = 0.0
			status_light.visible = false  # Optional: completely hide it

func update_visuals():
	if not GameManager.network_state:
		return

	var node = GameManager.network_state.get_node(node_id)
	if not node:
		return

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
	# Could display recent log on a small screen on the server box
	pass

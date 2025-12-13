extends Node3D
class_name ServerBox

@export var node_id: int = -1
@export var is_active: bool = false

@onready var status_light = $StatusLight
@onready var power_button_area = $PowerButton/PowerButtonArea if has_node("PowerButton/PowerButtonArea") else null

var node_terminal: NodeTerminal = null
var is_powered_on: bool = true  # Servers start powered on

func _ready():
	add_to_group("server_boxes")

	# Setup power button interaction
	if power_button_area:
		power_button_area.add_to_group("interactable")
		# Store reference to parent ServerBox for interaction
		power_button_area.set_meta("server_box", self)

	if is_active and node_id >= 0:
		# Wait for GameManager to be fully initialized
		await get_tree().process_frame
		await get_tree().process_frame

		node_terminal = GameManager.get_node_terminal(node_id)
		if node_terminal:
			node_terminal.state_changed.connect(_on_state_changed)
			node_terminal.log_added.connect(_on_log_added)

			# Set initial state
			update_visuals()
			print("ServerBox: Node %d status light initialized" % node_id)
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

	# Update is_powered_on based on node state
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
	# Could display recent log on a small screen on the server box
	pass

# ═══════════════════════════════════════════
# Power Button Interaction
# ═══════════════════════════════════════════

func interact(player) -> void:
	"""Called when player presses E on the power button."""
	if not is_active or node_id < 0:
		return

	toggle_power()

func toggle_power() -> void:
	"""Toggle the server power on/off."""
	if is_powered_on:
		power_off()
	else:
		power_on()

func power_off() -> void:
	"""Crash the node (simulates powering off)."""
	if not is_active or node_id < 0:
		return

	is_powered_on = false

	# Check if node_terminal exists
	if not node_terminal:
		node_terminal = GameManager.get_node_terminal(node_id)
		if not node_terminal:
			return

	# Use GameManager to crash the node
	node_terminal.crash()
	# Force immediate visual update
	await get_tree().process_frame
	update_visuals()

func power_on() -> void:
	"""Reboot the node (simulates powering on)."""
	if not is_active or node_id < 0:
		return

	is_powered_on = true

	# Check if node_terminal exists
	if not node_terminal:
		node_terminal = GameManager.get_node_terminal(node_id)
		if not node_terminal:
			return

	# Use GameManager to reboot the node
	node_terminal.reboot()
	# Force immediate visual update
	await get_tree().process_frame
	update_visuals()

func get_interaction_prompt() -> String:
	"""Return the prompt text to show when player looks at the power button."""
	if not is_active or node_id < 0:
		return ""

	if is_powered_on:
		return "[E] Power Off Node %d" % node_id
	else:
		return "[E] Power On Node %d" % node_id

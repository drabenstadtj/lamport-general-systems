extends Node3D
class_name Terminal

@onready var terminal_ui = $SubViewport/TerminalUI
@onready var interactable: Interactable = $Area3D/Interactable
@onready var camera_position_marker: Node3D = $CameraPosition
@onready var camera_lookat_marker: Node3D = $CameraLookAt

@export var default_node_id: int = -1  # Optional: auto-connect to this node on start

var is_being_viewed: bool = false
var network_manager: NetworkManager = null

func _ready():
	# Setup interactable
	if interactable:
		interactable.prompt_text = "Press %s to use Terminal"
		interactable.interacted.connect(_on_interacted)

	# Wait for NetworkManager
	await get_tree().process_frame

	network_manager = get_tree().get_first_node_in_group("network_manager")

	# Pass network manager to UI
	if terminal_ui and network_manager:
		terminal_ui.network_manager = network_manager

		# Auto-connect to default node if specified
		if default_node_id >= 0:
			var node = network_manager.get_network_node(default_node_id)
			if node:
				terminal_ui.controlled_node_id = default_node_id
				terminal_ui.connected_node = node
				terminal_ui.update_prompt()

func _on_interacted(player):
	if is_being_viewed:
		stop_viewing(player)
	else:
		start_viewing(player)

func start_viewing(player):
	is_being_viewed = true
	player.start_viewing_terminal(self)

	if terminal_ui:
		terminal_ui.accept_input = true

func stop_viewing(_player):
	is_being_viewed = false

	if terminal_ui:
		terminal_ui.accept_input = false

	if interactable:
		interactable.prompt_text = "Press %s to use Terminal"

func get_camera_position() -> Vector3:
	if camera_position_marker:
		return camera_position_marker.global_position
	return global_position + Vector3(0, 0.5, 0.25)

func get_look_at_position() -> Vector3:
	if camera_lookat_marker:
		return camera_lookat_marker.global_position
	return global_position + Vector3(0, 0.47, 0)

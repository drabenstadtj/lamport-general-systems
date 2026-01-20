extends Node3D
class_name Terminal

@onready var terminal_ui = $SubViewport/TerminalUI
@onready var interactable: Interactable = $Area3D/Interactable 
@onready var camera_position_marker: Node3D = $CameraPosition
@onready var camera_lookat_marker: Node3D = $CameraLookAt

@export var node_id: int = -1

var is_being_viewed: bool = false
var network_node: NetworkNode = null
var network_manager: NetworkManager = null

func _ready():
	# Setup interactable
	if interactable:
		interactable.prompt_text = "Press %s to use Terminal"
		interactable.interacted.connect(_on_interacted)
	
	# Wait for NetworkManager
	await get_tree().process_frame
	
	network_manager = get_tree().get_first_node_in_group("network_manager")
	if network_manager and node_id >= 0:
		network_node = network_manager.get_network_node(node_id)
		if network_node:
			network_node.state_changed.connect(_on_node_state_changed)
			network_node.message_sent.connect(_on_message_sent)
			network_node.message_received.connect(_on_message_received)
			network_node.vote_cast.connect(_on_vote_cast)
			network_node.decision_made.connect(_on_decision_made)
			
			if terminal_ui:
				terminal_ui.setup_network_context(node_id)

func _on_interacted(player):
	if is_being_viewed:
		stop_viewing(player)
	else:
		start_viewing(player)

func start_viewing(player):
	print("set being viewed to true")
	is_being_viewed = true
	player.start_viewing_terminal(self)
	
	if terminal_ui:
		terminal_ui.accept_input = true
	
	#if interactable:
		#interactable.prompt_text = "Press %s to exit Terminal"

func stop_viewing(_player):
	print("set being viewed to false")
	is_being_viewed = false
	
	if terminal_ui:
		terminal_ui.accept_input = false
	
	if interactable:
		print("setting prompt to use")
		interactable.prompt_text = "Press %s to use Terminal"

func get_camera_position() -> Vector3:
	if camera_position_marker:
		return camera_position_marker.global_position
	return global_position + Vector3(0, 0.5, 0.25)

func get_look_at_position() -> Vector3:
	if camera_lookat_marker:
		return camera_lookat_marker.global_position
	return global_position + Vector3(0, 0.47, 0)

# NetworkNode signal handlers

func _on_node_state_changed(_old_state: Enums.NodeState, new_state: Enums.NodeState):
	var state_name = _get_state_name(new_state, true)
	var plain_state_name = _get_state_name(new_state, false)
	
	if terminal_ui:
		var message = ">>> Node state changed to: %s" % state_name
		terminal_ui.print_to_terminal(message)
		
		var time = Time.get_ticks_msec() / 1000.0
		var timestamp = "%6.2f" % time
		terminal_ui.append_to_file("consensus.log", "[%s] >>> Node state changed to: %s" % [timestamp, plain_state_name])

func _on_message_sent(msg_type: String, target_id: int, _value):
	if terminal_ui:
		var message = "→ Sent %s to Node %d" % [msg_type, target_id]
		terminal_ui.print_to_terminal(message)
		terminal_ui.append_to_file("consensus.log", message)

func _on_message_received(msg_type: String, from_id: int, _value):
	if terminal_ui:
		var message = "← Received %s from Node %d" % [msg_type, from_id]
		terminal_ui.print_to_terminal(message)
		terminal_ui.append_to_file("consensus.log", message)

func _on_vote_cast(vote_value: Enums.VoteValue):
	if terminal_ui:
		var vote_name = "OPEN" if vote_value == Enums.VoteValue.OPEN else "LOCKED"
		var message = "Vote cast: %s" % vote_name
		terminal_ui.print_to_terminal(message)
		terminal_ui.append_to_file("consensus.log", message)

func _on_decision_made(decision: Enums.VoteValue):
	if terminal_ui:
		var decision_name = "OPEN" if decision == Enums.VoteValue.OPEN else "LOCKED"
		var message = "Decision: %s" % decision_name
		terminal_ui.print_to_terminal(message)
		terminal_ui.append_to_file("consensus.log", message)

func _get_state_name(state: Enums.NodeState, colored: bool = true) -> String:
	if colored:
		match state:
			Enums.NodeState.HEALTHY:
				return "[color=green]HEALTHY[/color]"
			Enums.NodeState.CRASHED:
				return "[color=red]CRASHED[/color]"
			Enums.NodeState.BYZANTINE:
				return "[color=yellow]BYZANTINE[/color]"
	else:
		match state:
			Enums.NodeState.HEALTHY:
				return "HEALTHY"
			Enums.NodeState.CRASHED:
				return "CRASHED"
			Enums.NodeState.BYZANTINE:
				return "BYZANTINE"
	return "UNKNOWN"

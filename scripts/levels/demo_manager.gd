extends Node

signal tutorial_step_completed(step_name: String)
signal tutorial_completed

enum TutorialStep {
	NONE,
	MOVE_AROUND,
	CROUCH,
	ZOOM,
	INTERACT_WITH_TERMINAL,
	RESTORE_NETWORK,
	COMPLETE
}

var current_step: TutorialStep = TutorialStep.NONE
var completed_steps: Array[TutorialStep] = []

@export var step_delay: float = 0.5
@export var final_message_duration: float = 2.0
@export var exit_door: DoubleDoors
@export var physical_server_id: int = 0
@export var terminal_server_id: int = 1

func _ready():
	add_to_group("tutorial_manager")

	if SaveManager.get_flag("tutorial_complete"):
		current_step = TutorialStep.COMPLETE
		return

	if NetworkManager:
		NetworkManager.node_state_changed.connect(_on_node_state_changed)
		NetworkManager.network_initialized.connect(_on_network_initialized, CONNECT_ONE_SHOT)

	start_tutorial()

func start_tutorial():
	current_step = TutorialStep.MOVE_AROUND
	if AIDirector.player:
		_last_pos = AIDirector.player.global_position
	show_step_hint("Use %s%s%s%s to move around" % [key("move_forward"), key("move_left"), key("move_backward"), key("move_right")])

func complete_step(step: TutorialStep):
	if step == current_step and step not in completed_steps:
		completed_steps.append(step)
		tutorial_step_completed.emit(TutorialStep.keys()[step])
		
		# Fade out current hint, wait, then show next
		if HUD:
			var tween = HUD.hide_tutorial_hint()
			if tween:
				await tween.finished
		
		await get_tree().create_timer(step_delay).timeout
		advance_to_next_step()

var _move_distance: float = 0.0
var _last_pos: Vector3
@export var move_required_distance: float = 3.0

func _process(_delta: float) -> void:
	if current_step == TutorialStep.MOVE_AROUND:
		var player := AIDirector.player
		if player:
			_move_distance += player.global_position.distance_to(_last_pos)
			_last_pos = player.global_position
			if _move_distance >= move_required_distance:
				complete_step(TutorialStep.MOVE_AROUND)

func _input(event: InputEvent) -> void:
	if current_step == TutorialStep.CROUCH and event.is_action_pressed("crouch"):
		complete_step(TutorialStep.CROUCH)
	elif current_step == TutorialStep.ZOOM and event.is_action_pressed("zoom"):
		complete_step(TutorialStep.ZOOM)

func advance_to_next_step():
	match current_step:
		TutorialStep.MOVE_AROUND:
			current_step = TutorialStep.CROUCH
			show_step_hint("Hold %s to crouch and move quietly" % key("crouch"))
		TutorialStep.CROUCH:
			current_step = TutorialStep.ZOOM
			show_step_hint("Press %s to zoom" % key("zoom"))
		TutorialStep.ZOOM:
			current_step = TutorialStep.INTERACT_WITH_TERMINAL
			show_step_hint("Press %s to interact with terminals" % key("interact"))
		TutorialStep.INTERACT_WITH_TERMINAL:
			current_step = TutorialStep.RESTORE_NETWORK
			show_step_hint("The servers are offline. Get the network back up.")
		TutorialStep.RESTORE_NETWORK:
			current_step = TutorialStep.COMPLETE
			complete_tutorial()

func complete_tutorial():
	tutorial_completed.emit()
	SaveManager.set_flag("tutorial_complete", true)
	SaveManager.save()
	if exit_door:
		exit_door.unlock()

	if HUD:
		await HUD.show_final_tutorial_hint("Demo Complete!", final_message_duration)

	HUD.hide_tutorial_hint()

func show_step_hint(text: String):
	if HUD:
		HUD.show_tutorial_hint(text)

func key(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.as_text_physical_keycode()
	return action

func _on_network_initialized() -> void:
	NetworkManager.power_off_node(physical_server_id)
	NetworkManager.power_off_node(terminal_server_id)

var _restored_servers: Array[int] = []

func _on_node_state_changed(node_id: int, _old: Enums.NodeState, new_state: Enums.NodeState) -> void:
	if current_step != TutorialStep.RESTORE_NETWORK or new_state != Enums.NodeState.HEALTHY:
		return
	if node_id in [physical_server_id, terminal_server_id] and node_id not in _restored_servers:
		_restored_servers.append(node_id)
	if _restored_servers.has(physical_server_id) and _restored_servers.has(terminal_server_id):
		complete_step(TutorialStep.RESTORE_NETWORK)

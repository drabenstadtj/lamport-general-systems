extends Node

signal tutorial_step_completed(step_name: String)
signal tutorial_completed

enum TutorialStep {
	NONE,
	MOVE_AROUND,
	ZOOM,
	INTERACT_WITH_TERMINAL,
	POWER_ON_SERVERS,
	COMPLETE
}

var current_step: TutorialStep = TutorialStep.NONE
var completed_steps: Array[TutorialStep] = []
@export var step_delay: float = 0.5  # Delay between steps

# Track server states
var servers_healthy: Dictionary = {
	0: false,
	1: false
}

func _ready():
	add_to_group("tutorial_manager")
	
	# Connect to NetworkManager signals
	if NetworkManager:
		NetworkManager.node_state_changed.connect(_on_node_state_changed)
	
	start_tutorial()

func _input(event: InputEvent):
	# Reset demo with Ctrl+R
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and event.ctrl_pressed:
			reset_demo()

func reset_demo():
	print("Resetting demo...")
	get_tree().reload_current_scene()

func start_tutorial():
	current_step = TutorialStep.MOVE_AROUND
	show_step_hint("Use WASD to move around")

func complete_step(step: TutorialStep):
	if step == current_step and step not in completed_steps:
		completed_steps.append(step)
		tutorial_step_completed.emit(TutorialStep.keys()[step])
		
		# Fade out current hint, wait, then show next
		if HUD:
			HUD.hide_tutorial_hint()
		
		await get_tree().create_timer(step_delay).timeout
		advance_to_next_step()

func advance_to_next_step():
	match current_step:
		TutorialStep.MOVE_AROUND:
			current_step = TutorialStep.ZOOM  
			show_step_hint("Press F to zoom") 
		TutorialStep.ZOOM:
			current_step = TutorialStep.INTERACT_WITH_TERMINAL
			show_step_hint("Press E to interact with terminals")
		TutorialStep.INTERACT_WITH_TERMINAL:
			current_step = TutorialStep.POWER_ON_SERVERS
			show_step_hint("Power on both Server 1 and Server 2")
		TutorialStep.POWER_ON_SERVERS:
			current_step = TutorialStep.COMPLETE
			show_step_hint("Demo Complete!")  
			tutorial_completed.emit()

func show_step_hint(text: String):
	if HUD:
		HUD.show_tutorial_hint(text)

# Check if both nodes 0 and 1 are healthy
func _on_node_state_changed(node_id: int, old_state: Enums.NodeState, new_state: Enums.NodeState):
	if current_step != TutorialStep.POWER_ON_SERVERS:
		return
	
	# Only track nodes 0 and 1
	if node_id != 0 and node_id != 1:
		return
	
	# Update the tracked state
	servers_healthy[node_id] = (new_state == Enums.NodeState.HEALTHY)
	
	print("Server %d state changed to %s (healthy=%s)" % [node_id, Enums.NodeState.keys()[new_state], servers_healthy[node_id]])
	print("Current healthy status - Server 0: %s, Server 1: %s" % [servers_healthy[0], servers_healthy[1]])
	
	# Check if BOTH are healthy
	if servers_healthy[0] and servers_healthy[1]:
		print("Both servers are healthy! Completing tutorial...")
		complete_step(TutorialStep.POWER_ON_SERVERS)

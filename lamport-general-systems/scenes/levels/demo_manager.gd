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
		NetworkManager.security_level_changed.connect(_on_security_level_changed)
	
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

func _on_security_level_changed(old_level: Enums.SecurityLevel, new_level: Enums.SecurityLevel):
	if current_step != TutorialStep.POWER_ON_SERVERS:
		return
	
	print("[Tutorial] Security level changed: %s -> %s" % [Enums.SecurityLevel.keys()[old_level], Enums.SecurityLevel.keys()[new_level]])
	
	# Complete tutorial when reaching MAINTENANCE level (level 1)
	if new_level == Enums.SecurityLevel.MAINTENANCE:
		print("[Tutorial] Reached MAINTENANCE level! Completing tutorial...")
		complete_step(TutorialStep.POWER_ON_SERVERS)

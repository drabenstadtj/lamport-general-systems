class_name StateMachine
extends Node

var current_state: State
var states: Dictionary = {}

@export var initial_state: State

func _ready() -> void:
	# Gather all child nodes that are states
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.player = owner  # Pass reference to the player
	
	# Start with initial state
	if initial_state:
		current_state = initial_state
		current_state.enter()

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func transition_to(state_name: String) -> void:
	var new_state = states.get(state_name.to_lower())
	
	if !new_state:
		push_warning("State " + state_name + " does not exist!")
		return
	
	if new_state == current_state:
		return
	
	if current_state:
		current_state.exit()
	
	current_state = new_state
	current_state.enter()
	print("Transitioned to: " + state_name)

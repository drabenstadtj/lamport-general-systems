class_name State
extends Node

# Reference to the player (or whatever entity owns this state)
var player: CharacterBody3D  # Change to CharacterBody2D if using 2D

func enter() -> void:
	# Called when entering this state
	pass

func exit() -> void:
	# Called when exiting this state
	pass

func update(delta: float) -> void:
	# Called every frame (from _process)
	pass

func physics_update(delta: float) -> void:
	# Called every physics frame (from _physics_process)
	pass

func handle_input(event: InputEvent) -> void:
	# Called when input events occur
	pass

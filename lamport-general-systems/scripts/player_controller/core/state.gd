class_name State
extends Node

# Reference to the player
var player: CharacterBody3D 

func enter() -> void:
	# Called when entering this state
	pass

func exit() -> void:
	# Called when exiting this state
	pass

func update(_delta: float) -> void:
	# Called every frame (from _process)
	pass

func physics_update(_delta: float) -> void:
	# Called every physics frame (from _physics_process)
	pass

func handle_input(_event: InputEvent) -> void:
	# Called when input events occur
	pass

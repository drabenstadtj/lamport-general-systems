@tool
extends Node3D

@export var light_color: Color = Color(0.941, 1.0, 0.824, 1.0):
	set(value):
		light_color = value
		update_light()

@export var light_energy: float = .25:
	set(value):
		light_energy = value
		update_light()

func _ready():
	update_light()

func update_light():
	if not has_node("OmniLight3D"):
		return
	
	var light = get_node("OmniLight3D") as OmniLight3D
	if light:
		light.light_color = light_color
		light.light_energy = light_energy

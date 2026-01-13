# hud.gd
extends CanvasLayer

@onready var interaction_prompt = $InteractionPrompt

func _ready():
	hide_interaction_prompt()
	
func show_interaction_prompt(text: String):
	interaction_prompt.text = text
	interaction_prompt.visible = true

func hide_interaction_prompt():
	interaction_prompt.visible = false

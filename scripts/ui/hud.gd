# hud.gd
extends CanvasLayer

@onready var interaction_prompt = $InteractionPrompt
@onready var demo_prompt: Label = $DemoPrompt 
@onready var control_prompt: Label = $MarginContainer/ControlPrompt

@export var fade_duration: float = 0.5

var current_demo_tween: Tween = null

func _ready():
	hide_interaction_prompt()
	# Set demo_prompt to fully transparent initially
	if demo_prompt:
		demo_prompt.modulate.a = 0.0
	
func show_interaction_prompt(text: String):
	interaction_prompt.text = text
	interaction_prompt.visible = true

func hide_interaction_prompt():
	interaction_prompt.visible = false

func show_tutorial_hint(text: String) -> Tween:
	if not demo_prompt:
		return null
	
	# If text is empty, fade out
	if text == "":
		hide_tutorial_hint()
		return current_demo_tween
	
	# Kill existing tween
	if current_demo_tween:
		current_demo_tween.kill()
	
	# Set text and make visible
	demo_prompt.text = text
	demo_prompt.visible = true
	
	# Fade in
	current_demo_tween = create_tween()
	current_demo_tween.tween_property(demo_prompt, "modulate:a", 1.0, fade_duration)
	return current_demo_tween

func hide_tutorial_hint() -> Tween:
	if not demo_prompt:
		return null
	
	# Kill existing tween
	if current_demo_tween:
		current_demo_tween.kill()
	
	# Fade out
	current_demo_tween = create_tween()
	current_demo_tween.tween_property(demo_prompt, "modulate:a", 0.0, fade_duration)
	# Hide after fade completes
	current_demo_tween.tween_callback(func(): demo_prompt.visible = false)
	return current_demo_tween

# Use this for the final tutorial step
func show_final_tutorial_hint(text: String, display_duration: float = 2.0) -> Signal:
	if not demo_prompt:
		return Signal()
	
	# Kill existing tween
	if current_demo_tween:
		current_demo_tween.kill()
	
	# Set text and make visible
	demo_prompt.text = text
	demo_prompt.visible = true
	
	# Fade in, wait, then fade out
	current_demo_tween = create_tween()
	current_demo_tween.tween_property(demo_prompt, "modulate:a", 1.0, fade_duration)
	current_demo_tween.tween_interval(display_duration)
	current_demo_tween.tween_property(demo_prompt, "modulate:a", 0.0, fade_duration)
	current_demo_tween.tween_callback(func(): demo_prompt.visible = false)
	
	return current_demo_tween.finished

func show_control_prompt(text: String):
	if control_prompt:
		control_prompt.text = text
		control_prompt.visible = text != ""

func hide_control_prompt():
	if control_prompt:
		control_prompt.visible = false

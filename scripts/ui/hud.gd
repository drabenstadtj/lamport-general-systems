# hud.gd
extends CanvasLayer

@onready var interaction_prompt = $InteractionPrompt
@onready var demo_prompt: Label = $DemoPrompt 
@onready var control_prompt: Label = $MarginContainer/ControlPrompt
@onready var cursor: ColorRect = $Cursor
@export var fade_duration: float = 0.5
@onready var rect = $DamageEffects

var current_demo_tween: Tween = null
var _desat_tween: Tween = null
var _fade_overlay: ColorRect = null
var _fade_tween: Tween = null

func _ready():
	add_to_group("hud")
	hide_interaction_prompt()
	if demo_prompt:
		demo_prompt.modulate.a = 0.0
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color.BLACK
	_fade_overlay.modulate.a = 0.0
	_fade_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)
	
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
		
func disable_cursor():
	cursor.visible = false
	
func enable_cursor():
	cursor.visible = true

func update_health(hits_remaining: int, max_hits: int) -> void:
	var target := 1.0 - (float(hits_remaining) / float(max_hits))
	if _desat_tween:
		_desat_tween.kill()
	_desat_tween = create_tween()
	var current := float(rect.material.get_shader_parameter("desaturate"))
	_desat_tween.tween_method(set_desaturation, current, target, 0.3)

func set_desaturation(amount: float):
	rect.material.set_shader_parameter("desaturate", amount)

func fade_to_black(duration: float = 0.5) -> Signal:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_overlay, "modulate:a", 1.0, duration)
	return _fade_tween.finished

func fade_from_black(duration: float = 0.5) -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_overlay, "modulate:a", 0.0, duration)

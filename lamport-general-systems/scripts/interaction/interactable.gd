extends Node
class_name Interactable

signal interacted(player)

@export var prompt_text: String = "Press %s to interact"
@export var enabled: bool = true

func interact(player):
	if enabled:
		emit_signal("interacted", player)
		_on_interact(player)

func _on_interact(_player):
	# override in child class
	pass

func get_prompt() -> String:
	var interact_key = _get_interact_key_name()
	return prompt_text % interact_key

func _get_interact_key_name() -> String:
	# Get the first event assigned to the "interact" action
	var events = InputMap.action_get_events("interact")
	if events.size() > 0:
		var event = events[0]
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
		elif event is InputEventMouseButton:
			return "Mouse " + str(event.button_index)
		elif event is InputEventJoypadButton:
			return "Button " + str(event.button_index)
	return "E"  # Fallback

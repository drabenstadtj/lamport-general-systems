extends Node
class_name Interactable

signal interacted(player)

@export var prompt_text: String = "Press %s to interact"
@export var enabled: bool = true
@export var require_facing: bool = false
@export var facing_direction: Vector3 = Vector3.FORWARD
@export_range(0, 180) var facing_angle: float = 90.0

func can_interact_from(position: Vector3) -> bool:
	if not require_facing:
		return true
	var parent_3d = get_parent() as Node3D
	if not parent_3d:
		return true
	var world_facing = parent_3d.global_transform.basis * facing_direction
	var to_position = (position - parent_3d.global_position).normalized()
	var angle = rad_to_deg(world_facing.angle_to(to_position))
	return angle <= facing_angle

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

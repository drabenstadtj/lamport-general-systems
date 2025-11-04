extends Node3D
class_name Door

@onready var door_panel = $DoorPanel
@onready var status_light = $StatusLight
@onready var status_label = $StatusLabel

var is_open: bool = false
var target_position: Vector3
var opening_speed: float = 2.0
var closed_position: Vector3

func _ready():
	# Register with GameManager
	GameManager.register_door(self)
	
	# Store the door's initial position as closed position
	closed_position = door_panel.position
	target_position = closed_position
	
	update_visuals(Enums.VoteValue.LOCKED)

func _process(delta):
	# Smoothly animate door panel position
	if door_panel.position.distance_to(target_position) > 0.01:
		door_panel.position = door_panel.position.lerp(target_position, opening_speed * delta)

func update_state(door_state: Enums.VoteValue):
	update_visuals(door_state)

func update_visuals(door_state: Enums.VoteValue):
	if door_state == Enums.VoteValue.OPEN:
		open_door()
	else:
		close_door()

func open_door():
	if is_open:
		return
	
	is_open = true
	
	# Slide and scale down
	target_position = closed_position + Vector3(-1.1, 0, 0)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(door_panel, "scale", Vector3(0.1, 1.0, 1.0), 0.8)
	
	status_light.light_color = Color.GREEN
	status_label.text = "OPEN"
	status_label.modulate = Color.GREEN

func close_door():
	if not is_open:
		return
	
	is_open = false
	
	target_position = closed_position
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(door_panel, "scale", Vector3(1.0, 1.0, 1.0), 0.8)
	
	status_light.light_color = Color.RED
	status_label.text = "LOCKED"
	status_label.modulate = Color.RED

func can_command() -> bool:
	return GameManager.network_state.current_level == Enums.SecurityLevel.MAINTENANCE

func can_exploit() -> bool:
	return GameManager.consensus_engine.failsafe_active

func get_status_text() -> String:
	var level_name = ["", "MAINTENANCE", "NORMAL", "DEFENSIVE"][GameManager.network_state.current_level]
	var state = "OPEN" if is_open else "LOCKED"
	
	var status = "Door: %s | Level: %s" % [state, level_name]
	
	if can_command():
		status += "\n[O] Command Door Open"
	elif can_exploit():
		status += "\n[E] Exploit Door (Failsafe Active)"
	else:
		status += "\nReach Maintenance level to command door"
		status += "\nOR trigger failsafe to exploit"
	
	return status

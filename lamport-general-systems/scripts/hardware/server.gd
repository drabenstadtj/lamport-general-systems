extends Node
class_name Server

@export var is_active: bool = false
@export var node_id: int = -1
@export var is_powered_on: bool = true

@onready var status_light = $StatusLight

func _ready():
	# If not active, turn off the light completely
	if not is_active:
		if status_light:
			status_light.visible = false
			status_light.light_energy = 0.0
	else:
		update_status_light()

func update_status_light():
	if not status_light:
		return
	
	status_light.visible = true
	
	if is_powered_on:
		status_light.light_color = Color.GREEN
		status_light.light_energy = 5.0
	else:
		status_light.light_color = Color.RED
		status_light.light_energy = 5.0

func toggle_power():
	if not is_active:  # Can't toggle inactive servers
		return
		
	is_powered_on = !is_powered_on
	update_status_light()

func get_power_state() -> bool:
	return is_powered_on

# door_interactable.gd
extends Interactable
class_name DoorInteractable

@export var open_angle: float = 90.0
@export var open_duration: float = 1.0
@export var auto_close: bool = false
@export var auto_close_delay: float = 3.0

var is_open: bool = false
var initial_rotation: Vector3

func _ready():
	var parent = get_parent()
	if parent:
		initial_rotation = parent.rotation_degrees

func _on_interact(_player):
	toggle_door()

func toggle_door():
	is_open = !is_open
	var parent = get_parent().get_parent()
	if not parent is Node3D:
		return
	
	var target = initial_rotation + (Vector3(0, open_angle, 0) if is_open else Vector3.ZERO)
	var tween = create_tween()
	tween.tween_property(parent, "rotation_degrees", target, open_duration)
	
	if is_open and auto_close:
		await get_tree().create_timer(auto_close_delay).timeout
		if is_open:  # Check again in case player closed it
			toggle_door()

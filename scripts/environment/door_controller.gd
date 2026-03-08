extends Node3D
var is_open: bool = false

func _ready() -> void:
	if not get_parent() is DoubleDoors:
		add_to_group("door")
	for body in find_children("*", "StaticBody3D", true, false):
		body.add_to_group("door_body")
@export var rotation_deg: float = 90
@export var open_time: float = 0.5
@export var locked: bool = false

func unlock() -> void:
	locked = false

func open() -> float:
	if is_open:
		return 0.0
	_open()
	return open_time

@onready var _nav_obstacle: NavigationObstacle3D = get_node_or_null("NavigationObstacle3D")

func _open() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "rotation", Vector3(0.0, deg_to_rad(rotation_deg), 0.0), open_time)
	is_open = true
	if _nav_obstacle:
		_nav_obstacle.avoidance_enabled = true

func _on_interactable_interacted(_player: Variant) -> void:
	if locked:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	if is_open:
		tween.tween_property(self, "rotation", Vector3(0.0, 0.0, 0.0), open_time)
		if _nav_obstacle:
			_nav_obstacle.avoidance_enabled = false
	else:
		tween.tween_property(self, "rotation", Vector3(0.0, deg_to_rad(rotation_deg), 0.0), open_time)
		if _nav_obstacle:
			_nav_obstacle.avoidance_enabled = true
	is_open = !is_open

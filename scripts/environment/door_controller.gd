extends Node3D
var is_open: bool = false
@export var rotation_deg: float = 80
@export var open_time: float = 0.5
@export var locked: bool = false

func unlock() -> void:
	locked = false


func _open() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "rotation", Vector3(0.0, deg_to_rad(rotation_deg), 0.0), open_time)
	is_open = true

func _on_interactable_interacted(_player: Variant) -> void:
	if locked:
		return
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	if is_open:
		tween.tween_property(self, "rotation", Vector3(0.0, 0.0, 0.0), open_time)
	else:
		tween.tween_property(self, "rotation", Vector3(0.0, deg_to_rad(rotation_deg), 0.0), open_time)
	is_open = !is_open

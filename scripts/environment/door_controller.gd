extends Node3D
var is_open: bool = false
@export var rotation_deg: float = 80
@export var open_time: float = 0.5

func _on_interactable_interacted(player: Variant) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)  
	
	if is_open:
		# Tween to zero rotation
		tween.tween_property(self, "rotation", Vector3(0.0, 0.0, 0.0), open_time)
	else:
		# Tween to rotation_deg
		tween.tween_property(self, "rotation", Vector3(0.0, deg_to_rad(rotation_deg), 0.0), open_time)		
	
	is_open = !is_open

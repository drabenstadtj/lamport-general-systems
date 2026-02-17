extends Node3D
@export var rotation_deg: float = 45

func _on_interactable_interacted(player: Variant) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)  
	
	# Tween to zero rotation
	# Tween to rotation_deg
	tween.tween_property(self, "rotation", Vector3(deg_to_rad(rotation_deg), 0.0 , 0.0), .2)		
	tween.tween_property(self, "rotation", Vector3(0.0, 0.0, 0.0), .4)

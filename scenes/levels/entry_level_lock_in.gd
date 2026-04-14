extends Area3D

@export var doors: DoubleDoors

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		doors.close()
		doors.lock()
		queue_free()  

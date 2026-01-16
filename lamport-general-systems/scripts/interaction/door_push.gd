extends Area3D

@onready var door_body = get_parent() as RigidBody3D
@export var push_force: float = 5.0

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("PLAYER DETECTED!")
		# Apply force to door
		var push_dir = (door_body.global_position - body.global_position).normalized()
		door_body.apply_central_impulse(push_dir * push_force)

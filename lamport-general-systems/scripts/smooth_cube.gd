extends Node3D

@onready var cube: MeshInstance3D = $MeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	cube.rotate(Vector3(0,1,0).normalized(), .001)

	#
#func _physics_process(delta: float) -> void:
	#cube.rotate(Vector3(0,1,0).normalized(), .1)

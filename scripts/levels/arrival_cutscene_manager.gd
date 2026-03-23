extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var car: Node3D = $Car

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.connect("animation_finished", Callable(self, "_on_animation_finished"))
	animation_player.play("ArrivalCutscene")

	

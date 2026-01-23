extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var car: Node3D = $Car

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.connect("animation_finished", Callable(self, "_on_animation_finished"))
	animation_player.play("ArrivalCutscene")

func _on_animation_finished(anim_name: String) -> void:
	var player = car.get_node_or_null("Player")
	if player:
		# Get the root node of the scene tree
		var root = get_tree().root
		# Reparent the player to the root node
		player.reparent(root)

extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var car: Node3D = $Car

func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play("ArrivalCutscene")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			_skip()

func _skip() -> void:
	animation_player.stop()
	var cutscene_cam := get_node_or_null("Cameras/Camera3D")
	if cutscene_cam:
		cutscene_cam.current = false
	_on_animation_finished("ArrivalCutscene")

func _on_animation_finished(_anim_name: String) -> void:
	pass # TODO: transition to gameplay (e.g. free cutscene, enable player, change scene)

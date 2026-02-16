extends Node3D

@onready var door1 = $Door1
@onready var door2 = $Door2
@onready var door1_open_pos = $Door1Open
@onready var door2_open_pos = $Door2Open
@onready var door1_closed_pos = $Door1Closed
@onready var door2_closed_pos = $Door2Closed


@export var destination_scene: PackedScene
@export var exit_side: SceneManager.DoorSide = SceneManager.DoorSide.DOOR2
@export var destination_dock: String = "Dock"

var door1_open: bool = true
var door2_open: bool = true

func _on_interactable_interacted(player: Variant) -> void:
	await lockdown()
	await SceneManager.change_scene(destination_scene, exit_side, destination_dock, self)
	
func lockdown():
	var tween = create_tween().set_parallel(true)
	if door1_open:
		tween.tween_property(door1, "position", door1_closed_pos.position, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		door1_open = false
	if door2_open:
		tween.tween_property(door2, "position", door2_closed_pos.position, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		door2_open = false
	await tween.finished

func open_side(side: SceneManager.DoorSide):
	var tween = create_tween()
	if side == SceneManager.DoorSide.DOOR1:
		tween.tween_property(door1, "position", door1_open_pos.position, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		door1_open = true
	else:
		tween.tween_property(door2, "position", door2_open_pos.position, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		door2_open = true
	await tween.finished

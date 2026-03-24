extends Node

@export var trigger_area: Area3D

var _triggered: bool = false

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	_end_playtest()

func _end_playtest() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud:
		return
	await hud.show_final_tutorial_hint("To be continued...", 5.0)
	await hud.fade_to_black(1.5)
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if _triggered and event.is_action_pressed("ui_cancel"):
		get_tree().quit()

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
	SaveManager.send_pda_message(
		"gpaulson@lgs.org",
		"Ripley Site Briefing",
"""Hello,

You should be reading this on your LGS FocusLink, which you will learn to use over the course of your work here.

Ripley Site has been closed for over 15 years following its emergency shutdown. The site runs on a legacy network architecture called Byzantine Fault Tolerance — BFT for short. In plain terms, every subsystem on site (doors, lighting, security) requires the servers controlling it to reach an agreement before anything happens. No consensus, no access.

As a legacy systems technician contracted through LGS, your job is to bring the site's subnetworks back online and restore operations.

From what we know, the main entrance was left unlocked during the last visit, so getting in shouldn't be a problem. Beyond that, you'll need to assess the situation on the ground.

Your contract is attached for reference.

Greg Paulson
Chief of Operations
Lamport General Systems"""
	)

	await get_tree().process_frame
	var player := AIDirector.player
	if player and player.has_method("open_pda"):
		player.open_pda()

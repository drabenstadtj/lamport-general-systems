extends Node3D

@onready var animation_player = $AnimationPlayer
@onready var audio_player = $AudioStreamPlayer3D
@export var enabled: bool = false
var is_talking = true

func _ready():
	audio_player.finished.connect(_on_audio_finished)
	animation_player.animation_finished.connect(_on_animation_finished)

func play_voiceline(audio_stream: AudioStream):
	if is_talking:
		return  # Don't interrupt current voiceline
	
	is_talking = true
	audio_player.stream = audio_stream
	audio_player.play()
	animation_player.play("DemoRobotLibrary/Talking")

func _on_audio_finished():
	is_talking = false
	animation_player.stop()

func _on_animation_finished(anim_name: String):
	if anim_name == "talking" and audio_player.playing:
		animation_player.play("DemoRobotLibrary/Talking")

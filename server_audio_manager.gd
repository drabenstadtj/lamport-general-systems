extends Node
class_name ServerAudioManager

# Audio streams
@export_group("Audio Streams")
@export var power_on_beep: AudioStream = preload("res://audio/server/server_powerup.mp3")
@export var power_off_beep: AudioStream = preload("res://audio/server/server_powerdown.mp3")
@export var hdd_spinup: AudioStream = preload("res://audio/server/harddrive_spinup.mp3")
@export var hdd_idle_sound: AudioStream = preload("res://audio/server/harddrive_idle.mp3")

@export_group("Idle Sound Settings")
@export var num_idle_layers: int = 3
@export var idle_fade_duration: float = 3.0
@export var idle_min_duration: float = 8.0
@export var idle_max_duration: float = 20.0
@export var idle_min_silence: float = 2.0
@export var idle_max_silence: float = 8.0
@export var idle_volume_variation: float = 3.0

# Internal state
var idle_players: Array[AudioStreamPlayer3D] = []
var idle_active: bool = false
var is_transitioning: bool = false
var spinup_player_ref: AudioStreamPlayer3D = null
var server_position: Vector3 = Vector3.ZERO
var should_start_idle: bool = false

func _ready():
	# Get parent's position
	var parent = get_parent()
	if parent is Node3D:
		server_position = parent.global_position
	
	# Wait one frame for AudioManager to finish setup
	await get_tree().process_frame
	
	# If we were told to start idle during initialization, do it now
	if should_start_idle:
		start_idle_system()
		should_start_idle = false

# Call this to update position if server moves
func update_position(pos: Vector3):
	server_position = pos

func play_power_on_sequence():
	# Cancel any ongoing transition
	if is_transitioning:
		print("[ServerAudio] Interrupting previous power sequence")
		stop_idle_system()
		if spinup_player_ref and is_instance_valid(spinup_player_ref):
			spinup_player_ref.stop()
	
	is_transitioning = true
	print("[ServerAudio] Starting power on sequence")
	
	# Power up beep
	if power_on_beep:
		AudioManager.play_sound_3d_priority(power_on_beep, server_position)
	
	# Small delay
	await get_tree().create_timer(0.05).timeout
	
	# HDD spin up
	if hdd_spinup:
		spinup_player_ref = AudioManager.play_sound_3d_priority(hdd_spinup, server_position)
		if spinup_player_ref:
			await spinup_player_ref.finished
			spinup_player_ref = null
	
	# Start idle system
	start_idle_system()
	is_transitioning = false
	print("[ServerAudio] Power on sequence complete")

func play_power_off_sequence():
	# Cancel any ongoing transition
	if is_transitioning:
		print("[ServerAudio] Interrupting previous power sequence")
		if spinup_player_ref and is_instance_valid(spinup_player_ref):
			spinup_player_ref.stop()
	
	is_transitioning = true
	print("[ServerAudio] Starting power off sequence")
	
	# Stop idle sound immediately
	stop_idle_system()
	
	await get_tree().create_timer(0.1).timeout
	
	# Power down beep
	if power_off_beep:
		AudioManager.play_sound_3d_priority(power_off_beep, server_position)
	
	is_transitioning = false
	print("[ServerAudio] Power off sequence complete")

func start_idle_system():
	if not is_inside_tree():
		should_start_idle = true
		return
		
	if not hdd_idle_sound:
		return
	
	idle_active = true
	idle_players.clear()
	
	print("[ServerAudio] Starting idle system with ", num_idle_layers, " layers")
	
	# Start multiple layers with random offsets
	for i in range(num_idle_layers):
		var start_delay = randf_range(0.0, idle_max_duration * 0.5)
		_start_idle_layer(start_delay)

func stop_idle_system():
	print("[ServerAudio] Stopping idle system, active players: ", idle_players.size())
	idle_active = false
	
	# Immediately stop all players
	for player in idle_players:
		if is_instance_valid(player):
			player.stop()
	
	idle_players.clear()

func _start_idle_layer(initial_delay: float = 0.0):
	if not idle_active:
		return
	
	# Wait before starting this layer
	if initial_delay > 0:
		await get_tree().create_timer(initial_delay).timeout
	
	if not idle_active:
		return
	
	# Create and start player silently
	var random_volume = randf_range(-idle_volume_variation, idle_volume_variation)
	var player = AudioManager.play_sound_3d(hdd_idle_sound, server_position, -80.0)
	
	if not player:
		# If no player available, try again later
		await get_tree().create_timer(2.0).timeout
		if idle_active:
			_start_idle_layer()
		return
	
	idle_players.append(player)
	
	# Fade in
	var tween = create_tween()
	tween.tween_property(player, "volume_db", random_volume, idle_fade_duration)
	await tween.finished
	
	if not idle_active or not is_instance_valid(player):
		return
	
	# Play for random duration
	var play_duration = randf_range(idle_min_duration, idle_max_duration)
	await get_tree().create_timer(play_duration).timeout
	
	if not idle_active or not is_instance_valid(player):
		return
	
	# Fade out
	tween = create_tween()
	tween.tween_property(player, "volume_db", -80.0, idle_fade_duration)
	await tween.finished
	
	if is_instance_valid(player):
		player.stop()
		idle_players.erase(player)
	
	if not idle_active:
		return
	
	# Wait random silence period before restarting this layer
	var silence_duration = randf_range(idle_min_silence, idle_max_silence)
	await get_tree().create_timer(silence_duration).timeout
	
	if idle_active:
		_start_idle_layer()

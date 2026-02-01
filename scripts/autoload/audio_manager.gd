extends Node

const MAX_PLAYERS_3D = 30
const PRIORITY_PLAYERS = 5

var player_pool_2d: Array[AudioStreamPlayer] = []
var player_pool_3d: Array[AudioStreamPlayer3D] = []
var priority_pool_3d: Array[AudioStreamPlayer3D] = []

func _ready():
	_create_audio_players()

func _create_audio_players():
	# Pre-create 2D players
	for i in range(10):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		player_pool_2d.append(player)
	
	# Pre-create 3D players
	for i in range(MAX_PLAYERS_3D):
		var player = AudioStreamPlayer3D.new()
		player.bus = "Master"
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 1.0
		player.max_distance = 50.0
		add_child(player)
		player_pool_3d.append(player)
	
	# Pre-create priority players
	for i in range(PRIORITY_PLAYERS):
		var player = AudioStreamPlayer3D.new()
		player.bus = "Master"
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 1.0
		player.max_distance = 50.0
		add_child(player)
		priority_pool_3d.append(player)
	
	print("AudioManager: Created ", player_pool_3d.size(), " 3D players")

# For UI/non-positional sounds
func play_sound(stream: AudioStream, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not stream:
		return null
	
	for player in player_pool_2d:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return player
	
	push_warning("All 2D audio players busy")
	return null

# For 3D positional sounds
func play_sound_3d(stream: AudioStream, position: Vector3, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	if not stream:
		return null
	
	for player in player_pool_3d:
		if not player.playing:
			player.stream = stream
			player.global_position = position
			player.volume_db = volume_db
			player.play()
			return player
	
	push_warning("All 3D audio players busy")
	return null

# For priority sounds (beeps, one-shots)
func play_sound_3d_priority(stream: AudioStream, position: Vector3, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	if not stream:
		return null
	
	# Find available priority player
	for player in priority_pool_3d:
		if not player.playing:
			player.stream = stream
			player.global_position = position
			player.volume_db = volume_db
			player.play()
			return player
	
	# If all priority players busy, interrupt the oldest one
	var oldest_player = priority_pool_3d[0]
	oldest_player.stop()
	oldest_player.stream = stream
	oldest_player.global_position = position
	oldest_player.volume_db = volume_db
	oldest_player.play()
	return oldest_player

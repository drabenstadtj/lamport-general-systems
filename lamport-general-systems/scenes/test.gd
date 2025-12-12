extends Node3D

@onready var status_label = $CanvasLayer/StatusLabel

func _ready():
	# Initialize the game
	GameManager.initialize_game(1)
	
	# Connect to signals
	GameManager.turn_completed.connect(_on_turn_completed)
	GameManager.game_won.connect(_on_game_won)
	
	# Initial status update
	update_status()
	
	print("\n=== CONTROLS ===")
	print("Hold number key (0-2) and press:")
	print("  R = Reboot node")
	print("  C = Crash node")
	print("  X = Corrupt node")
	print("================\n")

func _on_turn_completed(turn_info):
	update_status()

func _on_game_won(path_type):
	status_label.text = "VICTORY: %s path!" % path_type.to_upper()
	status_label.add_theme_color_override("font_color", Color.GOLD)

func update_status():
	var status = GameManager.get_game_status()
	var consensus_state = GameManager.get_consensus_state()
	var health = GameManager.get_network_health()
	var level_name = ["", "MAINTENANCE", "NORMAL", "DEFENSIVE"][GameManager.network_manager.current_level]
	var door_state = "OPEN" if consensus_state.current_door_state == Enums.VoteValue.OPEN else "LOCKED"

	status_label.text = "Turn: %d | Level: %s | Door: %s | Healthy: %d | Crashed: %d | Byzantine: %d | Failed: %d/10" % [
		status.turn,
		level_name,
		door_state,
		health.healthy,
		health.crashed,
		health.byzantine,
		consensus_state.failed_rounds
	]

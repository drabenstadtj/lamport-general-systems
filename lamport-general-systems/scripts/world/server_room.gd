extends Node3D

@onready var status_label = $SubViewportContainer/SubViewport/CanvasLayer/StatusLabel
@export var f: int

func _ready():
	GameManager.initialize_game(f)
	refresh_all_terminals()
	GameManager.turn_completed.connect(_on_turn_completed)
	GameManager.game_won.connect(_on_game_won)
	update_status()

	print("\n=== CONTROLS ===")
	print("Node actions (hold number key 0-2):")
	print("  R = Reboot node")
	print("  C = Crash node")
	print("  X = Corrupt node")
	print("\nDoor actions:")
	print("  O = Command door OPEN (requires Maintenance level)")
	print("  E = Exploit door (requires failsafe active)")
	print("================\n")

func refresh_all_terminals():
	for terminal in GameManager.node_terminals.values():
		terminal.update_visuals()

func _on_turn_completed(_turn_info):
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

	var base_status = "Turn: %d | Level: %s | Door: %s | Healthy: %d | Crashed: %d | Byzantine: %d | Failed: %d/10" % [
		status["turn"],
		level_name,
		door_state,
		health.healthy,
		health.crashed,
		health.byzantine,
		consensus_state.failed_rounds
	]

	if GameManager.door_object:
		if GameManager.door_object.can_command():
			base_status += "\n[O] Command Door Open (Maintenance Mode)"
		elif GameManager.door_object.can_exploit():
			base_status += "\n[E] Exploit Door (Failsafe Active)"

	status_label.text = base_status

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_O:
				print("\n>>> Player commanding door OPEN")
				GameManager.player_action(Enums.ActionType.COMMAND_DOOR, -1, Enums.VoteValue.OPEN)
			#KEY_E:
				#print("\n>>> Player exploiting door")
				#GameManager.player_action(Enums.ActionType.EXPLOIT_DOOR)

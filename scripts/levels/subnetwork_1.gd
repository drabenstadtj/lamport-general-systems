extends Node3D

@export var exit_door: Node3D

func _ready() -> void:
	NetworkManager.game_won.connect(_on_game_won)
	SaveManager.send_pda_message("ADMIN", "Facility Shutdown", "All personnel must evacuate by 0600.")


func _on_game_won(_win_type: Variant) -> void:
	if exit_door:
		exit_door.unlock()
		exit_door._open()

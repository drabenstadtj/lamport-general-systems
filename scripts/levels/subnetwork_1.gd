extends Node3D

@export var exit_door: Node3D
@export var terminal: Terminal

func _ready() -> void:
	NetworkManager.game_won.connect(_on_game_won)
	SaveManager.send_pda_message("ADMIN", "Facility Shutdown", "All personnel must evacuate by 0600.")
	NetworkManager.network_initialized.connect(_inject_files, CONNECT_ONE_SHOT)

func _inject_files() -> void:
	if not terminal:
		return
	var user_dir = terminal.terminal_ui.local_filesystem["children"]["home"]["children"]["user"]["children"]
	user_dir["recovery.txt"] = {
		"type": "file",
		"read_only": true,
		"content": """NETWORK RECOVERY — SN1

If the network is LOCKED and doors won't respond:

  1. Check what's online:     status
  2. Get nodes back up:       connect <id>  then  reboot
                             (or use the physical power button on the rack)
  3. Once enough are online:  consensus OPEN

You need at least 3 nodes healthy before a consensus vote will go through.
Node 2 has been acting up — don't count on it.

Type 'help' for a full list of commands."""
	}


func _on_game_won(_win_type: Variant) -> void:
	if exit_door:
		exit_door.unlock()
		exit_door._open()

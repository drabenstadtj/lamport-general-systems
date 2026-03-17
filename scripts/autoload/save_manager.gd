extends Node

signal message_received(message: Dictionary)

const SAVE_PATH = "user://save.tres"
var current: SaveData = SaveData.new()

func save() -> void:
	current.current_level = AIDirector.level_path
	current.player_position = AIDirector.player.global_position
	current.player_rotation = AIDirector.player.global_rotation
	current.player_hits_remaining = AIDirector.player.damage_component.hits_remaining
	ResourceSaver.save(current, SAVE_PATH)

func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	current = ResourceLoader.load(SAVE_PATH) as SaveData
	return true

func apply_to_player() -> void:
	var player := AIDirector.player
	player.global_position = current.player_position
	player.global_rotation = current.player_rotation
	player.damage_component.restore(current.player_hits_remaining)

func send_pda_message(sender: String, subject: String, body: String) -> void:
	var msg := {
		"sender": sender,
		"subject": subject,
		"body": body,
		"timestamp": Time.get_unix_time_from_system(),
		"read": false,
	}
	current.pda_messages.append(msg)
	message_received.emit(msg)

func set_flag(key: String, value: Variant = true) -> void:
	current.flags[key] = value

func get_flag(key: String, default: Variant = false) -> Variant:
	return current.flags.get(key, default)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	current = SaveData.new()

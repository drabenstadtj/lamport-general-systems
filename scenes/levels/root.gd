extends Node

@export_file("*.tscn") var starting_level: String = ""

func _ready() -> void:
	if not starting_level.is_empty():
		await SceneManager.load_initial(starting_level)

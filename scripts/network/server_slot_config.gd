extends Resource
class_name ServerSlotConfig

func _init() -> void:
	resource_local_to_scene = true

@export var slot_index: int = -1 # -1: pick randomly
@export var is_active_node: bool = false
@export var node_id: int = -1
@export var custom_server_scene: PackedScene

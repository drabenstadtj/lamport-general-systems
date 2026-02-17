extends Node

var docks: Dictionary = {}
var spawned_transfer_rooms: Dictionary = {}  # dock_name -> transfer_room

func register_dock(dock_name: String, dock_node: Node3D) -> void:
	docks[dock_name] = dock_node
	print("Registered dock: ", dock_name)

func get_dock(dock_name: String) -> Node3D:
	return docks.get(dock_name, null)

func register_transfer_room(dock_name: String, transfer_room: Node3D) -> void:
	spawned_transfer_rooms[dock_name] = transfer_room

func has_transfer_room(dock_name: String) -> bool:
	return spawned_transfer_rooms.has(dock_name)

func clear() -> void:
	docks.clear()
	spawned_transfer_rooms.clear()

extends Node

var docks: Dictionary = {}
<<<<<<< Updated upstream
=======
var spawned_transfer_rooms: Dictionary = {}
>>>>>>> Stashed changes

func register_dock(dock_name: String, dock_node: Node3D) -> void:
	docks[dock_name] = dock_node.global_transform
	print("Registered dock: ", dock_name)

func get_dock(dock_name: String) -> Transform3D:
	return docks.get(dock_name, Transform3D())

func has_dock(dock_name: String) -> bool:
	return docks.has(dock_name)

func clear() -> void:
	docks.clear()

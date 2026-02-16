extends Node

var docks: Dictionary = {}

func register_dock(dock_name: String, dock_node: Node3D) -> void:
	docks[dock_name] = dock_node
	print("Registered dock: ", dock_name)

func get_dock(dock_name: String) -> Node3D:
	return docks.get(dock_name, null)

func clear() -> void:
	docks.clear()

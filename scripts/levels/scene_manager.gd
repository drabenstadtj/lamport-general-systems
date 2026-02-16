extends Node

enum DoorSide { 
	DOOR1, 
	DOOR2 
}

@onready var level_container = get_tree().root.get_node("Root/CurrentLevel")

func change_scene(dest_scene: PackedScene, side: DoorSide, dock_name: String, transfer_room: Node3D):
	var new_level = dest_scene.instantiate()
	
	transfer_room.get_parent().remove_child(transfer_room)
	level_container.add_child(transfer_room)
	
	for child in level_container.get_children():
		if child != transfer_room:
			child.queue_free()
	
	level_container.add_child(new_level)
	
	# align using the dock name from the export
	var room_dock: Node3D
	if side == DoorSide.DOOR1:
		room_dock = transfer_room.get_node("Door1Dock")
	else:
		room_dock = transfer_room.get_node("Door2Dock")
	
	var level_dock = new_level.get_node(dock_name)
	new_level.global_position += room_dock.global_position - level_dock.global_position
	
	await transfer_room.open_side(side)

extends Node

enum DoorSide { 
	DOOR1, 
	DOOR2 
}

func change_scene(dest_scene_path: String, side: DoorSide, dock_name: String, transfer_room: Node3D):
	var level_container = get_tree().root.get_node("Root/CurrentLevel")
	var player = get_tree().root.get_node("Root/Player")
	
	ResourceLoader.load_threaded_request(dest_scene_path)
	while ResourceLoader.load_threaded_get_status(dest_scene_path) != ResourceLoader.THREAD_LOAD_LOADED:
		await get_tree().process_frame
	
	var scene = ResourceLoader.load_threaded_get(dest_scene_path)
	var new_level = scene.instantiate()
	
	transfer_room.get_parent().remove_child(transfer_room)
	level_container.add_child(transfer_room)
	
	for child in level_container.get_children():
		if child != transfer_room:
			child.queue_free()
	
	await get_tree().process_frame
	
	level_container.add_child(new_level)
	
	# wait for docks to register
	await get_tree().process_frame
	
	var level_dock = DoorRegistry.get_dock(dock_name)
	if not level_dock:
		push_error("Dock not found: " + dock_name)
		return
	
	var door_dock: Node3D
	if side == DoorSide.DOOR1:
		door_dock = transfer_room.get_node("Door1Dock")
	else:
		door_dock = transfer_room.get_node("Door2Dock")
	
	# save player offset from transfer room before moving
	var player_local = transfer_room.global_transform.inverse() * player.global_transform
	
	var flip_angle = 0.0 if side == DoorSide.DOOR1 else PI
	transfer_room.global_rotation = Vector3(0, level_dock.global_rotation.y + flip_angle, 0)
	
	var offset = level_dock.global_position - door_dock.global_position
	transfer_room.global_position += offset
	
	player.global_transform = transfer_room.global_transform * player_local
	
	await transfer_room.open_side(side)

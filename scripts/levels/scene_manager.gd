extends Node

enum DoorSide { 
	DOOR1, 
	DOOR2 
}

func change_scene(dest_scene_path: String, side: DoorSide, dock_name: String, transfer_room: Node3D):
	if dest_scene_path.begins_with("uid://"):
		dest_scene_path = ResourceUID.get_id_path(ResourceUID.text_to_id(dest_scene_path))
	var level_container = get_tree().root.get_node("Root/CurrentLevel")
	var player = get_tree().root.get_node("Root/Player")

	ResourceLoader.load_threaded_request(dest_scene_path)
	while ResourceLoader.load_threaded_get_status(dest_scene_path) != ResourceLoader.THREAD_LOAD_LOADED:
		await get_tree().process_frame
	
	var scene = ResourceLoader.load_threaded_get(dest_scene_path)
	var new_level = scene.instantiate()
	
	transfer_room.get_parent().remove_child(transfer_room)
	level_container.add_child(transfer_room)
	
	AIDirector.clear_level()
	for child in level_container.get_children():
		if child != transfer_room:
			child.queue_free()
	
	DoorRegistry.clear()
	DoorRegistry.register_transfer_room(dock_name, transfer_room)
	await get_tree().process_frame

	AIDirector.level_name = dest_scene_path.get_file().get_basename()
	AIDirector.level_path = dest_scene_path
	level_container.add_child(new_level)
	await get_tree().process_frame
	AIDirector.nav_region = new_level.get_node("NavigationRegion3D")
	AIDirector.start_robots()
	
	var level_dock = DoorRegistry.get_dock(dock_name)
	if level_dock == Transform3D():
		push_error("Dock not found: " + dock_name)
		return
	
	var door_dock: Node3D
	if side == DoorSide.DOOR1:
		door_dock = transfer_room.get_node("Door1Dock")
	else:
		door_dock = transfer_room.get_node("Door2Dock")
	
	var player_local = transfer_room.global_transform.inverse() * player.global_transform
	
	var flip_angle = 0.0 if side == DoorSide.DOOR1 else PI
	var dock_rotation_y = level_dock.basis.get_euler().y
	transfer_room.global_rotation = Vector3(0, dock_rotation_y + flip_angle, 0)
	
	var offset = level_dock.origin - door_dock.global_position
	transfer_room.global_position += offset
	
	player.global_transform = transfer_room.global_transform * player_local
	
	await transfer_room.open_side(side)
	SaveManager.save()
	print("[SceneManager] checkpoint saved — level: ", AIDirector.level_name)

func reload_current() -> void:
	var level_path := SaveManager.current.current_level
	if level_path.is_empty():
		push_error("[SceneManager] reload_current: no saved level path")
		return

	var level_container := get_tree().root.get_node("Root/CurrentLevel")

	AIDirector.clear_level_no_save()
	NetworkManager.reset()
	DoorRegistry.clear()

	for child in level_container.get_children():
		child.queue_free()
	await get_tree().process_frame

	var scene := ResourceLoader.load(level_path) as PackedScene
	var new_level := scene.instantiate()

	AIDirector.level_name = level_path.get_file().get_basename()
	AIDirector.level_path = level_path
	level_container.add_child(new_level)
	await get_tree().process_frame

	AIDirector.nav_region = new_level.get_node("NavigationRegion3D")
	AIDirector.start_robots()

	SaveManager.apply_to_player()
	print("[SceneManager] reloaded level: ", AIDirector.level_name)

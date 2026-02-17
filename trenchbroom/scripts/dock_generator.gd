@tool
extends Node3D

@export_file("*.tscn") var transfer_room_scene: String = "res://scenes/levels/transfer_room.tscn"

@export var dock_name: String = "Dock":
	set(value):
		dock_name = value
		_rename_marker()

@export_group("Door 1 Destination")
@export_file("*.tscn") var door1_scene_path: String
@export var door1_dock: String = "Dock"

@export_group("Door 2 Destination")
@export_file("*.tscn") var door2_scene_path: String
@export var door2_dock: String = "Dock"

func _ready() -> void:
	_draw_gizmo()
	if not Engine.is_editor_hint():
		_hide_gizmo()
		DoorRegistry.register_dock(dock_name, self)
		_spawn_transfer_room()

func _spawn_transfer_room() -> void:
	if transfer_room_scene == "":
		return
	
	if DoorRegistry.has_transfer_room(dock_name):
		print("Transfer room already exists at ", dock_name)
		return
	
	var scene = load(transfer_room_scene)
	var transfer_room = scene.instantiate()
	get_parent().call_deferred("add_child", transfer_room)
	
	await get_tree().process_frame
	
	# reset first
	transfer_room.global_rotation = Vector3.ZERO
	transfer_room.global_position = Vector3.ZERO
	
	await get_tree().process_frame
	
	# Door1 uses no flip (same as change_scene)
	var flip_angle = 0.0
	transfer_room.global_rotation = Vector3(0, global_rotation.y + flip_angle, 0)
	
	await get_tree().process_frame
	
	# align Door1Dock to dock_generator
	var door_dock = transfer_room.get_node("Door1Dock")
	var offset = global_position - door_dock.global_position
	transfer_room.global_position += offset
	
	# configure destinations
	transfer_room.door1_scene_path = door1_scene_path
	transfer_room.door1_dock = door1_dock
	transfer_room.door2_scene_path = door2_scene_path
	transfer_room.door2_dock = door2_dock
	
	# register it
	DoorRegistry.register_transfer_room(dock_name, transfer_room)

func _hide_gizmo() -> void:
	for child in get_children():
		if child is MeshInstance3D or child.name in ["TransferRoomSide", "LevelSide"]:
			child.visible = false

func _rename_marker() -> void:
	for child in get_children():
		if child is Marker3D:
			child.name = dock_name
			break

func _draw_gizmo() -> void:
	_draw_arrow("TransferRoomSide", Color.RED, -1.0)
	_draw_arrow("LevelSide", Color.GREEN, 1.0)

func _draw_arrow(label: String, color: Color, direction: float) -> void:
	var root = Node3D.new()
	root.name = label
	add_child(root)
	
	var body = MeshInstance3D.new()
	var body_mesh = CylinderMesh.new()
	body_mesh.top_radius = 0.05
	body_mesh.bottom_radius = 0.05
	body_mesh.height = 1.0
	body.mesh = body_mesh
	body.rotation_degrees.z = 90.0
	body.position.x = direction * 0.5
	root.add_child(body)
	
	var head = MeshInstance3D.new()
	var head_mesh = CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.2
	head_mesh.height = 0.4
	head.mesh = head_mesh
	if direction > 0:
		head.rotation_degrees.z = -90.0
	else:
		head.rotation_degrees.z = 90.0
	head.position.x = direction * 1.2
	root.add_child(head)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	body.material_override = mat
	head.material_override = mat

@tool
extends Node3D

@export var dock_name: String = "Dock":
	set(value):
		dock_name = value
		_rename_marker()

func _ready() -> void:
	_draw_gizmo()
	if not Engine.is_editor_hint():
		_hide_gizmo()
		# register when scene loads
		DoorRegistry.register_dock(dock_name, self)

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

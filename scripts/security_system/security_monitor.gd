class_name SecurityMonitor
extends Node3D

@export var linked_camera_ids: Array[String] = []

@onready var _ui: Node = $SubViewport/SecurityMonitorUI
@onready var interactable: Interactable = $Area3D/Interactable
@onready var _camera_position: Node3D = $CameraPosition
@onready var _camera_look_at: Node3D = $CameraLookAt

var terminal_ui = null  # No keyboard UI — satisfies TerminalViewer duck typing


func _ready() -> void:
	if interactable:
		interactable.prompt_text = "Press %s to view Monitor"
		interactable.interacted.connect(_on_interacted)

	await get_tree().process_frame
	_ui.call("setup", linked_camera_ids)


func _on_interacted(player) -> void:
	player.start_viewing_terminal(self)


func stop_viewing(_player) -> void:
	pass


func get_camera_position() -> Vector3:
	if _camera_position:
		return _camera_position.global_position
	return global_position + Vector3(0, 0.5, 0.25)


func get_look_at_position() -> Vector3:
	if _camera_look_at:
		return _camera_look_at.global_position
	return global_position + Vector3(0, 0.47, 0)

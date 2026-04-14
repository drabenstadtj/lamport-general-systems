class_name CameraManager
extends Node

signal alert_raised(camera_id: String, target: Node)

# Registry: id → camera node
var _cameras: Dictionary = {}
# Access control: zone/context → allowed camera ids
var _access_map: Dictionary = {}

var _camera_view_ui: Node = null


func register_camera(camera: SecurityCamera) -> void:
	_cameras[camera.camera_id] = camera
	camera.detection_triggered.connect(_on_detection)
	camera.camera_disabled.connect(_on_camera_disabled)

func unregister_camera(camera_id: String) -> void:
	if _cameras.has(camera_id):
		_cameras.erase(camera_id)

# --- Access Control ---

func grant_access(context: String, camera_id: String) -> void:
	if not _access_map.has(context):
		_access_map[context] = []
	_access_map[context].append(camera_id)

func revoke_access(context: String, camera_id: String) -> void:
	if _access_map.has(context):
		_access_map[context].erase(camera_id)

func get_accessible_cameras(context: String) -> Array[SecurityCamera]:
	var result: Array[SecurityCamera] = []
	if not _access_map.has(context):
		return result
	for cam_id in _access_map[context]:
		if _cameras.has(cam_id):
			result.append(_cameras[cam_id])
	return result

func is_accessible(context: String, camera_id: String) -> bool:
	return _access_map.has(context) \
		and _access_map[context].has(camera_id) \
		and _cameras.has(camera_id)

# --- Commands ---

func disable_camera(camera_id: String) -> void:
	if _cameras.has(camera_id):
		_cameras[camera_id].deactivate()

func enable_camera(camera_id: String) -> void:
	if _cameras.has(camera_id):
		_cameras[camera_id].activate()

# --- Callbacks ---

func _on_detection(camera: SecurityCamera, target: Node) -> void:
	alert_raised.emit(camera.camera_id, target)

func _on_camera_disabled(camera: SecurityCamera) -> void:
	print("Camera offline: ", camera.camera_id)

# --- Camera View UI ---

func get_camera(camera_id: String) -> SecurityCamera:
	return _cameras.get(camera_id, null)

func get_all_cameras() -> Array[SecurityCamera]:
	var result: Array[SecurityCamera] = []
	for cam in _cameras.values():
		result.append(cam)
	return result

func open_camera_view() -> void:
	if _camera_view_ui == null:
		return
	(_camera_view_ui as CameraViewUI).setup(get_all_cameras())
	_camera_view_ui.visible = true

func close_camera_view() -> void:
	if _camera_view_ui == null:
		return
	_camera_view_ui.visible = false
	(_camera_view_ui as CameraViewUI).clear_cameras()

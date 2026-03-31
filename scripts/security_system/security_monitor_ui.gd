class_name SecurityMonitorUI
extends Control

@onready var _grid: GridContainer = $MarginContainer/GridContainer

var _cam_pairs: Array[Dictionary] = []


func setup(camera_ids: Array[String]) -> void:
	clear()
	for camera_id in camera_ids:
		var sec_cam := SecurityCameraManager.get_camera(camera_id)
		if sec_cam == null or sec_cam.get_camera() == null:
			push_warning("[SecurityMonitorUI] no camera found for id: " + camera_id)
			continue

		var vp_cam := Camera3D.new()

		var viewport := SubViewport.new()
		viewport.size = Vector2i(640, 360)
		viewport.own_world_3d = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.add_child(vp_cam)

		var container := SubViewportContainer.new()
		container.custom_minimum_size = Vector2(640, 360)
		container.stretch = true
		container.add_child(viewport)

		var label := Label.new()
		label.text = camera_id
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var wrapper := VBoxContainer.new()
		wrapper.add_child(container)
		wrapper.add_child(label)
		_grid.add_child(wrapper)

		vp_cam.current = true

		_cam_pairs.append({"source": sec_cam, "viewport_cam": vp_cam})


func clear() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cam_pairs.clear()


func _process(_delta: float) -> void:
	for pair in _cam_pairs:
		var source_cam: Camera3D = pair["source"].get_camera()
		var vp_cam: Camera3D = pair["viewport_cam"]
		if is_instance_valid(source_cam) and is_instance_valid(vp_cam):
			vp_cam.global_transform = source_cam.global_transform

class_name CameraViewUI
extends CanvasLayer

@onready var grid: GridContainer = $ColorRect/VBoxContainer/MarginContainer/ScrollContainer/GridContainer

# [{source: SecurityCamera, viewport_cam: Camera3D}]
var _cam_pairs: Array[Dictionary] = []


func setup(cameras: Array[SecurityCamera]) -> void:
	clear_cameras()
	print("[CameraViewUI] setup — ", cameras.size(), " camera(s)")
	for security_cam in cameras:
		if security_cam.get_camera() == null:
			print("[CameraViewUI] skipping ", security_cam.camera_id, " — no Camera3D node")
			continue

		var vp_cam := Camera3D.new()

		var viewport := SubViewport.new()
		viewport.size = Vector2i(320, 240)
		viewport.own_world_3d = false
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.add_child(vp_cam)

		var container := SubViewportContainer.new()
		container.custom_minimum_size = Vector2(320, 240)
		container.stretch = true
		container.add_child(viewport)

		var label := Label.new()
		label.text = security_cam.camera_id
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var wrapper := VBoxContainer.new()
		wrapper.add_child(container)
		wrapper.add_child(label)
		grid.add_child(wrapper)

		# Must be set AFTER entering the scene tree to register with the viewport
		vp_cam.current = true

		_cam_pairs.append({"source": security_cam, "viewport_cam": vp_cam})


func clear_cameras() -> void:
	for child in grid.get_children():
		child.queue_free()
	_cam_pairs.clear()


func _process(_delta: float) -> void:
	if not visible:
		return
	for pair in _cam_pairs:
		var source_cam: Camera3D = pair["source"].get_camera()
		var vp_cam: Camera3D = pair["viewport_cam"]
		if is_instance_valid(source_cam) and is_instance_valid(vp_cam):
			vp_cam.global_transform = source_cam.global_transform


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Consume all input while the camera view is open so nothing bleeds through
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		SecurityCameraManager.close_camera_view()

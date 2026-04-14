class_name SecurityCamera
extends Node3D

signal detection_triggered(camera: SecurityCamera, body: Node)
signal camera_disabled(camera: SecurityCamera)

@export var camera_id: String = ""
@export var is_active: bool = true

# FOV settings
@export var fov_angle: float = 90.0
@export var view_distance: float = 300.0
@export var ray_count: int = 12

# Debug visualization
@export var debug_draw: bool = true
@export var color_idle: Color = Color(0.0, 1.0, 0.0, 0.3)
@export var color_alert: Color = Color(1.0, 0.0, 0.0, 0.5)
@export var color_inactive: Color = Color(0.5, 0.5, 0.5, 0.2)

@onready var cam: Camera3D = $Camera3D

var _detection_cooldown: float = 0.0
var _is_detecting: bool = false

var _debug_mesh_instance: MeshInstance3D
var _debug_mesh: ImmediateMesh

func _ready() -> void:
	SecurityCameraManager.register_camera(self)

	if debug_draw:
		_debug_mesh = ImmediateMesh.new()
		_debug_mesh_instance = MeshInstance3D.new()
		_debug_mesh_instance.mesh = _debug_mesh
		# Unshaded so it's always visible
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_debug_mesh_instance.material_override = mat
		add_child(_debug_mesh_instance)

func _exit_tree() -> void:
	SecurityCameraManager.unregister_camera(camera_id)

func _physics_process(delta: float) -> void:
	if not is_active:
		_update_debug_mesh()
		return
	_detection_cooldown -= delta
	if _detection_cooldown <= 0.0:
		_is_detecting = false
		_scan_for_targets()
	if debug_draw:
		_update_debug_mesh()

func _scan_for_targets() -> void:
	var space := get_world_3d().direct_space_state
	var half_fov := fov_angle / 2.0
	var step := fov_angle / ray_count

	for i in range(ray_count + 1):
		var angle_deg := -half_fov + (step * i)
		var angle_rad := deg_to_rad(angle_deg)
		# Rotate ray direction within the camera's local forward plane
		var local_dir := Vector3(sin(angle_rad), 0.0, cos(angle_rad))
		var world_dir := global_transform.basis * local_dir
		var target_pos := global_position + world_dir * view_distance

		var query := PhysicsRayQueryParameters3D.create(global_position, target_pos)
		query.exclude = [self]

		var result := space.intersect_ray(query)
		if result and result.collider.is_in_group("detectable"):
			_is_detecting = true
			_detection_cooldown = 0.5
			detection_triggered.emit(self, result.collider)
			return

func _update_debug_mesh() -> void:
	if not debug_draw or not _debug_mesh:
		return

	var draw_color: Color
	if not is_active:
		draw_color = color_inactive
	elif _is_detecting:
		draw_color = color_alert
	else:
		draw_color = color_idle

	_debug_mesh.clear_surfaces()
	_debug_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_fov := fov_angle / 2.0
	var step := fov_angle / ray_count
	var space := get_world_3d().direct_space_state if is_active else null
	var origin := Vector3.ZERO  # local space

	var rim_points: Array[Vector3] = []

	for i in range(ray_count + 1):
		var angle_deg := -half_fov + (step * i)
		var angle_rad := deg_to_rad(angle_deg)
		var local_dir := Vector3(sin(angle_rad), 0.0, cos(angle_rad))
		var ray_end := local_dir * view_distance

		# Shorten to wall hit
		if space:
			var world_start := global_position
			var world_end := global_position + (global_transform.basis * local_dir) * view_distance
			var query := PhysicsRayQueryParameters3D.create(world_start, world_end)
			query.exclude = [self]
			var result := space.intersect_ray(query)
			if result:
				ray_end = global_transform.affine_inverse() * result.position

		rim_points.append(ray_end)

	# Draw cone triangles from origin to each rim segment
	for i in range(rim_points.size() - 1):
		_debug_mesh.surface_set_color(draw_color)
		_debug_mesh.surface_add_vertex(origin)
		_debug_mesh.surface_add_vertex(rim_points[i])
		_debug_mesh.surface_add_vertex(rim_points[i + 1])

	_debug_mesh.surface_end()


func activate() -> void:
	is_active = true

func deactivate() -> void:
	is_active = false
	_is_detecting = false
	camera_disabled.emit(self)

func get_camera_id() -> String:
	return camera_id

func get_camera() -> Camera3D:
	return cam

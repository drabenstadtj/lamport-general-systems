extends Node3D

class_name SensoryComponent

var player: CharacterBody3D
@onready var sightline: RayCast3D = $RayCast3D

@export var hearing_range: float = 10.0 # meters
@export var vision_angle: float = 75.0          # horizontal FOV (degrees)
@export var vision_vertical_angle: float = 45.0 # vertical FOV (degrees)
@export var vision_range: float = 10.0 # meters
@export var visual_confidence_threshold: float = 100.0

@export var debug_vision: bool = false

var visual_confidence: float = 0.0
var last_detected_position: Vector3
var is_threat_confirmed: bool = false
var has_detection: bool = false

var _dbg_mesh: ImmediateMesh
var _dbg_instance: MeshInstance3D

func _ready() -> void:
	player = AIDirector.player
	print("[SensoryComponent] ready — player: ", player)
	_setup_debug_mesh()

func _setup_debug_mesh() -> void:
	_dbg_mesh = ImmediateMesh.new()
	_dbg_instance = MeshInstance3D.new()
	_dbg_instance.mesh = _dbg_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	_dbg_instance.material_override = mat
	add_child(_dbg_instance)

func _physics_process(_delta: float) -> void:
	has_detection = false

	if vision_check():
		visual_confidence += 1.0
	else:
		visual_confidence = clamp(visual_confidence - 1.0, 0.0, visual_confidence_threshold)

	if visual_confidence > visual_confidence_threshold:
		if not is_threat_confirmed:
			print("[SensoryComponent] threat confirmed — confidence: ", visual_confidence)
		is_threat_confirmed = true

	_update_debug()


func vision_check() -> bool:
	var player_center := player.global_position + Vector3(0, 0.9, 0)
	var to_player: Vector3 = player_center - global_position

	if to_player.length() > vision_range:
		return false

	# horizontal angle — compare XZ projections
	var fwd := -global_basis.z
	var fwd_flat := Vector3(fwd.x, 0.0, fwd.z)
	var to_flat  := Vector3(to_player.x, 0.0, to_player.z)
	if fwd_flat.length() > 0.001 and to_flat.length() > 0.001:
		if to_flat.angle_to(fwd_flat) > deg_to_rad(vision_angle) / 2.0:
			return false

	# vertical angle — elevation from horizontal plane
	var elevation := atan2(to_player.y, to_flat.length())
	if abs(elevation) > deg_to_rad(vision_vertical_angle) / 2.0:
		return false

	# cast ray toward player center
	sightline.target_position = sightline.to_local(sightline.global_position + to_player.normalized() * vision_range)
	sightline.force_raycast_update()

	var collider = sightline.get_collider()
	if collider is Node:
		if collider.is_in_group("player"):
			last_detected_position = player.global_position
			has_detection = true
			return true
	return false


func _update_debug() -> void:
	_dbg_mesh.clear_surfaces()
	if not debug_vision:
		return

	var cone_color := Color.GREEN if has_detection else Color.YELLOW
	var h_half := deg_to_rad(vision_angle / 2.0)
	var v_half := deg_to_rad(vision_vertical_angle / 2.0)
	var D := vision_range
	# radii of the ellipse at the far cap
	var xr := D * tan(h_half)
	var yr := D * tan(v_half)
	var steps := 32

	_dbg_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_dbg_mesh.surface_set_color(cone_color)

	# ellipse cap at distance D along local -Z
	for i in range(steps):
		var t1: float = TAU * float(i) / steps
		var t2: float = TAU * float(i + 1) / steps
		_dbg_mesh.surface_add_vertex(Vector3(xr * cos(t1), yr * sin(t1), -D))
		_dbg_mesh.surface_add_vertex(Vector3(xr * cos(t2), yr * sin(t2), -D))

	# spokes from apex to cap (4 cardinal + 4 diagonal = 8 spokes)
	for i in range(8):
		var t: float = TAU * float(i) / 8.0
		_dbg_mesh.surface_add_vertex(Vector3.ZERO)
		_dbg_mesh.surface_add_vertex(Vector3(xr * cos(t), yr * sin(t), -D))

	_dbg_mesh.surface_end()

	# ray toward player center
	if player:
		var player_local := to_local(player.global_position + Vector3(0, 0.9, 0))
		var ray_color := Color.CYAN if has_detection else Color.RED
		_dbg_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		_dbg_mesh.surface_set_color(ray_color)
		_dbg_mesh.surface_add_vertex(Vector3.ZERO)
		_dbg_mesh.surface_add_vertex(player_local)
		_dbg_mesh.surface_end()


func get_detected_threat():
	return last_detected_position

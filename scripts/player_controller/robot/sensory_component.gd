extends Node3D
class_name SensoryComponent

# References ----------------------------------------------------------------
var player: CharacterBody3D
@onready var sightline: RayCast3D = $RayCast3D

# Exports -------------------------------------------------------------------
@export_group("Vision")
@export var vision_range: float = 10.0 # meters
@export var vision_angle: float = 75.0 # horizontal FOV (degrees)
@export var vision_vertical_angle: float = 45.0 # vertical FOV (degrees)
@export var visual_confidence_threshold: float = 100.0

@export_group("Hearing")
@export var hearing_range: float = 10.0 # meters
@export var hearing_curve: Curve

@export_group("Debug")
@export var debug_vision: bool = false

# State ---------------------------------------------------------------------
var visual_confidence: float = 0.0
var is_threat_confirmed: bool = false
var has_detection: bool = false
var last_detected_position: Vector3

# Debug internals -----------------------------------------------------------
var _sound_dbg_timer: float = 0.0
var _last_sound_position: Vector3
var _last_sound_volume: float = 0.0
var _last_sound_in_range: bool = false
var _last_sound_was_heard: bool = false
var _dbg_mesh: ImmediateMesh
var _dbg_mesh_instance: MeshInstance3D

# Setup ---------------------------------------------------------------------
func _ready() -> void:
	player = AIDirector.player
	print("[SensoryComponent] ready — player: ", player)
	_setup_hearing_curve()
	_setup_debug_mesh()

func _setup_hearing_curve() -> void:
	hearing_curve = Curve.new()
	hearing_curve.add_point(Vector2(0.0, 0.0), 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	hearing_curve.add_point(Vector2(1.0, 1.0), 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	hearing_curve.bake()

func _setup_debug_mesh() -> void:
	_dbg_mesh = ImmediateMesh.new()
	_dbg_mesh_instance = MeshInstance3D.new()
	_dbg_mesh_instance.mesh = _dbg_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	_dbg_mesh_instance.material_override = mat
	add_child(_dbg_mesh_instance)

# Per-frame -----------------------------------------------------------------
func _physics_process(_delta: float) -> void:
	has_detection = false

	var robot := get_parent() as Robot
	if robot == null or not robot.hostile:
		visual_confidence = clamp(visual_confidence - 1.0, 0.0, visual_confidence_threshold)
		is_threat_confirmed = false
		return

	if vision_check():
		visual_confidence += 1.0
	else:
		visual_confidence = clamp(visual_confidence - 1.0, 0.0, visual_confidence_threshold)

	if visual_confidence > visual_confidence_threshold:
		if not is_threat_confirmed:
			print("[SensoryComponent] threat confirmed — confidence: ", visual_confidence)
		is_threat_confirmed = true

	if _sound_dbg_timer > 0.0:
		_sound_dbg_timer -= _delta

	_update_debug()

# Vision --------------------------------------------------------------------
func vision_check() -> bool:
	if not is_instance_valid(player):
		player = AIDirector.player
		return false
	var player_center := player.global_position + Vector3(0, 0.9, 0)
	var to_player: Vector3 = player_center - global_position

	if to_player.length() > vision_range:
		return false

	# Within melee range — always detected regardless of facing
	if to_player.length() < 1.5:
		last_detected_position = player.global_position
		has_detection = true
		return true

	# horizontal angle — compare XZ projections
	var fwd := -global_basis.z
	var fwd_flat := Vector3(fwd.x, 0.0, fwd.z)
	var to_flat := Vector3(to_player.x, 0.0, to_player.z)
	if fwd_flat.length() > 0.001 and to_flat.length() > 0.001:
		if to_flat.angle_to(fwd_flat) > deg_to_rad(vision_angle) / 2.0:
			return false

	# vertical angle — elevation from horizontal plane
	var elevation := atan2(to_player.y, to_flat.length())
	if abs(elevation) > deg_to_rad(vision_vertical_angle) / 2.0:
		return false

	# cast ray toward player center, ignoring door bodies
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(sightline.global_position, player_center)
	query.exclude = _get_door_rids()
	var result := space.intersect_ray(query)
	if result and result.collider is Node and result.collider.is_in_group("player"):
		last_detected_position = player.global_position
		has_detection = true
		return true
	return false

func _get_door_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for body in get_tree().get_nodes_in_group("door_body"):
		rids.append(body.get_rid())
	return rids

# Hearing -------------------------------------------------------------------
func hear_sound(sound_position: Vector3, volume: float) -> void:
	# always record for debug visualization
	_last_sound_position = sound_position
	_last_sound_volume = volume
	_sound_dbg_timer = 0.5

	var sound_distance := (global_position - sound_position).length()
	if sound_distance > hearing_range:
		_last_sound_in_range = false
		_last_sound_was_heard = false
		return
	_last_sound_in_range = true

	var threshold := hearing_curve.sample(sound_distance / hearing_range)
	if volume < threshold:
		_last_sound_was_heard = false
		return

	_last_sound_was_heard = true
	has_detection = true
	last_detected_position = sound_position

func get_detected_threat() -> Vector3:
	return last_detected_position

# Debug visualization -------------------------------------------------------
func _update_debug() -> void:
	_dbg_mesh.clear_surfaces()
	if not debug_vision:
		return
	_draw_vision_cone()
	_draw_hearing_ring()
	_draw_sound_event()
	_draw_sightline_ray()

func _draw_vision_cone() -> void:
	var cone_color := Color.GREEN if has_detection else Color.YELLOW
	var h_half := deg_to_rad(vision_angle / 2.0)
	var v_half := deg_to_rad(vision_vertical_angle / 2.0)
	var D := vision_range
	var xr := D * tan(h_half)
	var yr := D * tan(v_half)
	var steps := 32

	_dbg_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_dbg_mesh.surface_set_color(cone_color)
	for i in range(steps):
		var t1: float = TAU * float(i) / steps
		var t2: float = TAU * float(i + 1) / steps
		_dbg_mesh.surface_add_vertex(Vector3(xr * cos(t1), yr * sin(t1), -D))
		_dbg_mesh.surface_add_vertex(Vector3(xr * cos(t2), yr * sin(t2), -D))
	for i in range(8):
		var t: float = TAU * float(i) / 8.0
		_dbg_mesh.surface_add_vertex(Vector3.ZERO)
		_dbg_mesh.surface_add_vertex(Vector3(xr * cos(t), yr * sin(t), -D))
	_dbg_mesh.surface_end()

func _draw_hearing_ring() -> void:
	var hear_color := Color.ORANGE if (_sound_dbg_timer > 0.0 and _last_sound_in_range) else Color.CYAN
	var steps := 48
	_dbg_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_dbg_mesh.surface_set_color(hear_color)
	for i in range(steps):
		var t1: float = TAU * float(i) / steps
		var t2: float = TAU * float(i + 1) / steps
		_dbg_mesh.surface_add_vertex(Vector3(hearing_range * cos(t1), 0.0, hearing_range * sin(t1)))
		_dbg_mesh.surface_add_vertex(Vector3(hearing_range * cos(t2), 0.0, hearing_range * sin(t2)))
	_dbg_mesh.surface_end()

func _draw_sound_event() -> void:
	if _sound_dbg_timer <= 0.0:
		return
	var sound_local := to_local(_last_sound_position)
	var sound_color := Color.ORANGE if _last_sound_was_heard else Color.MAGENTA
	var steps := 32
	_dbg_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_dbg_mesh.surface_set_color(sound_color)
	for i in range(steps):
		var t1: float = TAU * float(i) / steps
		var t2: float = TAU * float(i + 1) / steps
		_dbg_mesh.surface_add_vertex(sound_local + Vector3(_last_sound_volume * cos(t1), 0.0, _last_sound_volume * sin(t1)))
		_dbg_mesh.surface_add_vertex(sound_local + Vector3(_last_sound_volume * cos(t2), 0.0, _last_sound_volume * sin(t2)))
	_dbg_mesh.surface_end()

func _draw_sightline_ray() -> void:
	if not player:
		return
	var player_local := to_local(player.global_position + Vector3(0, 0.9, 0))
	var ray_color := Color.CYAN if has_detection else Color.RED
	_dbg_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_dbg_mesh.surface_set_color(ray_color)
	_dbg_mesh.surface_add_vertex(Vector3.ZERO)
	_dbg_mesh.surface_add_vertex(player_local)
	_dbg_mesh.surface_end()

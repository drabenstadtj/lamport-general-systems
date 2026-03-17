@tool
extends Node3D
class_name Cable

enum Mode {
	HANGING, ## Parabolic sag between each pair of anchors
	GROUND,  ## Catmull-Rom spline along the floor, no sag
}

@export var mode: Mode = Mode.HANGING:
	set(v):
		mode = v
		_rebuild()

## NodePaths to Marker3Ds. The cable runs from this node's position
## through each waypoint in order.
@export var waypoints: Array[NodePath]:
	set(v):
		waypoints = v
		_rebuild()

@export var sag: float = 0.3:
	set(v):
		sag = v
		_rebuild()

@export var thickness: float = 0.015:
	set(v):
		thickness = v
		_rebuild()

@export var color: Color = Color(0.08, 0.08, 0.08):
	set(v):
		color = v
		if _material:
			_material.albedo_color = v

@export_range(4, 32) var segments: int = 12:
	set(v):
		segments = v
		_rebuild()

@export_range(3, 8) var sides: int = 4:
	set(v):
		sides = v
		_rebuild()

var _material: StandardMaterial3D
var _mesh_instance: MeshInstance3D
var _last_positions: PackedVector3Array

func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.roughness = 0.95

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "CableMesh"
	add_child(_mesh_instance)

	_rebuild()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var current := _get_waypoint_positions()
	if current != _last_positions:
		_rebuild()

func _get_waypoint_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for path in waypoints:
		var n := get_node_or_null(path) as Node3D
		if n:
			result.append(n)
	return result

func _get_waypoint_positions() -> PackedVector3Array:
	var positions := PackedVector3Array()
	for path in waypoints:
		var n := get_node_or_null(path) as Node3D
		if n:
			positions.append(n.global_position)
	return positions

func _get_curve_point(t: float, start: Vector3, end_pos: Vector3) -> Vector3:
	var p := start.lerp(end_pos, t)
	p.y -= sag * 4.0 * t * (1.0 - t)
	return p

func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	return 0.5 * (
		2.0 * p1
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t
	)

func _rebuild() -> void:
	if not _mesh_instance or not is_inside_tree():
		return

	var nodes := _get_waypoint_nodes()
	if nodes.is_empty():
		_mesh_instance.mesh = null
		return

	var anchors := PackedVector3Array()
	anchors.append(global_position)
	for n in nodes:
		anchors.append(n.global_position)

	_last_positions = _get_waypoint_positions()

	var points := PackedVector3Array()
	var na := anchors.size()

	if mode == Mode.HANGING:
		for seg in range(na - 1):
			var start_w := anchors[seg]
			var end_w := anchors[seg + 1]
			var count := segments if seg < na - 2 else segments + 1
			for i in range(count):
				var t := float(i) / float(segments)
				points.append(to_local(_get_curve_point(t, start_w, end_w)))
	else:
		for seg in range(na - 1):
			var p0 := 2.0 * anchors[seg] - anchors[seg + 1] if seg == 0 else anchors[seg - 1]
			var p1 := anchors[seg]
			var p2 := anchors[seg + 1]
			var p3 := 2.0 * anchors[seg + 1] - anchors[seg] if seg + 2 >= na else anchors[seg + 2]
			var count := segments if seg < na - 2 else segments + 1
			for i in range(count):
				var t := float(i) / float(segments)
				points.append(to_local(_catmull_rom(p0, p1, p2, p3, t)))

	_mesh_instance.mesh = _build_tube(points)
	_mesh_instance.set_surface_override_material(0, _material)

func _build_tube(points: PackedVector3Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var rings: Array[PackedVector3Array] = []
	for i in range(points.size()):
		var fwd: Vector3
		if i < points.size() - 1:
			fwd = (points[i + 1] - points[i]).normalized()
		else:
			fwd = (points[i] - points[i - 1]).normalized()

		var up := Vector3.UP
		if abs(fwd.dot(up)) > 0.99:
			up = Vector3.FORWARD
		var right := fwd.cross(up).normalized()
		up = right.cross(fwd).normalized()

		var ring := PackedVector3Array()
		for j in range(sides):
			var angle := TAU * float(j) / float(sides)
			ring.append(points[i] + (right * cos(angle) + up * sin(angle)) * thickness)
		rings.append(ring)

	for ring in rings:
		for v in ring:
			verts.append(v)
			normals.append(Vector3.UP)

	for i in range(rings.size() - 1):
		for j in range(sides):
			var nj := (j + 1) % sides
			var a := i * sides + j
			var b := i * sides + nj
			var c := (i + 1) * sides + nj
			var d := (i + 1) * sides + j
			indices.append_array([a, b, c, a, c, d])

	for idx in range(0, indices.size(), 3):
		var n := (verts[indices[idx + 1]] - verts[indices[idx]]).cross(
				  verts[indices[idx + 2]] - verts[indices[idx]]).normalized()
		normals[indices[idx]]     = n
		normals[indices[idx + 1]] = n
		normals[indices[idx + 2]] = n

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX]  = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

@tool
extends Marker3D
class_name PatrolPoint

@onready var _label: Label3D = $Label3D
@onready var _sphere: MeshInstance3D = $Sphere

const UNASSIGNED_COLOR := Color(0.5, 0.5, 0.5)

var _material: StandardMaterial3D
var _refresh_timer: float = 0.0

func _ready() -> void:
	if not Engine.is_editor_hint():
		_label.visible = false
		_sphere.visible = false
		return

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.no_depth_test = true
	_material.albedo_color = UNASSIGNED_COLOR
	_sphere.material_override = _material
	_label.text = "(unassigned)"
	_label.modulate = UNASSIGNED_COLOR

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = 0.5
	_refresh()

func _refresh() -> void:
	if not _material or not _label:
		return
	var result := _find_owning_robot()
	if result.is_empty():
		_material.albedo_color = UNASSIGNED_COLOR
		_label.text = "(unassigned)"
		_label.modulate = UNASSIGNED_COLOR
		return

	var robot: Robot = result["robot"]
	var index: int = result["index"]
	var color := color_for_id(robot.id)
	_material.albedo_color = color
	_label.text = "%s  [%d]" % [robot.id, index]
	_label.modulate = color

func _find_owning_robot() -> Dictionary:
	# current_scene is null in the editor — use get_edited_scene_root() instead
	var scene_root: Node = get_tree().get_edited_scene_root()
	if not scene_root:
		scene_root = owner  # fallback when instanced inside another scene
	if not scene_root:
		return {}
	return _search(scene_root)

func _search(node: Node) -> Dictionary:
	if node is Robot:
		var idx: int = node.patrol_points.find(self)
		if idx >= 0:
			return {"robot": node, "index": idx}
	for child in node.get_children():
		var result := _search(child)
		if not result.is_empty():
			return result
	return {}

static func color_for_id(id: String) -> Color:
	var h := float(id.hash() % 360) / 360.0
	return Color.from_hsv(absf(h), 0.80, 1.0)

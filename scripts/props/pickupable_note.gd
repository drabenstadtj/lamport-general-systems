@tool
extends Node3D

@export_group("Note")
@export var texture: Texture2D:
	set(value):
		texture = value
		_apply()

@export var base_color: Color = Color(1.0, 1.0, 0.7):
	set(value):
		base_color = value
		_apply()

@export var note_size: Vector2 = Vector2(0.2, 0.2):
	set(value):
		if lock_aspect_ratio and _prev_size != Vector2.ZERO:
			if value.x != _prev_size.x:
				value.y = value.x * (_prev_size.y / _prev_size.x)
			elif value.y != _prev_size.y:
				value.x = value.y * (_prev_size.x / _prev_size.y)
		_prev_size = value
		note_size = value
		_apply()

@export var lock_aspect_ratio: bool = false

@export var roughness: float = 0.8:
	set(value):
		roughness = clamp(value, 0.0, 1.0)
		_apply()

@export_group("Text")
@export_multiline var note_text: String = "":
	set(value):
		note_text = value
		_apply()

@export var font_size: int = 8:
	set(value):
		font_size = value
		_apply()

@export var label_rotation: Vector3 = Vector3(0, 0, 0):
	set(value):
		label_rotation = value
		_apply()

var _mesh_instance: MeshInstance3D
var _shader_material: ShaderMaterial
var _label: Label3D
var _prev_size: Vector2 = Vector2.ZERO

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_apply()

func _ready() -> void:
	_mesh_instance = get_node_or_null("NoteMesh")
	if not _mesh_instance:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "NoteMesh"
		add_child(_mesh_instance)
		if Engine.is_editor_hint():
			_mesh_instance.owner = owner

	var shader := load("res://assets/shaders/sticky_note.gdshader") as Shader
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_mesh_instance.material_override = _shader_material
	_mesh_instance.rotation_degrees.x = 90.0

	_label = get_node_or_null("NoteLabel")
	if not _label:
		_label = Label3D.new()
		_label.name = "NoteLabel"
		_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_label.no_depth_test = false
		add_child(_label)
		if Engine.is_editor_hint():
			_label.owner = owner

	_apply()

func _apply() -> void:
	if not _shader_material or not _mesh_instance:
		return

	var plane := PlaneMesh.new()
	plane.size = note_size
	_mesh_instance.mesh = plane

	_shader_material.set_shader_parameter("base_color", base_color)
	_shader_material.set_shader_parameter("roughness_value", roughness)
	_shader_material.set_shader_parameter("text_decal", texture)

	if texture:
		var tex_size := texture.get_size()
		var tex_aspect := tex_size.x / tex_size.y
		var quad_aspect := note_size.x / note_size.y
		var decal_scale := Vector2.ONE
		if tex_aspect > quad_aspect:
			decal_scale.y = quad_aspect / tex_aspect
		else:
			decal_scale.x = tex_aspect / quad_aspect
		_shader_material.set_shader_parameter("decal_scale", decal_scale)
	else:
		_shader_material.set_shader_parameter("text_decal", null)
		_shader_material.set_shader_parameter("decal_scale", Vector2.ZERO)

	if _label:
		_label.visible = texture == null and note_text != ""
		_label.text = note_text
		_label.font_size = font_size
		_label.modulate = Color.BLACK
		_label.position = Vector3(0, 0, 0.0002)
		_label.rotation_degrees = label_rotation
		_label.pixel_size = 0.0005
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.width = note_size.x / _label.pixel_size

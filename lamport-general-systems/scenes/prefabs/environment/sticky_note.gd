@tool # This makes it update in the editor
extends MeshInstance3D

@export var base_color: Color = Color(1.0, 1.0, 0.7):
	set(value):
		base_color = value
		update_material()

@export var text_texture: Texture2D:
	set(value):
		text_texture = value
		update_material()

@export var roughness: float = 0.8:
	set(value):
		roughness = clamp(value, 0.0, 1.0)
		update_material()

@export var note_size: Vector2 = Vector2(0.1, 0.1):
	set(value):
		note_size = value
		update_mesh()

var shader_material: ShaderMaterial

func _ready():
	setup_mesh()
	setup_material()
	update_material()

func setup_mesh():
	if mesh == null:
		mesh = QuadMesh.new()
	update_mesh()

func update_mesh():
	if mesh is QuadMesh:
		mesh.size = note_size

func setup_material():
	var shader = load("res://resources/shaders/sticky_note.gdshader")
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	set_surface_override_material(0, shader_material)

func update_material():
	if shader_material == null:
		return
	
	shader_material.set_shader_parameter("base_color", base_color)
	shader_material.set_shader_parameter("text_decal", text_texture)
	shader_material.set_shader_parameter("roughness_value", roughness)

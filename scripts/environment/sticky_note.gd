@tool
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
		update_material()

var shader_material: ShaderMaterial

func _ready():
	setup_mesh()
	setup_material()
	update_material()

func setup_mesh():
	mesh = PlaneMesh.new()
	update_mesh()

func update_mesh():
	if mesh is PlaneMesh:
		mesh.size = note_size

func setup_material():
	var shader = load("res://resources/shaders/sticky_note.gdshader")
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	material_override = shader_material

func update_material():
	if shader_material == null:
		return
	
	shader_material.set_shader_parameter("base_color", base_color)
	shader_material.set_shader_parameter("text_decal", text_texture)
	shader_material.set_shader_parameter("roughness_value", roughness)
	
	# Calculate aspect ratio correction to fit the note
	if text_texture != null:
		var tex_size = text_texture.get_size()
		var tex_aspect = tex_size.x / tex_size.y
		var quad_aspect = note_size.x / note_size.y
		
		var decal_scale = Vector2(1.0, 1.0)  
		if tex_aspect > quad_aspect:
			decal_scale.x = 1.0
			decal_scale.y = quad_aspect / tex_aspect
		else:
			decal_scale.x = tex_aspect / quad_aspect
			decal_scale.y = 1.0
		
		shader_material.set_shader_parameter("decal_scale", decal_scale)

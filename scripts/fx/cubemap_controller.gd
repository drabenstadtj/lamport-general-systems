extends Node3D

@export var mat: Material
@export var step = 0.01
@export var player: CharacterBody3D
@onready var viewports_256 = $"Cubemap-256"
@onready var viewports_128 = $"Cubemap-128"

var subviewports_256 = []
var subviewports_128 = []

func _ready():
	for i in viewports_256.get_children():
		subviewports_256.push_back(i)
	for i in viewports_128.get_children():
		subviewports_128.push_back(i)

@export var player_camera: Camera3D  

func _process(_delta):
	if player_camera == null:
		return

	var cam_pos = player_camera.global_position

	for vp in subviewports_256:
		var cam = vp.get_child(0)
		cam.global_position = cam_pos

	for vp in subviewports_128:
		var cam = vp.get_child(0)
		cam.global_position = cam_pos.snapped(Vector3(step, step, step))
	
	# mat.set_shader_parameter("interpolation_z", p_pos.z - player.global_position.z) # difference between quantized
	# assign all viewport textures to the shader
	# camera centered viewport
	mat.set_shader_parameter("tex_posx", subviewports_256[0].get_texture())
	mat.set_shader_parameter("tex_negx", subviewports_256[1].get_texture())
	mat.set_shader_parameter("tex_posy", subviewports_256[2].get_texture())
	mat.set_shader_parameter("tex_negy", subviewports_256[3].get_texture())
	mat.set_shader_parameter("tex_posz", subviewports_256[4].get_texture())
	mat.set_shader_parameter("tex_negz", subviewports_256[5].get_texture())
	
	# other viewports
	mat.set_shader_parameter("tex_posx_z", subviewports_128[0].get_texture())
	mat.set_shader_parameter("tex_negx_z", subviewports_128[1].get_texture())
	mat.set_shader_parameter("tex_posy_z", subviewports_128[2].get_texture())
	mat.set_shader_parameter("tex_negy_z", subviewports_128[3].get_texture())
	mat.set_shader_parameter("tex_posz_z", subviewports_128[4].get_texture())
	mat.set_shader_parameter("tex_negz_z", subviewports_128[5].get_texture())

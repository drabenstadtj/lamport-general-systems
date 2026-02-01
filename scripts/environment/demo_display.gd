@tool
extends Node3D

@export var front_image: Texture2D:
	set(value):
		front_image = value
		print("Front image set: ", front_image)
		if is_inside_tree():  # Only update if node is in tree
			update_front_image()

@onready var front_mesh: MeshInstance3D = $ImageDisplay

func _ready() -> void:
	print("Ready called")
	update_front_image()

func update_front_image():
	print("Update front image called")
	
	if not is_inside_tree():
		print("Not in tree yet, skipping")
		return
	
	# In @tool mode, @onready might not work yet
	if front_mesh == null:
		front_mesh = get_node_or_null("ImageDisplay")
	
	if not front_mesh:
		print("ERROR: front_mesh is null!")
		return
		
	if not front_image:
		print("WARNING: front_image is null!")
		return
	
	print("Creating material...")
	var material = StandardMaterial3D.new()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_texture = front_image
	
	front_mesh.material_override = material
	print("Material applied successfully!")

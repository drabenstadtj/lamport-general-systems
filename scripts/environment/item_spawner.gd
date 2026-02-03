@tool
extends RigidBody3D

@export var model_scene: PackedScene:
	set(value):
		model_scene = value
		if Engine.is_editor_hint() and is_inside_tree():
			_update_model()

@export var model_offset: Vector3 = Vector3.ZERO:
	set(value):
		model_offset = value
		if Engine.is_editor_hint() and models_container:
			_apply_model_offset()

@export var auto_generate_collision: bool = true:
	set(value):
		auto_generate_collision = value
		if Engine.is_editor_hint() and is_inside_tree():
			_update_model()
			
## Mesh instances with this group will be used
@export var collision_group: String = "collision_mesh"  

@export var update_model: bool:
	set(value):
		if Engine.is_editor_hint() and is_inside_tree():
			_update_model()

var models_container: Node3D


func _ready() -> void:
	if not Engine.is_editor_hint():
		_update_model()


func _update_model() -> void:
	# Find or create models container
	models_container = get_node_or_null("Models")
	if not models_container:
		models_container = Node3D.new()
		models_container.name = "Models"
		add_child(models_container)
		if Engine.is_editor_hint() and get_tree():
			models_container.owner = get_tree().edited_scene_root
	
	# Clear existing models
	for child in models_container.get_children():
		child.queue_free()
	
	# Add new model
	if model_scene:
		var model_instance = model_scene.instantiate()
		models_container.add_child(model_instance)
		if Engine.is_editor_hint() and get_tree():
			model_instance.owner = get_tree().edited_scene_root
		
		_apply_model_offset()
		
		# Generate collision if enabled
		if auto_generate_collision:
			_generate_convex_collision()


func _apply_model_offset() -> void:
	if models_container and models_container.get_child_count() > 0:
		var model = models_container.get_child(0)
		model.position = model_offset


func _generate_convex_collision() -> void:
	# Find all meshes in the collision group
	var mesh_instances = _find_mesh_instances_in_group(models_container, collision_group)
	
	if mesh_instances.is_empty():
		push_warning("No mesh instances found in group '", collision_group, "' for collision generation")
		return
	
	# Find or create collision shape
	var collision_shape = get_node_or_null("CollisionShape3D")
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)
		if Engine.is_editor_hint() and get_tree():
			collision_shape.owner = get_tree().edited_scene_root
	
	# If only one mesh, use it 
	if mesh_instances.size() == 1:
		collision_shape.shape = mesh_instances[0].mesh.create_convex_shape()
	else:
		# Combine multiple meshes into one collision shape
		var combined_shape = _create_combined_convex_shape(mesh_instances)
		collision_shape.shape = combined_shape
	
	if Engine.is_editor_hint():
		print("Generated convex collision for ", name, " from ", mesh_instances.size(), " mesh(es)")


func _find_mesh_instances_in_group(node: Node, group_name: String) -> Array[MeshInstance3D]:
	var results: Array[MeshInstance3D] = []
	
	if node is MeshInstance3D and node.is_in_group(group_name):
		results.append(node as MeshInstance3D)
	
	for child in node.get_children():
		results.append_array(_find_mesh_instances_in_group(child, group_name))
	
	return results


func _create_combined_convex_shape(mesh_instances: Array[MeshInstance3D]) -> ConvexPolygonShape3D:
	# Combine all vertices from all meshes
	var all_points: PackedVector3Array = []
	
	for mesh_instance in mesh_instances:
		if not mesh_instance.mesh:
			continue
		
		var surface_count = mesh_instance.mesh.get_surface_count()
		
		for surface_idx in range(surface_count):
			var arrays = mesh_instance.mesh.surface_get_arrays(surface_idx)
			var vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			
			# Just add vertices directly 
			for vertex in vertices:
				all_points.append(vertex)
	
	# Create convex hull from combined points
	var shape = ConvexPolygonShape3D.new()
	shape.points = all_points
	return shape

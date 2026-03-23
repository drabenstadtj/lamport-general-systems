@tool
extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/characters/player/player_noanim.tscn")

func _ready() -> void:
	if Engine.is_editor_hint():
		_draw_gizmo()
		return

	# Root node only exists when launched through the full game — skip if so
	if get_tree().root.get_node_or_null("Root") != null:
		return

	await get_tree().process_frame
	_spawn_player()

func _spawn_player() -> void:
	if player_scene == null:
		push_error("[TestSpawnPoint] player_scene is not set")
		return

	var player = player_scene.instantiate()
	get_tree().root.add_child(player)
	player.global_position = global_position
	player.global_rotation = global_rotation
	AIDirector.player = player

	# Find the NavigationRegion3D in this level and hand it to AIDirector
	var level := get_parent()
	var nav := _find_nav_region(level)
	if nav:
		AIDirector.nav_region = nav
	else:
		push_warning("[TestSpawnPoint] no NavigationRegion3D found in level — robots won't navigate")

	AIDirector.start_robots()
	print("[TestSpawnPoint] spawned player at ", global_position)

func _find_nav_region(node: Node) -> NavigationRegion3D:
	if node is NavigationRegion3D:
		return node
	for child in node.get_children():
		var result = _find_nav_region(child)
		if result:
			return result
	return null

# Editor gizmo so the spawn point is visible
func _draw_gizmo() -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh_instance.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 1.0, 0.4)
	mat.emission_energy_multiplier = 2.0
	mesh_instance.material_override = mat
	add_child(mesh_instance)

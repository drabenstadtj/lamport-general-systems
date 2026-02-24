@tool
extends Node3D
class_name ServerRack

@export var server_configs: Array[ServerSlotConfig] = []
@export var server_scene: PackedScene

func _ready():
	if not Engine.is_editor_hint():
		spawn_servers()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var has_active := false
	for c in server_configs:
		if c != null and c.is_active_node:
			has_active = true
			break
	var ind := get_node_or_null("ActiveIndicator")
	if has_active and ind == null:
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.0, 1.0, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.0, 1.0, 0.2)
		mat.emission_energy_multiplier = 3.0
		sphere.surface_set_material(0, mat)
		var m := MeshInstance3D.new()
		m.name = "ActiveIndicator"
		m.mesh = sphere
		m.position = Vector3(0, 2.5, 0)
		add_child(m)
	elif not has_active and ind != null:
		ind.queue_free()

func spawn_servers():
	# Get all available slots
	var available_slots = get_available_slot_indices()

	# Shuffle for random assignment
	available_slots.shuffle()
	var random_slot_index = 0

	for config in server_configs:
		if not config:
			continue

		var slot_index = config.slot_index

		# If slot_index is -1 or not set, use random
		if slot_index < 0:
			if random_slot_index < available_slots.size():
				slot_index = available_slots[random_slot_index]
				random_slot_index += 1
			else:
				continue

		# Find the slot marker
		var slot = get_slot_node(slot_index)
		if not slot:
			push_warning("ServerRack: Slot %d not found" % slot_index)
			continue

		# Instantiate the server box
		var server: Server
		if config.custom_server_scene:
			server = config.custom_server_scene.instantiate()
		elif server_scene:
			server = server_scene.instantiate()
		else:
			push_error("ServerRack: No server box scene assigned!")
			continue

		# Configure the server
		server.is_active = config.is_active_node
		server.node_id = config.node_id if config.is_active_node else -1

		# Add to slot
		slot.add_child(server)
		server.position = Vector3.ZERO

func get_available_slot_indices() -> Array[int]:
	var indices: Array[int] = []
	var slots = get_node_or_null("Slots")
	if not slots:
		return indices

	for child in slots.get_children():
		# Parse slot number from name
		var slot_name = child.name
		if slot_name.begins_with("Slot"):
			var num_str = slot_name.substr(4)  # Get everything after "Slot"
			if num_str.is_valid_int():
				indices.append(num_str.to_int())

	return indices

func get_slot_node(slot_index: int) -> Node3D:
	var slots = get_node_or_null("Slots")
	if slots:
		return slots.get_node_or_null("Slot%d" % slot_index)
	return null

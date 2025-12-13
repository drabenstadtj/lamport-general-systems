extends Node3D
class_name ServerRack

@export var server_configs: Array[ServerSlotConfig] = []
@export var server_box_scene: PackedScene

func _ready():
	spawn_servers()

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
		var server_box: ServerBox
		if config.custom_server_scene:
			server_box = config.custom_server_scene.instantiate()
		elif server_box_scene:
			server_box = server_box_scene.instantiate()
		else:
			push_error("ServerRack: No server box scene assigned!")
			continue
		
		# Add to slot
		slot.add_child(server_box)
		server_box.position = Vector3.ZERO
		
		# Configure the server
		server_box.is_active = config.is_active_node
		server_box.node_id = config.node_id if config.is_active_node else -1

func get_available_slot_indices() -> Array[int]:
	var indices: Array[int] = []
	var slots = get_node_or_null("Slots")
	if not slots:
		return indices
	
	for child in slots.get_children():
		# Parse slot number from name (e.g., "Slot5" -> 5)
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

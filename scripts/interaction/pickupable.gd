extends Node

@export var item_root_path: NodePath = NodePath("../..")
## If true, returns to original position when dropped
@export var return_to_position: bool = true  

# References
var interactable: Node 
var item_root: Node3D
var is_held: bool = false

# Track velocity
var previous_position: Vector3
var current_velocity: Vector3


func _ready() -> void:
	# Get item root from exported path
	if item_root_path:
		item_root = get_node(item_root_path) as Node3D
	else:
		push_error("Pickupable: item_root_path not set on ", get_parent().name)
	
	# Get the interactable component 
	var area = get_parent().get_parent()
	interactable = area.get_node_or_null("Interactable")
	
	if not interactable:
		push_error("Pickupable: No Interactable node found")
		return
	
	# Connect to interactable signal
	if interactable.has_signal("interacted"):
		interactable.connect("interacted", _on_interact)


func _process(delta: float) -> void:
	# Track velocity while holding (so that inertia is kept when dropped
	if is_held and item_root:
		var current_pos = item_root.global_position
		if previous_position != Vector3.ZERO:
			current_velocity = (current_pos - previous_position) / delta
		previous_position = current_pos


func _on_interact(player) -> void:
	if not item_root:
		return
	
	# Pick it up
	_start_viewing(player)


func _start_viewing(player) -> void:
	if player.has_node("ItemViewer") and item_root:
		var item_viewer = player.get_node("ItemViewer") as ItemViewer
		
		# Freeze physics if it's a RigidBody3D
		if item_root is RigidBody3D:
			item_root.freeze = true
		
		is_held = true
		previous_position = item_root.global_position
		current_velocity = Vector3.ZERO
		
		# Pass whether to restore position
		item_viewer.start_viewing(item_root, return_to_position)
		
		# Connect to viewing_ended signal
		if not item_viewer.viewing_ended.is_connected(_on_viewing_ended):
			item_viewer.viewing_ended.connect(_on_viewing_ended)


func _on_viewing_ended() -> void:
	if not item_root:
		return
	
	is_held = false
	
	# Unfreeze and apply tracked velocity
	if item_root is RigidBody3D:
		item_root.freeze = false
		item_root.linear_velocity = current_velocity
	
	# Reset tracking
	previous_position = Vector3.ZERO
	current_velocity = Vector3.ZERO

extends RayCast3D

var current_interactable = null
@export var raycast_length: float = 3.0

func _ready():
	target_position = Vector3(0, 0, -raycast_length)
	enabled = true
	collide_with_areas = true
	collide_with_bodies = true
	
func _physics_process(_delta):
	_update_current_interactable()

func _update_current_interactable():
	var previous_interactable = current_interactable
	current_interactable = null
	
	if is_colliding():
		var collider = get_collider()
		if collider:
			var interactable = collider.get_node_or_null("Interactable")
			if interactable and interactable.enabled and interactable.can_interact_from(global_position):
				current_interactable = interactable
	
	if current_interactable != previous_interactable:
		if current_interactable:
			HUD.show_interaction_prompt(current_interactable.get_prompt())
		else:
			HUD.hide_interaction_prompt()

func try_interact(player):
	if current_interactable:
		current_interactable.interact(player)

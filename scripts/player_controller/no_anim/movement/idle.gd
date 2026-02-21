extends State

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if input_dir.length() > 0.1:
		get_parent().transition_to("Walking")
		return
	
	if Input.is_action_pressed("crouch"):
		get_parent().transition_to("Crouching")
		return
	
	if Input.is_action_just_pressed("jump") and actor.is_on_floor():
		get_parent().transition_to("Jumping")
		return
	
	# Apply friction
	actor.velocity.x = move_toward(actor.velocity.x, 0, actor.friction * delta)
	actor.velocity.z = move_toward(actor.velocity.z, 0, actor.friction * delta)
	
	# Apply gravity
	if not actor.is_on_floor():
		actor.velocity.y -= actor.gravity * delta
	
	actor.move_and_slide()

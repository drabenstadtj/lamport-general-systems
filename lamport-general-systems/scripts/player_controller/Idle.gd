extends State

func enter() -> void:
	#print("Entering Idle state")
	if player.has_node("AnimationPlayer"):
		player.get_node("AnimationPlayer").play("idle")

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Check for movement
	if input_dir.length() > 0.1:
		get_parent().transition_to("Walking")
		return
	
	# Check for crouch
	if Input.is_action_pressed("crouch"):
		get_parent().transition_to("Crouching")
		return
	
	# Check for jump
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		get_parent().transition_to("Jumping")
		return
	
	# FIXED: Apply friction to stop sliding
	if player.is_on_floor():
		player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, player.friction * delta)
	
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	player.move_and_slide()

extends State

func enter() -> void:
	#print("Entering Walking state")
	# Don't force stand_up here - let the crouching state handle it
	# player.stand_up()  # REMOVED
	
	if player.has_node("AnimationPlayer"):
		player.get_node("AnimationPlayer").play("walk")

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		
	# Check for crouch while moving
	if Input.is_action_pressed("crouch"):
		get_parent().transition_to("Crouching")
		return
	
	# Check if stopped moving
	if input_dir.length() < 0.1:
		get_parent().transition_to("Idle")
		return
	
	# Check for sprint
	if Input.is_action_pressed("sprint"):
		get_parent().transition_to("Running")
		return
	
	# Check for jump
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		get_parent().transition_to("Jumping")
		return
	
	# Calculate movement direction relative to player's rotation (for FPS)
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction and player.is_on_floor():
		# FIXED: Use lerp for acceleration instead of direct assignment
		var target_velocity = direction * player.walk_speed
		player.velocity.x = lerp(player.velocity.x, target_velocity.x, player.acceleration * delta)
		player.velocity.z = lerp(player.velocity.z, target_velocity.z, player.acceleration * delta)
	else:
		# FIXED: Apply friction when no input
		player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, player.friction * delta)
	
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	player.move_and_slide()

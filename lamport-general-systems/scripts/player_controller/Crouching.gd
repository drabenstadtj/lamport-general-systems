extends State

func enter() -> void:
	#print("Entering Crouching state")
	player.crouch_down()
	
	if player.has_node("AnimationPlayer"):
		player.get_node("AnimationPlayer").play("crouch_idle")

func exit() -> void:
	# Only stand up if there's room
	if not player.check_ceiling():
		player.stand_up()

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Check if trying to stand up
	if not Input.is_action_pressed("crouch"):
		# Only stand if there's no ceiling above
		if not player.check_ceiling():
			if input_dir.length() > 0.1:
				get_parent().transition_to("Walking")
			else:
				get_parent().transition_to("Idle")
			return
		# FIXED: If there's a ceiling, stay crouched but DON'T return - continue processing movement
	
	# Can't jump while crouching
	# But can move while crouched
	if input_dir.length() > 0.1:
		if player.has_node("AnimationPlayer"):
			player.get_node("AnimationPlayer").play("crouch_walk")
		
		# Calculate movement direction relative to player's rotation (for FPS)
		var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if direction:
			# FIXED: Use lerp for smooth acceleration like in Walking state
			var target_velocity = direction * player.crouch_speed
			player.velocity.x = lerp(player.velocity.x, target_velocity.x, player.acceleration * delta)
			player.velocity.z = lerp(player.velocity.z, target_velocity.z, player.acceleration * delta)
	else:
		# Standing still while crouched
		if player.has_node("AnimationPlayer"):
			player.get_node("AnimationPlayer").play("crouch_idle")
		
		# Apply friction
		player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, player.friction * delta)
	
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	player.move_and_slide()

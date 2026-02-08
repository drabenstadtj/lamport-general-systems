extends State

func enter() -> void:
	player.crouch_down()

func exit() -> void:
	if not player.check_ceiling():
		player.stand_up()

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Check if trying to stand up
	if not Input.is_action_pressed("crouch"):
		if not player.check_ceiling():
			if input_dir.length() > 0.1:
				get_parent().transition_to("Walking")
			else:
				get_parent().transition_to("Idle")
			return
	
	# Movement
	if input_dir.length() > 0.1:
		var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			var target_velocity = direction * player.crouch_speed
			player.velocity.x = lerp(player.velocity.x, target_velocity.x, player.acceleration * delta)
			player.velocity.z = lerp(player.velocity.z, target_velocity.z, player.acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, player.friction * delta)
	
	# Gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	player.move_and_slide()

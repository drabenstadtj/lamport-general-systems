extends State

var was_sprinting: bool = false

func enter() -> void:
	# Higher jump if sprinting
	player.velocity.y = player.jump_velocity * (1.3 if was_sprinting else 1.1)

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Air control
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		var target_speed = player.run_speed if was_sprinting else player.walk_speed
		player.velocity.x = lerp(player.velocity.x, direction.x * target_speed, player.air_control * delta)
		player.velocity.z = lerp(player.velocity.z, direction.z * target_speed, player.air_control * delta)
	
	# Gravity
	player.velocity.y -= player.gravity * delta
	
	# Variable jump height
	if Input.is_action_just_released("jump") and player.velocity.y > 0:
		player.velocity.y *= 0.4
	
	player.move_and_slide()
	
	# Check if landed
	if player.is_on_floor() and player.velocity.y <= 0:
		# Transition based on input
		if Input.is_action_pressed("crouch"):
			get_parent().transition_to("Crouching")
		elif input_dir.length() > 0.1:
			if Input.is_action_pressed("sprint"):
				get_parent().transition_to("Running")
			else:
				get_parent().transition_to("Walking")
		else:
			get_parent().transition_to("Idle")

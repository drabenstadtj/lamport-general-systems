extends State

func enter() -> void:
	player.set_sprinting(true)

func exit() -> void:
	player.set_sprinting(false)

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# State transitions
	if Input.is_action_pressed("crouch"):
		get_parent().transition_to("Crouching")
		return
	
	if input_dir.length() < 0.1:
		get_parent().transition_to("Idle")
		return
	
	if not Input.is_action_pressed("sprint"):
		get_parent().transition_to("Walking")
		return
	
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		var jumping_state = get_parent().get_node("Jumping")
		if jumping_state:
			jumping_state.was_sprinting = true
		get_parent().transition_to("Jumping")
		return
	
	# Movement
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction and player.is_on_floor():
		var target_velocity = direction * player.run_speed
		player.velocity.x = lerp(player.velocity.x, target_velocity.x, player.acceleration * delta)
		player.velocity.z = lerp(player.velocity.z, target_velocity.z, player.acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, player.friction * delta)
	
	# Gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	player.move_and_slide()

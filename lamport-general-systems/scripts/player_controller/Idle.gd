extends State

func enter() -> void:	
	if player.has_node("AnimationPlayer"):
		player.get_node("AnimationPlayer").play("idle")

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Check for crouch
	if Input.is_action_pressed("crouch"):
		get_parent().transition_to("Crouching")
		return
	
	# Check for movement
	if input_dir.length() > 0.1:
		if Input.is_action_pressed("sprint"):
			get_parent().transition_to("Running")
		else:
			get_parent().transition_to("Walking")
		return
	
	# Check for jump
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		get_parent().transition_to("Jumping")
		return
	
	# Apply gravity and friction
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta

	# Apply friction - decelerate while maintaining direction
	var horizontal_velocity = Vector2(player.velocity.x, player.velocity.z)
	var speed = horizontal_velocity.length()

	if speed > 0:
		var new_speed = max(speed - player.friction * delta, 0)
		horizontal_velocity = horizontal_velocity.normalized() * new_speed
		player.velocity.x = horizontal_velocity.x
		player.velocity.z = horizontal_velocity.y

	player.move_and_slide()

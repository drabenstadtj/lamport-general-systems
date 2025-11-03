extends State

func enter() -> void:
	print("Entering Walking state")
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
	
	if direction:
		player.velocity.x = direction.x * player.walk_speed
		player.velocity.z = direction.z * player.walk_speed
	
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	player.move_and_slide()

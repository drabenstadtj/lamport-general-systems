extends State

func enter() -> void:
	#print("Entering Running state")
	# Don't force stand_up here - let the crouching state handle it
	# player.stand_up()  # REMOVED
	
	if player.has_node("AnimationPlayer"):
		player.get_node("AnimationPlayer").play("run")

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Can't crouch while running
	if Input.is_action_pressed("crouch"):
		get_parent().transition_to("Crouching")
		return
	
	# Check if stopped moving
	if input_dir.length() < 0.1:
		get_parent().transition_to("Idle")
		return
	
	# Check if stopped sprinting
	if not Input.is_action_pressed("sprint"):
		get_parent().transition_to("Walking")
		return
	
	# Check for jump
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		get_parent().transition_to("Jumping")
		return
	
	# Calculate movement direction relative to player's rotation (for FPS)
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction and player.is_on_floor():
		player.velocity.x = direction.x * player.run_speed
		player.velocity.z = direction.z * player.run_speed
	
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	player.move_and_slide()

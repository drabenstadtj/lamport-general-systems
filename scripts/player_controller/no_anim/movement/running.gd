extends State

var _footstep_timer: float = 0.5

func enter() -> void:
	actor.set_sprinting(true)

func exit() -> void:
	actor.set_sprinting(false)

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
	
	if Input.is_action_just_pressed("jump") and actor.is_on_floor():
		var jumping_state = get_parent().get_node("Jumping")
		if jumping_state:
			jumping_state.was_sprinting = true
		get_parent().transition_to("Jumping")
		return
	
	# Movement
	var direction = (actor.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction and actor.is_on_floor():
		var target_velocity = direction * actor.run_speed
		actor.velocity.x = lerp(actor.velocity.x, target_velocity.x, actor.acceleration * delta)
		actor.velocity.z = lerp(actor.velocity.z, target_velocity.z, actor.acceleration * delta)
	else:
		actor.velocity.x = move_toward(actor.velocity.x, 0, actor.friction * delta)
		actor.velocity.z = move_toward(actor.velocity.z, 0, actor.friction * delta)
	
	# Gravity
	if not actor.is_on_floor():
		actor.velocity.y -= actor.gravity * delta
	
	# emit sound to AI's
	_footstep_timer += delta
	if _footstep_timer >= 0.5:
		AIDirector.emit_sound(actor.global_position, 0.9)
		_footstep_timer = 0.0
		
	actor.move_and_slide()

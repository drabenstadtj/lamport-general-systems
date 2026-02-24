extends State

var _footstep_timer: float = 1.2
func enter() -> void:
	actor.crouch_down()

func exit() -> void:
	if not actor.check_ceiling():
		actor.stand_up()

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Check if trying to stand up
	if not Input.is_action_pressed("crouch"):
		if not actor.check_ceiling():
			if input_dir.length() > 0.1:
				get_parent().transition_to("Walking")
			else:
				get_parent().transition_to("Idle")
			return
	
	# Movement
	if input_dir.length() > 0.1:
		var direction = (actor.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			var target_velocity = direction * actor.crouch_speed
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
		AIDirector.emit_sound(actor.global_position, 0.2)
		_footstep_timer = 0.0
	
	actor.move_and_slide()

extends State

var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var blend_position: Vector2 = Vector2.ZERO  # <-- ADD THIS

func enter() -> void:
	#print("Entering Crouching state")
	player.crouch_down()
	
	if player.has_node("AnimationTree"):
		anim_tree = player.get_node("AnimationTree")
		playback = anim_tree.get("parameters/playback")
		playback.travel("Crouching")
	elif player.has_node("AnimationPlayer"):
		player.get_node("AnimationPlayer").play("AnimationLibrary_Godot/Crouch_Idle")
	
	blend_position = Vector2.ZERO  # <-- ADD THIS

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
	
	# Update crouch animation with SMOOTHING
	if anim_tree:
		var target_blend = Vector2(input_dir.x, -input_dir.y)
		# SMOOTH the blend position instead of setting directly
		blend_position = blend_position.lerp(target_blend, 8.0 * delta)  # <-- CHANGE THIS LINE
		anim_tree.set("parameters/Crouching/blend_position", blend_position)
	
	# Handle movement
	if input_dir.length() > 0.1:
		var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if direction:
			var target_velocity = direction * player.crouch_speed
			player.velocity.x = lerp(player.velocity.x, target_velocity.x, player.acceleration * delta)
			player.velocity.z = lerp(player.velocity.z, target_velocity.z, player.acceleration * delta)
	else:
		# Apply friction
		player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, player.friction * delta)
	
	# Apply gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	player.move_and_slide()

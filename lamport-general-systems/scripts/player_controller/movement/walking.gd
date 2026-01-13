extends State

var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

func enter() -> void:
	#print("Entering Walking state")
	
	if player.has_node("AnimationTree"):
		anim_tree = player.get_node("AnimationTree")
		playback = anim_tree.get("parameters/playback")
		playback.travel("Grounded")
		var grounded_playback = anim_tree.get("parameters/Grounded/playback")
		if grounded_playback:
			# Make sure this matches your animation name in AnimationTree
			grounded_playback.travel("Walk")
	elif player.has_node("AnimationPlayer"):
		player.get_node("AnimationPlayer").play("AnimationLibrary_Godot/Walk")

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		
	if Input.is_action_pressed("crouch"):
		get_parent().transition_to("Crouching")
		return
	
	if input_dir.length() < 0.1:
		get_parent().transition_to("Idle")
		return
	
	if Input.is_action_pressed("sprint"):
		get_parent().transition_to("Running")
		return
	
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		# Set was_sprinting to false when jumping from walk
		var jumping_state = get_parent().get_node("Jumping")
		if jumping_state:
			jumping_state.was_sprinting = false
		get_parent().transition_to("Jumping")
		return
	
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction and player.is_on_floor():
		var target_velocity = direction * player.walk_speed
		player.velocity.x = lerp(player.velocity.x, target_velocity.x, player.acceleration * delta)
		player.velocity.z = lerp(player.velocity.z, target_velocity.z, player.acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, player.friction * delta)
	
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	player.move_and_slide()

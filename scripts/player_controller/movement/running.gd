extends State
var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

func enter() -> void:
	#print("Entering Running state")
	player.set_sprinting(true) 
	
	if player.has_node("AnimationTree"):
		anim_tree = player.get_node("AnimationTree")
		playback = anim_tree.get("parameters/playback")
		playback.travel("Grounded")
		var grounded_playback = anim_tree.get("parameters/Grounded/playback")
		if grounded_playback:
			grounded_playback.travel("Sprint")
	elif player.has_node("AnimationPlayer"):
		player.get_node("AnimationPlayer").play("AnimationLibrary_Godot/Sprint")

func exit() -> void:
	player.set_sprinting(false)

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
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
	
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction and player.is_on_floor():
		var target_velocity = direction * player.run_speed
		player.velocity.x = lerp(player.velocity.x, target_velocity.x, player.acceleration * delta)
		player.velocity.z = lerp(player.velocity.z, target_velocity.z, player.acceleration * delta)
	
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	player.move_and_slide()

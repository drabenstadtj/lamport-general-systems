extends State

var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

func enter() -> void:
	#print("Entering Walking state")
	
	if actor.has_node("AnimationTree"):
		anim_tree = actor.get_node("AnimationTree")
		playback = anim_tree.get("parameters/playback")
		playback.travel("Grounded")
		var grounded_playback = anim_tree.get("parameters/Grounded/playback")
		if grounded_playback:
			# Make sure this matches your animation name in AnimationTree
			grounded_playback.travel("Walk")
	elif actor.has_node("Animationactor"):
		actor.get_node("Animationactor").play("AnimationLibrary_Godot/Walk")

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
	
	if Input.is_action_just_pressed("jump") and actor.is_on_floor():
		# Set was_sprinting to false when jumping from walk
		var jumping_state = get_parent().get_node("Jumping")
		if jumping_state:
			jumping_state.was_sprinting = false
		get_parent().transition_to("Jumping")
		return
	
	var direction = (actor.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction and actor.is_on_floor():
		var target_velocity = direction * actor.walk_speed
		actor.velocity.x = lerp(actor.velocity.x, target_velocity.x, actor.acceleration * delta)
		actor.velocity.z = lerp(actor.velocity.z, target_velocity.z, actor.acceleration * delta)
	else:
		actor.velocity.x = move_toward(actor.velocity.x, 0, actor.friction * delta)
		actor.velocity.z = move_toward(actor.velocity.z, 0, actor.friction * delta)
	
	if not actor.is_on_floor():
		actor.velocity.y -= actor.gravity * delta
	
	actor.move_and_slide()

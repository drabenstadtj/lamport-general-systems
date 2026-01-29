extends State

var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

func enter() -> void:
	#print("Entering Idle state")
	
	# Get AnimationTree reference
	if player.has_node("AnimationTree"):
		anim_tree = player.get_node("AnimationTree")
		playback = anim_tree.get("parameters/playback")
		# Travel to Grounded state machine
		playback.travel("Grounded")
		# Get nested playback and explicitly go to Idle
		var grounded_playback = anim_tree.get("parameters/Grounded/playback")
		if grounded_playback:
			grounded_playback.travel("Idle")
	elif player.has_node("AnimationPlayer"):
		player.get_node("AnimationPlayer").play("AnimationLibrary_Godot/Idle")

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if input_dir.length() > 0.1:
		get_parent().transition_to("Walking")
		return
	
	if Input.is_action_pressed("crouch"):
		get_parent().transition_to("Crouching")
		return
	
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		get_parent().transition_to("Jumping")
		return
	
	if player.is_on_floor():
		player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, player.friction * delta)
	
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	
	player.move_and_slide()

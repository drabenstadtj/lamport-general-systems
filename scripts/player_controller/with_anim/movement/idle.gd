extends State

var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

func enter() -> void:
	#print("Entering Idle state")
	
	# Get AnimationTree reference
	if actor.has_node("AnimationTree"):
		anim_tree = actor.get_node("AnimationTree")
		playback = anim_tree.get("parameters/playback")
		# Travel to Grounded state machine
		playback.travel("Grounded")
		# Get nested playback and explicitly go to Idle
		var grounded_playback = anim_tree.get("parameters/Grounded/playback")
		if grounded_playback:
			grounded_playback.travel("Idle")
	elif actor.has_node("Animationactor"):
		actor.get_node("Animationactor").play("AnimationLibrary_Godot/Idle")

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	if input_dir.length() > 0.1:
		get_parent().transition_to("Walking")
		return
	
	if Input.is_action_pressed("crouch"):
		get_parent().transition_to("Crouching")
		return
	
	if Input.is_action_just_pressed("jump") and actor.is_on_floor():
		get_parent().transition_to("Jumping")
		return
	
	if actor.is_on_floor():
		actor.velocity.x = move_toward(actor.velocity.x, 0, actor.friction * delta)
		actor.velocity.z = move_toward(actor.velocity.z, 0, actor.friction * delta)
	
	if not actor.is_on_floor():
		actor.velocity.y -= actor.gravity * delta
	
	actor.move_and_slide()

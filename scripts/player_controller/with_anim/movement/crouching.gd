extends State

var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var blend_position: Vector2 = Vector2.ZERO  

func enter() -> void:
	actor.crouch_down()
	
	if actor.has_node("AnimationTree"):
		anim_tree = actor.get_node("AnimationTree")
		playback = anim_tree.get("parameters/playback")
		playback.travel("Crouching")
	elif actor.has_node("Animationactor"):
		actor.get_node("Animationactor").play("AnimationLibrary_Godot/Crouch_Idle")
	
	blend_position = Vector2.ZERO

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
	
	if anim_tree:
		var target_blend = Vector2(input_dir.x, -input_dir.y)
		# Smooth the blend position instead of setting directly
		blend_position = blend_position.lerp(target_blend, 8.0 * delta)  
		anim_tree.set("parameters/Crouching/blend_position", blend_position)
	
	# Handle movement
	if input_dir.length() > 0.1:
		var direction = (actor.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if direction:
			var target_velocity = direction * actor.crouch_speed
			actor.velocity.x = lerp(actor.velocity.x, target_velocity.x, actor.acceleration * delta)
			actor.velocity.z = lerp(actor.velocity.z, target_velocity.z, actor.acceleration * delta)
	else:
		# Apply friction
		actor.velocity.x = move_toward(actor.velocity.x, 0, actor.friction * delta)
		actor.velocity.z = move_toward(actor.velocity.z, 0, actor.friction * delta)
	
	# Apply gravity
	if not actor.is_on_floor():
		actor.velocity.y -= actor.gravity * delta
	
	actor.move_and_slide()

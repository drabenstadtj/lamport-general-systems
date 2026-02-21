extends State

var anim_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var was_sprinting: bool = false
var jump_started: bool = false
var has_landed: bool = false

func enter() -> void:
	#print("Entering Jumping state")
	# Get AnimationTree reference
	if actor.has_node("AnimationTree"):
		anim_tree = actor.get_node("AnimationTree")
		playback = anim_tree.get("parameters/playback")
		# Travel to Jumping state machine (will auto-start at Jump_Enter/Jump_Start)
		playback.travel("Jumping")
	elif actor.has_node("Animationactor"):
		# Fallback to Animationactor if AnimationTree not found
		actor.get_node("Animationactor").play("AnimationLibrary_Godot/Jump")
	
	# Jump with more force if sprinting
	if was_sprinting:
		actor.velocity.y = actor.jump_velocity * 1.2
	else:
		actor.velocity.y = actor.jump_velocity
	
	jump_started = true
	has_landed = false

func exit() -> void:
	jump_started = false
	has_landed = false

func physics_update(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Air control - can move horizontally while jumping
	var direction = (actor.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		var target_speed = actor.run_speed if was_sprinting else actor.walk_speed
		# Reduced air control
		actor.velocity.x = lerp(actor.velocity.x, direction.x * target_speed, actor.air_control * delta)
		actor.velocity.z = lerp(actor.velocity.z, direction.z * target_speed, actor.air_control * delta)
	
	# Apply gravity
	actor.velocity.y -= actor.gravity * delta
	
	# Variable jump height - release jump early for shorter jump
	if Input.is_action_just_released("jump") and actor.velocity.y > 0:
		actor.velocity.y *= 0.5
	
	actor.move_and_slide()
	
	# Check if we've started falling (past apex of jump)
	if jump_started and actor.velocity.y < 0:
		# Transition to fall/loop animation in the Jumping state machine
		if anim_tree:
			var jumping_playback = anim_tree.get("parameters/Jumping/playback")
			if jumping_playback:
				jumping_playback.travel("Jump")
		jump_started = false
	
	# Check if landed
	if actor.is_on_floor() and actor.velocity.y <= 0 and not has_landed:
		has_landed = true
		
		# Get camera pivot through CameraController
		var camera_controller = actor.get_node_or_null("CameraController")
		if camera_controller:
			var camera_pivot = actor.get_node_or_null("CameraPivot")
			if camera_pivot:
				var tween = create_tween()
				var start_pos = camera_pivot.position
				var dip_pos = start_pos + Vector3(0, -0.5, -0.2)  # Down and forward
				tween.tween_property(camera_pivot, "position", dip_pos, 0.2).set_ease(Tween.EASE_OUT)
				tween.tween_property(camera_pivot, "position", start_pos, 0.2).set_ease(Tween.EASE_IN_OUT)
		
		# Play landing animation
		if anim_tree:
			var jumping_playback = anim_tree.get("parameters/Jumping/playback")
			if jumping_playback:
				jumping_playback.travel("Jump_Exit")
		
		# Wait a short moment for landing animation, then transition
		await get_tree().create_timer(0.25).timeout
		
		# Transition based on input
		if Input.is_action_pressed("crouch"):
			get_parent().transition_to("Crouching")
		elif input_dir.length() > 0.1:
			if Input.is_action_pressed("sprint"):
				get_parent().transition_to("Running")
			else:
				get_parent().transition_to("Walking")
		else:
			get_parent().transition_to("Idle")

extends State
class_name HuntState

enum AttackPhase { NONE, ENTERING, HITTING, EXITING }

var lost_sight_timer: float = 0.0
var lost_sight_timeout: float = 15.0
var _prev_move_speed: float = 0.0
var _had_detection: bool = false
var _attack_phase := AttackPhase.NONE

func enter() -> void:
	print("[HuntState] entered")
	actor.sensory_component.visual_confidence = 0.0
	actor.sensory_component.is_threat_confirmed = false
	lost_sight_timer = 0.0
	_attack_phase = AttackPhase.NONE
	_prev_move_speed = actor.move_speed
	actor.move_speed = actor.hunt_move_speed

func exit() -> void:
	print("[HuntState] exited — lost_sight_timer: ", snapped(lost_sight_timer, 0.1))
	actor.move_speed = _prev_move_speed
	_attack_phase = AttackPhase.NONE

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	if not actor.hostile:
		actor.state_machine.transition_to("Patrol")
		return

	var sensory: SensoryComponent = actor.sensory_component

	if _attack_phase != AttackPhase.NONE:
		_update_attack()
	else:
		# navigate to live position when in LOS, otherwise last known
		if sensory.has_detection:
			actor.navigate_to(AIDirector.player.global_position)
		else:
			actor.navigate_to(sensory.last_detected_position)

		if actor.target_in_attack_range():
			_start_attack()
		else:
			actor.play_anim(actor.get_move_anim("Jog_Fwd"))

	# count down hunt timer when LOS is lost; reset when regained
	if lost_sight_timer >= lost_sight_timeout:
		print("[HuntState] hunt timed out — transitioning to Investigate")
		actor.state_machine.transition_to("Investigate")
	elif sensory.has_detection:
		if not _had_detection:
			print("[HuntState] sight regained")
		lost_sight_timer = 0.0
	else:
		if _had_detection:
			print("[HuntState] sight lost — timer running (timeout: ", lost_sight_timeout, "s)")
		lost_sight_timer += _delta

	_had_detection = sensory.has_detection

func _start_attack() -> void:
	print("[HuntState] attack — entering stance")
	_attack_phase = AttackPhase.ENTERING
	actor.navigate_to(actor.global_position) # stop moving
	actor.animation_player.play("AnimationLibrary_Godot/PunchKick_Enter")

func _update_attack() -> void:
	if actor.animation_player.is_playing():
		return
	match _attack_phase:
		AttackPhase.ENTERING:
			print("[HuntState] attack — hitting")
			_attack_phase = AttackPhase.HITTING
			actor.animation_player.play("AnimationLibrary_Godot/Punch_Jab")
		AttackPhase.HITTING:
			print("[HuntState] attack — exiting stance")
			_attack_phase = AttackPhase.EXITING
			actor.animation_player.play("AnimationLibrary_Godot/PunchKick_Exit")
		AttackPhase.EXITING:
			print("[HuntState] attack — done")
			_attack_phase = AttackPhase.NONE

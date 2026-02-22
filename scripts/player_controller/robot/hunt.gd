extends State
class_name HuntState

var hunt_timer: float = 0.0
var hunt_duration: float = 15.0 #15 sec
var _prev_move_speed: float = 0.0

func enter() -> void:
	print("[HuntState] entered")
	# reset confidence so is_threat_confirmed can be re-earned from current LOS
	actor.sensory_component.visual_confidence = 0.0
	actor.sensory_component.is_threat_confirmed = false
	hunt_timer = 0.0
	_prev_move_speed = actor.move_speed
	actor.move_speed = actor.hunt_move_speed

func exit() -> void:
	print("[HuntState] exited — hunt_timer: ", snapped(hunt_timer, 0.1))
	actor.move_speed = _prev_move_speed

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	# navigate toward player's live position only when we have LOS
	# otherwise head to last known position
	if actor.sensory_component.has_detection:
		actor.navigate_to(AIDirector.player.global_position)
	else:
		actor.navigate_to(actor.sensory_component.last_detected_position)

	# check if close enough
	if actor.target_in_attack_range():
		print("[HuntState] player in attack range")
		#attack
		pass

	if hunt_timer >= hunt_duration:
		print("[HuntState] hunt timed out — transitioning to Investigate")
		actor.state_machine.transition_to("Investigate")
	else:
		# use has_detection (per-frame LOS) to decide whether to count down
		if actor.sensory_component.has_detection:
			hunt_timer = 0.0
		else:
			hunt_timer += _delta
			print("[HuntState] lost sight — timer: ", snapped(hunt_timer, 0.1), " / ", hunt_duration)

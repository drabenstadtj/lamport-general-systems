extends State
class_name HuntState

var lost_sight_timer: float = 0.0
var lost_sight_timeout: float = 15.0
var _prev_move_speed: float = 0.0

func enter() -> void:
	print("[HuntState] entered")
	actor.sensory_component.visual_confidence = 0.0
	actor.sensory_component.is_threat_confirmed = false
	lost_sight_timer = 0.0
	_prev_move_speed = actor.move_speed
	actor.move_speed = actor.hunt_move_speed

func exit() -> void:
	print("[HuntState] exited — lost_sight_timer: ", snapped(lost_sight_timer, 0.1))
	actor.move_speed = _prev_move_speed

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	var sensory: SensoryComponent = actor.sensory_component

	# navigate to live position when in LOS, otherwise last known
	if sensory.has_detection:
		actor.navigate_to(AIDirector.player.global_position)
	else:
		actor.navigate_to(sensory.last_detected_position)

	if actor.target_in_attack_range():
		print("[HuntState] player in attack range")
		# TODO: attack

	# count down hunt timer when LOS is lost; reset when regained
	if lost_sight_timer >= lost_sight_timeout:
		print("[HuntState] hunt timed out — transitioning to Investigate")
		actor.state_machine.transition_to("Investigate")
	elif sensory.has_detection:
		lost_sight_timer = 0.0
	else:
		lost_sight_timer += _delta
		print("[HuntState] lost sight — timer: ", snapped(lost_sight_timer, 0.1), " / ", lost_sight_timeout)

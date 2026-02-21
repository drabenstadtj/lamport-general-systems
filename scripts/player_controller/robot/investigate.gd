extends State

class_name InvestigateState

var alertness_timer = 15.0 #sec

func enter() -> void:
	print("InvestigateState entered, last_detected_pos: ", actor.sensory_component.last_detected_position)
	alertness_timer = 15.0
	# clear prior confirmation so robot must freshly re-spot to escalate back to Hunt
	actor.sensory_component.visual_confidence = 0.0
	actor.sensory_component.is_threat_confirmed = false

func exit() -> void:
	# Called when exiting this state
	pass

func physics_update(_delta: float) -> void:
	# begin pathfind to lastdetected position
	if actor.sensory_component.has_detection:
		alertness_timer = 15.0
		var target: Vector3 = actor.sensory_component.last_detected_position
		actor.navigate_to(Vector3(target.x, target.y, actor.global_position.z))
	
	# continually check sensorycomponent for detections
	# if another detection is made then transition to hunt?
	if actor.sensory_component.is_threat_confirmed:
		actor.state_machine.transition_to("Hunt")
	
	# if alertness timer gets down to zero then transition back to patrol
	if alertness_timer >= 0.0:
		alertness_timer -= _delta
	else:
		actor.state_machine.transition_to("Patrol")
	pass

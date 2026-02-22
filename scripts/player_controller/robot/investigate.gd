extends State

class_name InvestigateState

var alertness_timer: float = 15.0 # sec
var search_radius: float = 3.0 # wander range around last detected position
var _search_origin: Vector3

func enter() -> void:
	print("InvestigateState entered, last_detected_pos: ", actor.sensory_component.last_detected_position)
	alertness_timer = 15.0
	# clear prior confirmation so robot must freshly re-spot to escalate back to Hunt
	actor.sensory_component.visual_confidence = 0.0
	actor.sensory_component.is_threat_confirmed = false
	_search_origin = actor.sensory_component.last_detected_position
	actor.navigate_to(_search_origin)

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	if actor.sensory_component.has_detection:
		# player spotted — update search origin and chase
		alertness_timer = 15.0
		_search_origin = actor.sensory_component.last_detected_position
		actor.navigate_to(_search_origin)
	elif actor.nav_agent.is_navigation_finished():
		# reached current target with no detection  wander nearby
		var offset := Vector3(
			randf_range(-search_radius, search_radius),
			0.0,
			randf_range(-search_radius, search_radius)
		)
		var map: RID = actor.nav_agent.get_navigation_map()
		var wander_point := NavigationServer3D.map_get_closest_point(map, _search_origin + offset)
		actor.navigate_to(wander_point)

	if actor.sensory_component.is_threat_confirmed:
		actor.state_machine.transition_to("Hunt")

	if alertness_timer >= 0.0:
		alertness_timer -= _delta
	else:
		actor.state_machine.transition_to("Patrol")

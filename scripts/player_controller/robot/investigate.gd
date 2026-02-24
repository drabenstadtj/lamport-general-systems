extends State
class_name InvestigateState

var search_timer: float = 15.0
var search_radius: float = 3.0
var _search_origin: Vector3

func enter() -> void:
	print("[InvestigateState] entered — last_detected_pos: ", actor.sensory_component.last_detected_position)
	var sensory: SensoryComponent = actor.sensory_component
	search_timer = 15.0
	sensory.visual_confidence = 0.0
	sensory.is_threat_confirmed = false
	_search_origin = sensory.last_detected_position
	actor.navigate_to(_search_origin)

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	if not actor.hostile:
		actor.state_machine.transition_to("Patrol")
		return

	var sensory: SensoryComponent = actor.sensory_component

	if sensory.has_detection:
		search_timer = 15.0
		_search_origin = sensory.last_detected_position
		actor.navigate_to(_search_origin)
	elif actor.nav_agent.is_navigation_finished():
		# wander nearby while searching
		var offset := Vector3(randf_range(-search_radius, search_radius), 0.0, randf_range(-search_radius, search_radius))
		var map: RID = actor.nav_agent.get_navigation_map()
		actor.navigate_to(NavigationServer3D.map_get_closest_point(map, _search_origin + offset))

	if sensory.is_threat_confirmed:
		actor.state_machine.transition_to("Hunt")
		return

	actor.play_anim(actor.get_move_anim("Walk", "Idle_LookAround"))
	search_timer -= _delta
	if search_timer <= 0.0:
		actor.state_machine.transition_to("Patrol")

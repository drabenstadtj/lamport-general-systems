extends State
class_name InvestigateState

@export var search_duration: float = 15.0
@export var search_radius: float = 3.0

var _search_timer: float = 0.0
var _search_origin: Vector3

func enter() -> void:
	print("[InvestigateState] enteredlast_detected_pos: ", actor.sensory_component.last_detected_position)
	var sensory: SensoryComponent = actor.sensory_component
	_search_timer = search_duration
	sensory.visual_confidence = 0.0
	sensory.is_threat_confirmed = false
	_search_origin = sensory.last_detected_position
	actor.navigate_to(_search_origin)

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	if not actor.hostile:
		actor.state_machine.transition_to("Patrol")
		return

	var sensory: SensoryComponent = actor.sensory_component

	if sensory.has_detection:
		# player spotted, refresh the search origin and keep moving toward them
		_search_timer = search_duration
		_search_origin = sensory.last_detected_position
		actor.navigate_to(_search_origin)
	elif actor.nav_agent.is_navigation_finished():
		# arrived at destination, pick a nearby wander point
		# retry up to 5 times to avoid snapping to navmesh boundary edges
		var map: RID = actor.nav_agent.get_navigation_map()
		var wander_point := actor.global_position
		for _i in range(5):
			var raw := actor.global_position + Vector3(randf_range(-search_radius, search_radius), 0.0, randf_range(-search_radius, search_radius))
			var nav_point := NavigationServer3D.map_get_closest_point(map, raw)
			var snap_drift := Vector2(raw.x - nav_point.x, raw.z - nav_point.z).length()
			if snap_drift < 0.75 and nav_point.distance_to(actor.global_position) > 1.0:
				wander_point = nav_point
				break
		actor.navigate_to(wander_point)

	# confidence threshold crossed, player is definitely there
	if sensory.is_threat_confirmed:
		actor.state_machine.transition_to("Hunt")
		return

	actor.play_anim(actor.get_move_anim("Walk", "Idle_LookAround"))
	_search_timer -= _delta
	if _search_timer <= 0.0:
		actor.state_machine.transition_to("Patrol")

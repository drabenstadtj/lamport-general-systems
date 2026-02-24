extends State
class_name PatrolState


func enter() -> void:
	print("[PatrolState] entered (index=%d)" % actor.patrol_index)
	actor.dormant_time = 0.0
	actor.navigate_to(_current_target())

func exit() -> void:
	print("[PatrolState] exited")
	actor.dormant_time = 0.0


func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	if actor.nav_agent.is_navigation_finished():
		var points: Array = actor.get_patrol_points()
		if points.is_empty():
			actor.navigate_to(_random_nav_point())
		else:
			actor.advance_patrol_index()
			print("[PatrolState] reached waypoint — advancing to index %d" % actor.patrol_index)
			actor.navigate_to(_current_target())

	if actor.sensory_component.has_detection:
		print("[PatrolState] detection — transitioning to Investigate")
		actor.state_machine.transition_to("Investigate")

	actor.play_anim(actor.get_move_anim("Walk"))
	actor.dormant_time += _delta

func _current_target() -> Vector3:
	var points: Array = actor.get_patrol_points()
	if points.is_empty():
		return _random_nav_point()
	actor.patrol_index = actor.patrol_index % points.size()  # safety clamp
	return points[actor.patrol_index].global_position

func _random_nav_point() -> Vector3:
	return NavigationServer3D.region_get_random_point(AIDirector.nav_region.get_rid(), 1, true)

extends State
class_name PatrolState


func enter() -> void:
	print("[PatrolState] entered")
	actor.dormant_time = 0.0
	actor.navigate_to(_random_nav_point())

func exit() -> void:
	print("[PatrolState] exited")
	actor.dormant_time = 0.0


func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	if actor.nav_agent.is_navigation_finished():
		actor.navigate_to(_random_nav_point())

	if actor.sensory_component.has_detection:
		print("[PatrolState] detection — transitioning to Investigate")
		actor.state_machine.transition_to("Investigate")

	actor.play_anim(actor.get_move_anim("Walk"))
	actor.dormant_time += _delta

func _random_nav_point() -> Vector3:
	return NavigationServer3D.region_get_random_point(AIDirector.nav_region.get_rid(), 1, true)

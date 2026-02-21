extends State
class_name PatrolState

func enter() -> void:
	print("[PatrolState] entered — actor: ", actor, " | nav_region: ", AIDirector.nav_region)
	# set animation to walk
	var random_point = NavigationServer3D.region_get_random_point(AIDirector.nav_region.get_rid(), 1, true)
	print("[PatrolState] first patrol target: ", random_point)
	actor.navigate_to(random_point)
	pass

func exit() -> void:
	print("[PatrolState] exited")
	#stop movement?
	pass

func update(_delta: float) -> void:
	# Called every frame (from _process)
	pass

func physics_update(_delta: float) -> void:
	# move toward patrol point
	if actor.nav_agent.is_navigation_finished():
		var random_point = NavigationServer3D.region_get_random_point(AIDirector.nav_region.get_rid(), 1, true)
		print("[PatrolState] reached destination, new patrol target: ", random_point)
		actor.navigate_to(random_point)
	# check sensory component
	if actor.sensory_component.has_detection:
		print("[PatrolState] detection — transitioning to Investigate")
		#transition to investigate
		actor.state_machine.transition_to("Investigate")
	
	

extends State
class_name HuntState

enum AttackPhase {NONE, ENTERING, HITTING, EXITING}

@export var blind_chase_duration: float = 5.0 # seconds before giving up and switching to investigate
@export var blind_target_spread: float = 4.0 # radius of random wander points when sight is lost
@export var attack_cooldown: float = 1.5

var lost_sight_timer: float = 0.0
var _had_detection: bool = false # tracks the previous frame's detection state to catch the transition
var _blind_target: Vector3 = Vector3.ZERO
var _has_blind_target: bool = false
var _attack_phase := AttackPhase.NONE
var _attack_cooldown: float = 0.0

func enter() -> void:
	print("[HuntState] entered")
	# reset confidence so robot has to re-confirm before going back to hunt if it loses the player
	actor.sensory_component.visual_confidence = 0.0
	actor.sensory_component.is_threat_confirmed = false
	lost_sight_timer = 0.0
	_attack_phase = AttackPhase.NONE
	_has_blind_target = false
	actor.set_speed(actor.hunt_move_speed)

func exit() -> void:
	print("[HuntState] exited, lost_sight_timer: ", snapped(lost_sight_timer, 0.1))
	actor.set_speed(actor.move_speed)
	_attack_phase = AttackPhase.NONE

func physics_update(_delta: float) -> void:
	if not actor.hostile:
		actor.state_machine.transition_to("Patrol")
		return

	var sensory: SensoryComponent = actor.sensory_component

	# movement and attack
	if _attack_phase != AttackPhase.NONE:
		_update_attack()
	else:
		if sensory.has_detection:
			if actor.target_in_attack_range():
				actor.stop()
			else:
				actor.navigate_to(AIDirector.player.global_position)
		else:
			# go to last known position first, switch to random wander after arriving
			actor.navigate_to(_blind_target if _has_blind_target else sensory.last_detected_position)

		_attack_cooldown = maxf(_attack_cooldown - _delta, 0.0)
		if _attack_cooldown <= 0.0 and actor.target_in_attack_range():
			_start_attack()
		else:
			actor.play_anim(actor.get_move_anim("Sprint"))

	# sight loss timer, transitions to investigate after blind_chase_duration
	if lost_sight_timer >= blind_chase_duration:
		print("[HuntState] hunt timed out, transitioning to Investigate")
		actor.state_machine.transition_to("Investigate")
		return

	if sensory.has_detection:
		if not _had_detection:
			print("[HuntState] sight regained")
		lost_sight_timer = 0.0
		_has_blind_target = false
	else:
		if _had_detection:
			# just lost sight, clear any stale blind target so we head to last known pos first
			print("[HuntState] sight lost, heading to last known position (timeout: ", blind_chase_duration, "s)")
			_has_blind_target = false
		elif _attack_phase == AttackPhase.NONE and actor.nav_agent.is_navigation_finished():
			# arrived at destination, pick a new random wander point nearby
			var offset := Vector3(randf_range(-blind_target_spread, blind_target_spread), 0.0, randf_range(-blind_target_spread, blind_target_spread))
			var map: RID = actor.nav_agent.get_navigation_map()
			_blind_target = NavigationServer3D.map_get_closest_point(map, sensory.last_detected_position + offset)
			_has_blind_target = true
			print("[HuntState] picking wander point")
		lost_sight_timer += _delta

	_had_detection = sensory.has_detection

func _start_attack() -> void:
	print("[HuntState] attack, entering stance")
	_attack_phase = AttackPhase.ENTERING
	actor.stop()
	actor.animation_player.play("AnimationLibrary_Godot/PunchKick_Enter")

func _update_attack() -> void:
	if actor.animation_player.is_playing():
		return
	match _attack_phase:
		AttackPhase.ENTERING:
			print("[HuntState] attack, hitting")
			_attack_phase = AttackPhase.HITTING
			actor.animation_player.play("AnimationLibrary_Godot/Punch_Jab")
			var to_player := AIDirector.player.global_position - actor.global_position
			to_player.y = 0.0
			if to_player.length() <= actor.attack_range:
				AIDirector.player.damage_component.take_hit()
		AttackPhase.HITTING:
			print("[HuntState] attack, exiting stance")
			_attack_phase = AttackPhase.EXITING
			actor.animation_player.play("AnimationLibrary_Godot/PunchKick_Exit")
		AttackPhase.EXITING:
			print("[HuntState] attack, done")
			_attack_phase = AttackPhase.NONE
			_attack_cooldown = attack_cooldown

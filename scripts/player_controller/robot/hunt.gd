extends State
class_name HuntState

enum AttackPhase { NONE, ENTERING, HITTING, EXITING }

var lost_sight_timer: float = 0.0
@export var blind_chase_duration: float = 5.0
@export var blind_target_spread: float = 4.0
var _prev_move_speed: float = 0.0
var _had_detection: bool = false
var _blind_target: Vector3 = Vector3.ZERO
var _has_blind_target: bool = false
var _attack_phase := AttackPhase.NONE
var _attack_cooldown: float = 0.0
@export var attack_cooldown: float = 1.5

func enter() -> void:
	print("[HuntState] entered")
	actor.sensory_component.visual_confidence = 0.0
	actor.sensory_component.is_threat_confirmed = false
	lost_sight_timer = 0.0
	_attack_phase = AttackPhase.NONE
	_prev_move_speed = actor.move_speed
	actor.move_speed = actor.hunt_move_speed

func exit() -> void:
	print("[HuntState] exited — lost_sight_timer: ", snapped(lost_sight_timer, 0.1))
	actor.move_speed = _prev_move_speed
	_attack_phase = AttackPhase.NONE

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	if not actor.hostile:
		actor.state_machine.transition_to("Patrol")
		return

	var sensory: SensoryComponent = actor.sensory_component

	if _attack_phase != AttackPhase.NONE:
		_update_attack()
	else:
		if sensory.has_detection:
			actor.navigate_to(AIDirector.player.global_position)
		else:
			actor.navigate_to(_blind_target if _has_blind_target else sensory.last_detected_position)

		_face_player(_delta)
		_attack_cooldown = maxf(_attack_cooldown - _delta, 0.0)
		if _attack_cooldown <= 0.0 and actor.target_in_attack_range():
			_start_attack()
		else:
			actor.play_anim(actor.get_move_anim("Sprint"))

	# count down hunt timer when LOS is lost; reset when regained
	if lost_sight_timer >= blind_chase_duration:
		print("[HuntState] hunt timed out — transitioning to Investigate")
		actor.state_machine.transition_to("Investigate")
	elif sensory.has_detection:
		if not _had_detection:
			print("[HuntState] sight regained")
		lost_sight_timer = 0.0
		_has_blind_target = false
	else:
		if _had_detection or (actor.nav_agent.is_navigation_finished() and _has_blind_target):
			if _had_detection:
				print("[HuntState] sight lost — timer running (timeout: ", blind_chase_duration, "s)")
			else:
				print("[HuntState] blind target reached — picking new one")
			var offset := Vector3(randf_range(-blind_target_spread, blind_target_spread), 0.0, randf_range(-blind_target_spread, blind_target_spread))
			var raw := sensory.last_detected_position + offset
			var map: RID = actor.nav_agent.get_navigation_map()
			_blind_target = NavigationServer3D.map_get_closest_point(map, raw)
			_has_blind_target = true
		lost_sight_timer += _delta

	_had_detection = sensory.has_detection

func _face_player(delta: float) -> void:
	var to_player := AIDirector.player.global_position - actor.global_position
	to_player.y = 0.0
	if to_player.length() > 0.01:
		actor.basis = actor.basis.slerp(
			Basis.looking_at(to_player, Vector3.UP),
			clamp(actor.turn_speed * delta, 0.0, 1.0))

func _start_attack() -> void:
	print("[HuntState] attack — entering stance")
	_attack_phase = AttackPhase.ENTERING
	actor.navigate_to(actor.global_position) # stop moving
	actor.animation_player.play("AnimationLibrary_Godot/PunchKick_Enter")

func _update_attack() -> void:
	if actor.animation_player.is_playing():
		return
	match _attack_phase:
		AttackPhase.ENTERING:
			print("[HuntState] attack — hitting")
			_attack_phase = AttackPhase.HITTING
			actor.animation_player.play("AnimationLibrary_Godot/Punch_Jab")
			var to_player := AIDirector.player.global_position - actor.global_position
			to_player.y = 0.0
			if to_player.length() <= actor.attack_range:
				AIDirector.player.damage_component.take_hit()
		AttackPhase.HITTING:
			print("[HuntState] attack — exiting stance")
			_attack_phase = AttackPhase.EXITING
			actor.animation_player.play("AnimationLibrary_Godot/PunchKick_Exit")
		AttackPhase.EXITING:
			print("[HuntState] attack — done")
			_attack_phase = AttackPhase.NONE
			_attack_cooldown = attack_cooldown

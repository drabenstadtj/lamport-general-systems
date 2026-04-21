extends CharacterBody3D
class_name Robot

@onready var state_machine: StateMachine = $StateMachine
@onready var sensory_component: SensoryComponent = $SensoryComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio

@export var id: String

@export_group("Footsteps")
@export var footstep_sounds: Array[AudioStream] = []

@export_group("Movement")
@export var move_speed: float = 1.0
@export var hunt_move_speed: float = 6.0
@export var turn_speed: float = 8.0

@export_group("Patrol")
@export var patrol_points: Array[PatrolPoint] = []

@export_group("Combat")
@export var hostile: bool = true
@export var attack_range: float = 0.75

var is_active: bool = false
var nav_target: Vector3
var dormant_time: float = 0.0
var patrol_index: int = 0
var _door_wait_timer: float = 0.0
var _navigating: bool = false
var _current_speed: float
var _path_recompute_timer: float = 0.0
# path is re-pushed to nav agent on a timer rather than every frame to avoid perpetual recompute
const PATH_RECOMPUTE_INTERVAL: float = 0.3
# within this distance, skip the nav path and go straight, avoids nav agent jitter at close range
const DIRECT_CHASE_DISTANCE: float = 1.0
var _stuck_timer: float = 0.0
var _stuck_last_pos: Vector3
var _state_label: Label3D

func _ready() -> void:
	AIDirector.register_robot(self )
	# avoidance disabledrvo runs async and causes velocity to be overwritten unpredictably
	nav_agent.avoidance_enabled = false
	nav_agent.target_desired_distance = attack_range * 0.8
	# run after state machine (child, priority 0) so nav_target is set before we move
	process_priority = 1
	_current_speed = move_speed
	_setup_state_label()

func _setup_state_label() -> void:
	_state_label = Label3D.new()
	_state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_state_label.no_depth_test = true
	_state_label.position = Vector3(0, 2.2, 0)
	_state_label.font_size = 48
	_state_label.modulate = Color.WHITE
	_state_label.outline_modulate = Color.BLACK
	_state_label.outline_size = 8
	_state_label.visible = false
	add_child(_state_label)

func play_footstep() -> void:
	if footstep_sounds.is_empty() or not footstep_audio:
		return
	footstep_audio.stream = footstep_sounds[randi() % footstep_sounds.size()]
	footstep_audio.pitch_scale = randf_range(0.9, 1.1)
	footstep_audio.play()

func play_anim(anim: String) -> void:
	var full := "AnimationLibrary_Godot/" + anim
	if animation_player.current_animation != full:
		animation_player.play(full)

# returns idle when the robot isn't physically moving
func get_move_anim(move_anim: String, idle_anim: String = "Idle") -> String:
	return move_anim if velocity.length() > 0.1 else idle_anim

func get_patrol_points() -> Array[PatrolPoint]:
	return patrol_points

func advance_patrol_index() -> void:
	if not patrol_points.is_empty():
		patrol_index = (patrol_index + 1) % patrol_points.size()

func navigate_to(target: Vector3) -> void:
	_navigating = true
	nav_target = target
	# only push to nav agent when target changes meaningfullyavoids resetting the path every frame
	if target.distance_squared_to(nav_agent.target_position) > 0.25:
		nav_agent.target_position = target
		_path_recompute_timer = PATH_RECOMPUTE_INTERVAL

func stop() -> void:
	_navigating = false
	_path_recompute_timer = 0.0

func set_speed(speed: float) -> void:
	_current_speed = speed

# checks flat distance then confirms with a raycast so attacks don't fire through walls
func target_in_attack_range() -> bool:
	var to_player_flat := AIDirector.player.global_position - global_position
	to_player_flat.y = 0.0
	if to_player_flat.length() > attack_range:
		return false
	var player_center := AIDirector.player.global_position + Vector3(0, 0.9, 0)
	var sightline := sensory_component.sightline
	sightline.target_position = sightline.to_local(sightline.global_position + (player_center - sightline.global_position).normalized() * attack_range)
	sightline.force_raycast_update()
	var collider := sightline.get_collider()
	return collider is Node and collider.is_in_group("player")

func _try_open_nearby_doors() -> void:
	for door in get_tree().get_nodes_in_group("door"):
		if door is Node3D and global_position.distance_to(door.global_position) <= 1.5:
			var wait: float = door.open()
			if wait > 0.0:
				_door_wait_timer = wait

func _physics_process(delta: float) -> void:
	if state_machine.current_state:
		_state_label.text = state_machine.current_state.name

	# pause movement while waiting for a door to finish opening
	if _door_wait_timer > 0.0:
		_door_wait_timer -= delta
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if not _navigating:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# throttle nav agent updates to avoid keeping it in a perpetual recompute state
	_path_recompute_timer -= delta
	if _path_recompute_timer <= 0.0:
		nav_agent.target_position = nav_target
		_path_recompute_timer = PATH_RECOMPUTE_INTERVAL

	var to_target := nav_target - global_position
	to_target.y = 0.0

	var move_dir: Vector3
	if to_target.length() < DIRECT_CHASE_DISTANCE:
		move_dir = to_target
	else:
		move_dir = nav_agent.get_next_path_position() - global_position
		move_dir.y = 0.0

	if move_dir.length() > 0.01:
		basis = basis.slerp(Basis.looking_at(move_dir, Vector3.UP), clamp(turn_speed * delta, 0.0, 1.0))
		velocity = move_dir.normalized() * _current_speed
		_try_open_nearby_doors()
	else:
		velocity = Vector3.ZERO

	move_and_slide()

	# stuck recovery: if navigating but not moving, force a random nearby point
	if _navigating:
		if global_position.distance_squared_to(_stuck_last_pos) > 0.01:
			_stuck_last_pos = global_position
			_stuck_timer = 0.0
		else:
			_stuck_timer += delta
			if _stuck_timer >= 2.0:
				_stuck_timer = 0.0
				var map: RID = nav_agent.get_navigation_map()
				var offset := Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
				var recovery_point := NavigationServer3D.map_get_closest_point(map, global_position + offset)
				nav_agent.target_position = recovery_point
				nav_target = recovery_point
				_path_recompute_timer = PATH_RECOMPUTE_INTERVAL
	else:
		_stuck_timer = 0.0
		_stuck_last_pos = global_position

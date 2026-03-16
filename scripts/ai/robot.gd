extends CharacterBody3D
class_name Robot

# References ------------------------------------------------------------------
@onready var state_machine: StateMachine = $StateMachine
@onready var sensory_component: SensoryComponent = $SensoryComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
# Exports ---------------------------------------------------------------------
@export var id: String

@export_group("Movement")
@export var move_speed: float = 1.0 # meters per sec
@export var hunt_move_speed: float = 6.0 # meters per sec
@export var turn_speed: float = 8.0 # radians per sec (higher = snappier)

@export_group("Patrol")
@export var patrol_points: Array[PatrolPoint] = []

@export_group("Combat")
@export var hostile: bool = true
@export var attack_range: float = 0.75 # meters

# State -----------------------------------------------------------------------
var is_active: bool = false
var nav_target: Vector3
var dormant_time: float = 0.0
var patrol_index: int = 0
var _door_wait_timer: float = 0.0
var _is_moving: bool = false   # drives velocity application
var _nav_is_stop: bool = false # drives animation (true = told to hold position)

# Debug -----------------------------------------------------------------------
var _state_label: Label3D

# Setup -----------------------------------------------------------------------
func _ready() -> void:
	AIDirector.register_robot(self)
	nav_agent.target_desired_distance = attack_range * 0.8
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	_setup_state_label()

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if _is_moving:
		velocity = safe_velocity
	else:
		velocity = Vector3.ZERO

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

# Animation ------------------------------------------------------------------
func play_anim(anim: String) -> void:
	var full := "AnimationLibrary_Godot/" + anim
	if animation_player.current_animation != full:
		print("[Robot] anim: ", animation_player.current_animation, " → ", full)
		animation_player.play(full)

# Returns the appropriate movement anim, factoring in turning and idle.
# Uses _nav_is_stop (navigation intent) rather than _is_moving (physical velocity)
# so animation doesn't flicker at nav agent distance thresholds.
func get_move_anim(move_anim: String, idle_anim: String = "Idle") -> String:
	if _nav_is_stop:
		return idle_anim
	if velocity.length() > 0.1:
		var angle := (-global_basis.z).signed_angle_to(velocity.normalized(), Vector3.UP)
		if abs(angle) > deg_to_rad(60.0):
			return "Turn90_L" if angle > 0.0 else "Turn90_R"
	return move_anim

# Patrol route ----------------------------------------------------------------
func get_patrol_points() -> Array[PatrolPoint]:
	return patrol_points

func advance_patrol_index() -> void:
	if patrol_points.is_empty():
		return
	patrol_index = (patrol_index + 1) % patrol_points.size()

# Navigation ------------------------------------------------------------------
func navigate_to(target: Vector3) -> void:
	nav_target = target
	nav_agent.target_position = target
	# _nav_is_stop = true when told to hold position (target == self), false when moving somewhere
	var flat_diff := target - global_position
	flat_diff.y = 0.0
	_nav_is_stop = flat_diff.length_squared() < 0.01

# Combat ----------------------------------------------------------------------
func target_in_attack_range() -> bool:
	var to_player_flat := AIDirector.player.global_position - global_position
	to_player_flat.y = 0.0
	if to_player_flat.length() > attack_range:
		return false
	var player_center := AIDirector.player.global_position + Vector3(0, 0.9, 0)
	var to_center := player_center - sensory_component.sightline.global_position
	var sightline := sensory_component.sightline
	sightline.target_position = sightline.to_local(sightline.global_position + to_center.normalized() * attack_range)
	sightline.force_raycast_update()
	var collider = sightline.get_collider()
	return collider is Node and collider.is_in_group("player")

# Per-frame -------------------------------------------------------------------
func _try_open_nearby_doors() -> void:
	for door in get_tree().get_nodes_in_group("door"):
		if door is Node3D and global_position.distance_to(door.global_position) <= 1.5:
			var wait: float = door.open()
			if wait > 0.0:
				_door_wait_timer = wait

func _physics_process(delta: float) -> void:
	if state_machine.current_state:
		_state_label.text = state_machine.current_state.name

	if _door_wait_timer > 0.0:
		_door_wait_timer -= delta
		_is_moving = false
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if nav_target and not nav_agent.is_navigation_finished():
		var move_dir := nav_agent.get_next_path_position() - global_position
		move_dir.y = 0.0
		if move_dir.length() > 0.01:
			_is_moving = true
			var desired := move_dir.normalized() * move_speed
			basis = basis.slerp(Basis.looking_at(move_dir, Vector3.UP), clamp(turn_speed * delta, 0.0, 1.0))
			nav_agent.velocity = desired
			_try_open_nearby_doors()
		else:
			_is_moving = false
			nav_agent.velocity = Vector3.ZERO
			velocity = Vector3.ZERO
	else:
		_is_moving = false
		nav_agent.velocity = Vector3.ZERO
		velocity = Vector3.ZERO

	move_and_slide()

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

@export_group("Combat")
@export var attack_range: float = 0.75 # meters

# State -----------------------------------------------------------------------
var is_active: bool = false
var nav_target: Vector3
var dormant_time: float = 0.0

# Debug -----------------------------------------------------------------------
var _state_label: Label3D

# Setup -----------------------------------------------------------------------
func _ready() -> void:
	AIDirector.register_robot(self )
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
	add_child(_state_label)

# Animation ------------------------------------------------------------------
func play_anim(anim: String) -> void:
	var full := "AnimationLibrary_Godot/" + anim
	if animation_player.current_animation != full:
		animation_player.play(full)

# Returns the appropriate movement anim, factoring in turning and idle.
# idle_anim can be overridden (e.g. "Idle_LookAround" for investigate).
func get_move_anim(move_anim: String, idle_anim: String = "Idle") -> String:
	if velocity.length() < 0.1:
		return idle_anim
	var angle := (-global_basis.z).signed_angle_to(velocity.normalized(), Vector3.UP)
	if abs(angle) > deg_to_rad(60.0):
		return "Turn90_L" if angle > 0.0 else "Turn90_R"
	return move_anim

# Navigation ------------------------------------------------------------------
func navigate_to(target: Vector3) -> void:
	nav_target = target
	nav_agent.target_position = target

# Combat ----------------------------------------------------------------------
func target_in_attack_range() -> bool:
	var to_player := AIDirector.player.global_position - global_position
	if to_player.length() > attack_range:
		return false
	sensory_component.sightline.target_position = to_player.normalized() * sensory_component.vision_range
	var collider = sensory_component.sightline.get_collider()
	return collider is Node and collider.is_in_group("player")

# Per-frame -------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if state_machine.current_state:
		_state_label.text = state_machine.current_state.name

	if nav_target:
		var move_dir := nav_agent.get_next_path_position() - global_position
		move_dir.y = 0.0
		if move_dir.length() > 0.01:
			velocity = move_dir.normalized() * move_speed
			basis = basis.slerp(Basis.looking_at(move_dir, Vector3.UP), clamp(turn_speed * delta, 0.0, 1.0))
		else:
			velocity = Vector3.ZERO

	move_and_slide()

extends CharacterBody3D
class_name Robot

@export var id: String
var is_active: bool = false

@onready var state_machine = $StateMachine
@onready var sensory_component = $SensoryComponent
@onready var nav_agent = $NavigationAgent3D

@export var attack_range: float = 0.75 #meters
@export var move_speed: float = 1.0 #meters per sec
@export var hunt_move_speed: float = 2.0 #meters per sec
@export var turn_speed: float = 8.0 #radians per sec (higher = snappier)
var nav_target

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AIDirector.register_robot.call_deferred(self)
	pass # Replace with function body.

func target_in_attack_range():
	var to_player: Vector3 = AIDirector.player.global_position - global_position 
	
	#check if in range
	if to_player.length() > attack_range:
		return false
		
	# point the raycast to the player
	sensory_component.sightline.target_position = to_player.normalized() * sensory_component.vision_range
	
	#make sure not blocked by anything
	var collider = sensory_component.sightline.get_collider()
	if collider is Node:
		if collider.is_in_group("player"):
			return true
	return false 

func navigate_to(target: Vector3):
	nav_target = target
	nav_agent.target_position = target

func _physics_process(delta: float) -> void:
	if nav_target:
		# get position
		var target_pos = nav_agent.get_next_path_position()
		 
		# move toward (flatten Y so robot stays on ground plane)
		var move_dir = target_pos - global_position
		move_dir.y = 0.0
		if move_dir.length() > 0.01:
			velocity = move_dir.normalized() * move_speed
			var target_basis := Basis.looking_at(move_dir, Vector3.UP)
			basis = basis.slerp(target_basis, clamp(turn_speed * delta, 0.0, 1.0))
		else:
			velocity = Vector3.ZERO
		
	move_and_slide()

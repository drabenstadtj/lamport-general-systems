extends Resource
class_name RobotData

@export var id: String
@export var position: Vector3
@export var rotation: Vector3
@export var is_active: bool

func update_from_robot(robot: Robot):
	id = robot.id
	position = robot.global_position
	rotation = robot.global_rotation
	is_active = robot.is_active
	

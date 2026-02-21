extends Node

var robots = {} #id -> robot data
var robot_refs = []
var threat_meter: float = 0.0
var player: CharacterBody3D
var level_name: String
var nav_region: NavigationRegion3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_threat()

func start_robots() -> void:
	for robot in robot_refs:
		robot.state_machine.start()

func register_robot(robot: Robot):
	robot_refs.append(robot)
	var path =  "user://robots/%s/%s.tres" % [level_name, robot.id]
	if FileAccess.file_exists(path):
		var robot_data = ResourceLoader.load(path)
		robots[robot.id] = robot_data
		# set the robots postion to robots[robot.id].position
		robot.global_position = robots[robot.id].position
		robot.global_rotation = robots[robot.id].rotation
		# set the robots state
		robot.is_active = robots[robot.id].is_active
		pass
	else:
		var new_robot_data =  RobotData.new()
		new_robot_data.update_from_robot(robot)
		robots[robot.id] = new_robot_data
		pass

func clear_level():
	# save  all robots states and positions
	# unregister all current robots 
	
	#iterate over live robot references
	for robot in robot_refs:
		#update dict with live robot data
		robots[robot.id].update_from_robot(robot)
		pass
		
	# iterate over the dict, writing each robotdata resource
	for robot in robots.values():
		ResourceSaver.save(robot, "user://robots/%s/%s.tres" % [level_name, robot.id])
	
	robots.clear()
	robot_refs.clear()

func update_threat():
	# ya
	pass


	

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
	print("[AIDirector] start_robots — ", robot_refs.size(), " robot(s)")
	for robot in robot_refs:
		print("[AIDirector]   starting: ", robot.id)
		robot.state_machine.start()

func register_robot(robot: Robot) -> void:
	robot_refs.append(robot)
	print("[AIDirector] registered robot: ", robot.id, " (total: ", robot_refs.size(), ")")
	var path = "user://robots/%s/%s.tres" % [level_name, robot.id]
	if FileAccess.file_exists(path):
		var robot_data = ResourceLoader.load(path)
		robots[robot.id] = robot_data
		robot.global_position = robots[robot.id].position
		robot.global_rotation = robots[robot.id].rotation
		robot.is_active = robots[robot.id].is_active
		print("[AIDirector]   loaded saved data for: ", robot.id)
	else:
		var new_robot_data = RobotData.new()
		new_robot_data.update_from_robot(robot)
		robots[robot.id] = new_robot_data
		print("[AIDirector]   no saved data — created new entry for: ", robot.id)

func clear_level() -> void:
	print("[AIDirector] clear_level — saving ", robot_refs.size(), " robot(s)")
	for robot in robot_refs:
		robots[robot.id].update_from_robot(robot)
	var dir_path := "user://robots/%s" % level_name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	for robot in robots.values():
		ResourceSaver.save(robot, "user://robots/%s/%s.tres" % [level_name, robot.id])
		print("[AIDirector]   saved: ", robot.id)
	robots.clear()
	robot_refs.clear()
	print("[AIDirector] clear_level done — refs cleared")

func emit_sound(sound_position: Vector3, volume: float) -> void:
	for robot in AIDirector.robot_refs:
		robot.sensory_component.hear_sound(sound_position, volume)
		
func update_threat():
	# ya
	pass


	

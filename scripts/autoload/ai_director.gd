extends Node

var robots = {} # id -> robot data
var robot_refs = []
var player: CharacterBody3D
var level_name: String
var level_path: String
var nav_region: NavigationRegion3D

var threat_meter: float = 50.0
var threat_threshold: float = 20.0
var hint_cooldown: float = 0.0
var _threat_print_timer: float = 0.0

func _ready() -> void:
	SecurityCameraManager.alert_raised.connect(_on_camera_alert)

func _on_camera_alert(camera_id: String, target: Node) -> void:
	if not target is Node3D:
		return
	var alert_position: Vector3 = (target as Node3D).global_position
	print("[AIDirector] camera alert from ", camera_id, " — investigating ", alert_position)
	for robot in robot_refs:
		var current_state = robot.state_machine.current_state
		if current_state == null:
			continue
		robot.sensory_component.last_detected_position = alert_position
		match current_state.name:
			"Patrol":
				robot.state_machine.transition_to("Investigate")
			"Investigate":
				robot.navigate_to(alert_position)

func _process(delta: float) -> void:
	update_threat(delta)

	if threat_meter <= threat_threshold and hint_cooldown <= 0.0:
		print("[AIDirector] threat threshold reached — hinting to robot")
		var robot_to_hint: Robot = get_most_dormant()
		if robot_to_hint != null:
			robot_to_hint.state_machine.transition_to("Patrol")
			robot_to_hint.navigate_to(get_player_area())
			hint_cooldown = 10.0

	hint_cooldown = clampf(hint_cooldown - delta, 0.0, 10.0)

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

func clear_level_no_save() -> void:
	robots.clear()
	robot_refs.clear()
	print("[AIDirector] clear_level_no_save — refs cleared without writing saves")

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
	for robot in robot_refs:
		robot.sensory_component.hear_sound(sound_position, volume)

func update_threat(delta: float) -> void:
	_threat_print_timer -= delta
	var should_print := _threat_print_timer <= 0.0
	if should_print:
		_threat_print_timer = 1.0
	for robot in robot_refs:
		var current = robot.state_machine.current_state
		if current == null:
			continue
		match current.name:
			"Patrol":
				threat_meter -= 1.0 * delta
			"Investigate":
				threat_meter += 1.0 * delta
			"Hunt":
				if robot.sensory_component.has_detection:
					threat_meter += 3.0 * delta
				else:
					threat_meter += 1.0 * delta
		if should_print:
			print("[AIDirector] update_threat — ", robot.id, " (", current.name, ")")
	threat_meter = clampf(threat_meter, 0.0, 100.0)
	if should_print:
		print("[AIDirector] update_threat — threat_meter: ", "%.2f" % threat_meter)

func get_most_dormant() -> Robot:
	if robot_refs.is_empty():
		return null
	var most_dormant: Robot = robot_refs[0]
	for robot in robot_refs:
		if robot.dormant_time > most_dormant.dormant_time:
			most_dormant = robot
	print("[AIDirector] get_most_dormant — selected: ", most_dormant.id, " (dormant_time: ", "%.2f" % most_dormant.dormant_time, "s)")
	return most_dormant

func get_player_area() -> Vector3:
	var hint_radius: float = 5.0 # meters
	var hint_position = player.global_position + Vector3(randf() * hint_radius, 0, randf() * hint_radius)
	print("[AIDirector] get_player_area — hinting near: ", hint_position)
	return hint_position

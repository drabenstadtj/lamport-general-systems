extends Area3D

@export var voiceline: AudioStream  
@export var demo_robot: NodePath  # Link to DemoRobot node
@export var one_time_only = true  # Only trigger once
@export var delay_seconds = 0.0  # Add delay before playing

var has_triggered = false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player") and not has_triggered:
		if one_time_only:
			has_triggered = true
		
		# Wait for delay, then play
		await get_tree().create_timer(delay_seconds).timeout
		
		var robot = get_node(demo_robot)
		robot.play_voiceline(voiceline)

extends Node3D
class_name ControlTerminal

@onready var terminal = $SubViewport/Terminal
@onready var interaction_area: Area3D = $InteractionArea
@onready var camera_position_marker: Node3D = $CameraPosition
@onready var camera_lookat_marker: Node3D = $CameraLookAt

var player_nearby: bool = false
var is_being_viewed: bool = false

func _ready():
	if interaction_area:
		interaction_area.body_entered.connect(_on_player_entered)
		interaction_area.body_exited.connect(_on_player_exited)

func _on_player_entered(body):
	if body.is_in_group("player"):
		player_nearby = true

func _on_player_exited(body):
	if body.is_in_group("player"):
		player_nearby = false

func can_interact() -> bool:
	return player_nearby and not is_being_viewed

func interact(player):
	if can_interact():
		start_viewing(player)
	elif is_being_viewed:
		stop_viewing(player)

func start_viewing(player):
	is_being_viewed = true
	player.start_viewing_terminal(self)
	
	if terminal:
		terminal.accept_input = true

func stop_viewing(player):
	is_being_viewed = false
	
	if terminal:
		terminal.accept_input = false

func get_camera_position() -> Vector3:
	if camera_position_marker:
		return camera_position_marker.global_position
	return global_position + Vector3(0, 0.5, 0.25)

func get_look_at_position() -> Vector3:
	if camera_lookat_marker:
		return camera_lookat_marker.global_position
	return global_position + Vector3(0, 0.47, 0)

# ═══════════════════════════════════════════
# Input Handling (for debugging/testing)
# ═══════════════════════════════════════════

func _input(event):
	if event is InputEventKey and event.pressed:
		# Forward to appropriate node terminal based on which one player wants to control
		# This is placeholder - might want different logic
		var target_node_id = -1
		
		match event.keycode:
			KEY_R:
				for i in range(10):
					if Input.is_key_pressed(KEY_0 + i) or Input.is_key_pressed(KEY_KP_0 + i):
						target_node_id = i
						if target_node_id >= 0:
							var node_terminal = GameManager.get_node_terminal(target_node_id)
							if node_terminal:
								node_terminal.reboot()
			KEY_C:
				for i in range(10):
					if Input.is_key_pressed(KEY_0 + i) or Input.is_key_pressed(KEY_KP_0 + i):
						target_node_id = i
						if target_node_id >= 0:
							var node_terminal = GameManager.get_node_terminal(target_node_id)
							if node_terminal:
								node_terminal.crash()
			KEY_X:
				for i in range(10):
					if Input.is_key_pressed(KEY_0 + i) or Input.is_key_pressed(KEY_KP_0 + i):
						target_node_id = i
						if target_node_id >= 0:
							var node_terminal = GameManager.get_node_terminal(target_node_id)
							if node_terminal:
								node_terminal.corrupt()
			KEY_L:
				for i in range(10):
					if Input.is_key_pressed(KEY_0 + i) or Input.is_key_pressed(KEY_KP_0 + i):
						target_node_id = i
						if target_node_id >= 0:
							var node_terminal = GameManager.get_node_terminal(target_node_id)
							if node_terminal:
								node_terminal.clear_logs()

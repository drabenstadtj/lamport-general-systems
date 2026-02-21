extends Node3D

class_name SensoryComponent

var player: CharacterBody3D
@onready var sightline: RayCast3D = $RayCast3D

@export var hearing_range: float = 10.0 # meters
@export var vision_angle: float = 75.0
@export var vision_range: float = 10.0 # meters
@export var visual_confidence_threshold: float = 100.0

var visual_confidence: float = 0.0
var last_detected_position: Vector3
var is_threat_confirmed: bool = false
var has_detection: bool = false

func _ready() -> void:
	player = AIDirector.player
	print("[SensoryComponent] ready — player: ", player)

func _physics_process(_delta: float) -> void:
	has_detection = false

	if vision_check():
		visual_confidence += 1.0
	else:
		visual_confidence = clamp(visual_confidence - 1.0, 0.0, visual_confidence_threshold)

	if visual_confidence > visual_confidence_threshold:
		if not is_threat_confirmed:
			print("[SensoryComponent] threat confirmed — confidence: ", visual_confidence)
		is_threat_confirmed = true


func vision_check() -> bool:
	var player_center := player.global_position + Vector3(0, 0.9, 0)  # aim at body center, not feet
	var to_player: Vector3 = player_center - global_position

	# if in range
	if to_player.length() > vision_range:
		return false

	# if in view cone
	if to_player.angle_to(-global_basis.z) > deg_to_rad(vision_angle) / 2:
		return false

	# point the raycast to the player
	sightline.target_position = sightline.to_local(sightline.global_position + to_player.normalized() * vision_range)
	sightline.force_raycast_update()

	var collider = sightline.get_collider()
	if collider is Node:
		if collider.is_in_group("player"):
			last_detected_position = player.global_position
			has_detection = true
			return true
	return false


func get_detected_threat():
	return last_detected_position

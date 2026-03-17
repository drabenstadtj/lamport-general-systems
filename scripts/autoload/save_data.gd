extends Resource
class_name SaveData

@export var current_level: String = ""
@export var player_hits_remaining: int = 3
@export var player_position: Vector3 = Vector3.ZERO
@export var player_rotation: Vector3 = Vector3.ZERO
@export var completed_levels: Array[String] = []
@export var flags: Dictionary = {}  # unlocked doors, items collected, etc
@export var pda_messages: Array[Dictionary] = []  # {sender, subject, body, timestamp, read}

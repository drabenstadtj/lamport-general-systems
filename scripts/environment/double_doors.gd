extends Node3D
class_name DoubleDoors

@export var locked: bool = false

@onready var _left: Node3D = $DoorPivot2
@onready var _right: Node3D = $DoorPivot

func _ready() -> void:
	add_to_group("door")
	_left.locked = locked
	_right.locked = locked

func open() -> float:
	if _left.is_open:
		return 0.0
	_open()
	return _left.open_time

func unlock() -> void:
	_left.unlock()
	_right.unlock()

func _open() -> void:
	_left._open()
	_right._open()

func close() -> void:
	_left.close()
	_right.close()

func lock() -> void:
	_left.locked = true
	_right.locked = true

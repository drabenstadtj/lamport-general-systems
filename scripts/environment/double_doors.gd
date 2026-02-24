extends Node3D

@export var locked: bool = false

@onready var _left: Node3D = $DoorPivot2
@onready var _right: Node3D = $DoorPivot

func _ready() -> void:
	_left.locked = locked
	_right.locked = locked

func unlock() -> void:
	_left.unlock()
	_right.unlock()

func _open() -> void:
	_left._open()
	_right._open()

func lock() -> void:
	_left.locked = true
	_right.locked = true

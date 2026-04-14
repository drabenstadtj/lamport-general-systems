extends Node3D

@export var amplitude: float = 10.0
@export var frequency: float = 0.1
@export var delay: float = 2.0

var _origin: Vector3
var _time: float = 0.0

var _started: bool = false

func _ready() -> void:
	_origin = position
	await get_tree().create_timer(delay).timeout
	_started = true


func _process(delta: float) -> void:
	if _started:
		_time += delta
		position.z = _origin.z + sin(_time * frequency * TAU) * amplitude

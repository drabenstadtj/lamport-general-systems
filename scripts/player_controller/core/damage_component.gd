extends Node
class_name DamageComponent

signal hit_taken(hits_remaining: int)
signal player_died

@export var max_hits: int = 3

var hits_taken: int = 0
var hits_remaining: int:
	get: return max_hits - hits_taken
var is_dead: bool = false

# invincibility frames after each hit
@export var invincibility_duration: float = 1.0
var _invincible_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if _invincible_timer > 0.0:
		_invincible_timer -= delta

func take_hit() -> void:
	if is_dead or _invincible_timer > 0.0:
		return

	hits_taken += 1
	print('hits taken: ' + str(hits_taken))
	
	_invincible_timer = invincibility_duration

	var remaining := max_hits - hits_taken
	print("[DamageComponent] hit taken — %d/%d" % [hits_taken, max_hits])
	hit_taken.emit(remaining)

	if hits_taken >= max_hits:
		_die()

func _die() -> void:
	is_dead = true
	print("[DamageComponent] player died")
	player_died.emit()

func reset() -> void:
	hits_taken = 0
	is_dead = false
	_invincible_timer = 0.0

func restore(remaining: int) -> void:
	hits_taken = max_hits - clampi(remaining, 0, max_hits)
	is_dead = false
	_invincible_timer = 0.0

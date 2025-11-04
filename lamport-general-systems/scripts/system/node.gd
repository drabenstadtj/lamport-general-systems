extends RefCounted
class_name BFTNode

var id: int
var state: Enums.NodeState
var game_object = null  # Reference to NodeTerminal in 3D world

func _init(node_id: int, initial_state = Enums.NodeState.HEALTHY):
	id = node_id
	state = initial_state

func is_healthy() -> bool:
	return state == Enums.NodeState.HEALTHY

func is_crashed() -> bool:
	return state == Enums.NodeState.CRASHED

func is_byzantine() -> bool:
	return state == Enums.NodeState.BYZANTINE

func set_state(new_state: Enums.NodeState):
	print("BFTNode %d: set_state called, changing from %s to %s" % [id, state, new_state])
	state = new_state
	print("BFTNode %d: game_object is: %s" % [id, game_object])
	if game_object:
		print("BFTNode %d: calling game_object.update_visuals()" % id)
		game_object.update_visuals()
	else:
		print("BFTNode %d: game_object is null, can't update visuals!" % id)

func link_game_object(obj):
	game_object = obj

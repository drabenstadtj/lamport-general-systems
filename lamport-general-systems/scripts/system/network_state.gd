extends RefCounted
class_name NetworkState

var nodes: Array[BFTNode] = []
var current_level: Enums.SecurityLevel
var f: int  # Fault tolerance parameter
var security_lockdown: bool = false
var defense_timer: int = 0

func _init(f_value: int):
	f = f_value
	current_level = Enums.SecurityLevel.NORMAL
	initialize_nodes()

func initialize_nodes():
	# Create 2f+1 nodes (for f=1, that's 3 nodes)
	for i in range(3 * f + 1):
		var node = BFTNode.new(i)
		# Start some crashed for puzzle (nodes beyond f start crashed)
		if i > f:
			node.state = Enums.NodeState.CRASHED
		nodes.append(node)
	print("Created %d nodes (f=%d)" % [nodes.size(), f])

func get_node(node_id: int) -> BFTNode:
	if node_id >= 0 and node_id < nodes.size():
		return nodes[node_id]
	return null

func get_commander() -> BFTNode:
	return nodes[0]

func count_healthy_nodes() -> int:
	return nodes.filter(func(n): return n.is_healthy()).size()

func count_crashed_nodes() -> int:
	return nodes.filter(func(n): return n.is_crashed()).size()

func count_byzantine_nodes() -> int:
	return nodes.filter(func(n): return n.is_byzantine()).size()

func can_reach_level_1() -> bool:
	return count_healthy_nodes() >= (3 * f + 1) and not security_lockdown

func should_drop_to_level_2() -> bool:
	return count_healthy_nodes() < (3 * f + 1)

func check_level_transitions():
	match current_level:
		Enums.SecurityLevel.MAINTENANCE:
			if should_drop_to_level_2():
				transition_to_level(Enums.SecurityLevel.NORMAL)
		
		Enums.SecurityLevel.NORMAL:
			if can_reach_level_1():
				transition_to_level(Enums.SecurityLevel.MAINTENANCE)

func transition_to_level(new_level: Enums.SecurityLevel):
	var old_level = current_level
	current_level = new_level
	print("Security Level Changed: %s → %s" % [old_level, new_level])

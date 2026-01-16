extends RefCounted
class_name NetworkState

var nodes: Array[NetworkNode] = []
var current_level: Enums.SecurityLevel
var f: int  # Fault tolerance parameter
var security_lockdown: bool = false
var defense_timer: int = 0

func _init(f_value: int, num_total_nodes: int = -1):
	f = f_value
	current_level = Enums.SecurityLevel.NORMAL
	
	# Calculate node count
	var node_count = num_total_nodes if num_total_nodes > 0 else (3 * f + 1)
	initialize_nodes(node_count)

func initialize_nodes(count: int):
	var min_required = 3 * f + 1
	
	for i in range(count):
		var node = NetworkNode.new(i)
		
		if i >= min_required:
			node.state = Enums.NodeState.CRASHED
		else:
			node.state = Enums.NodeState.HEALTHY
		
		nodes.append(node)
	
	print("Created %d nodes (f=%d, healthy=%d, crashed=%d)" % [nodes.size(), f, min_required, max(0, nodes.size() - min_required)])
	
func get_node(node_id: int) -> NetworkNode:
	if node_id >= 0 and node_id < nodes.size():
		return nodes[node_id]
	return null

func get_commander() -> NetworkNode:
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
	print("Security Level Changed: %s -> %s" % [old_level, new_level])

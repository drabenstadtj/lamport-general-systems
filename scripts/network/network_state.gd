extends RefCounted
class_name NetworkState

signal anomaly_detected(anomaly: Dictionary)
signal alert_level_changed(old_level: int, new_level: int)

var nodes: Array[NetworkNode] = []
var current_level: Enums.SecurityLevel
var f: int  # Fault tolerance parameter
var security_lockdown: bool = false
var defense_timer: int = 0

# Link blocking: { "from_to" -> rounds_remaining }
var link_blocks: Dictionary = {}

# Detection system
var anomalies: Array[Dictionary] = []  # List of detected anomalies
var node_suspicion: Dictionary = {}  # {node_id: suspicion_score}
var alert_level: int = 0  # 0=normal, 1=elevated, 2=high, 3=critical
const SUSPICION_THRESHOLD_ELEVATED = 3
const SUSPICION_THRESHOLD_HIGH = 6
const SUSPICION_THRESHOLD_CRITICAL = 10

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

# Link Blocking

func block_link(from_id: int, to_id: int, rounds: int = 1):
	var key = "%d_%d" % [from_id, to_id]
	link_blocks[key] = rounds
	print("[NetworkState] Blocked link %d -> %d for %d round(s)" % [from_id, to_id, rounds])

func unblock_link(from_id: int, to_id: int):
	var key = "%d_%d" % [from_id, to_id]
	if link_blocks.has(key):
		link_blocks.erase(key)
		print("[NetworkState] Unblocked link %d -> %d" % [from_id, to_id])

func is_link_blocked(from_id: int, to_id: int) -> bool:
	var key = "%d_%d" % [from_id, to_id]
	return link_blocks.get(key, 0) > 0

func get_blocked_links() -> Array:
	var result = []
	for key in link_blocks.keys():
		var parts = key.split("_")
		result.append({
			"from": int(parts[0]),
			"to": int(parts[1]),
			"rounds": link_blocks[key]
		})
	return result

func tick_link_blocks():
	"""Call after each consensus round to decrement block durations"""
	var to_remove = []
	for key in link_blocks.keys():
		link_blocks[key] -= 1
		if link_blocks[key] <= 0:
			to_remove.append(key)
	for key in to_remove:
		link_blocks.erase(key)
		var parts = key.split("_")
		print("[NetworkState] Link block expired: %s -> %s" % [parts[0], parts[1]])

# Detection System

func report_anomaly(anomaly_type: String, node_id: int, details: String, severity: int = 1):
	var anomaly = {
		"type": anomaly_type,
		"node_id": node_id,
		"details": details,
		"severity": severity,
		"timestamp": Time.get_ticks_msec()
	}
	anomalies.append(anomaly)

	# Increase suspicion for the involved node
	if not node_suspicion.has(node_id):
		node_suspicion[node_id] = 0
	node_suspicion[node_id] += severity

	# Check for alert level changes
	_update_alert_level()

	# Log to node if it exists
	var node = get_node(node_id)
	if node:
		node.append_to_log("consensus", "[ANOMALY] %s: %s" % [anomaly_type, details])

	anomaly_detected.emit(anomaly)
	print("[DETECTION] %s on Node %d: %s (severity=%d)" % [anomaly_type, node_id, details, severity])

func report_blocked_message(from_id: int, to_id: int, msg_type: String):
	report_anomaly("BLOCKED_MSG", from_id, "%s to Node %d was blocked" % [msg_type, to_id], 1)

func report_inconsistent_vote(node_id: int, expected: String, actual: String):
	report_anomaly("INCONSISTENT_VOTE", node_id, "Expected %s but voted %s" % [expected, actual], 2)

func report_spoofed_message(node_id: int, target_id: int, spoofed_value: String):
	report_anomaly("SPOOFED_MSG", node_id, "Sent fake %s to Node %d" % [spoofed_value, target_id], 3)

func report_byzantine_behavior(node_id: int, details: String):
	report_anomaly("BYZANTINE", node_id, details, 3)

func _update_alert_level():
	var max_suspicion = 0
	for nid in node_suspicion.keys():
		max_suspicion = max(max_suspicion, node_suspicion[nid])

	var old_level = alert_level
	if max_suspicion >= SUSPICION_THRESHOLD_CRITICAL:
		alert_level = 3
	elif max_suspicion >= SUSPICION_THRESHOLD_HIGH:
		alert_level = 2
	elif max_suspicion >= SUSPICION_THRESHOLD_ELEVATED:
		alert_level = 1
	else:
		alert_level = 0

	if old_level != alert_level:
		alert_level_changed.emit(old_level, alert_level)
		print("[DETECTION] Alert level changed: %d -> %d" % [old_level, alert_level])

func get_alert_level_name() -> String:
	match alert_level:
		0: return "NORMAL"
		1: return "ELEVATED"
		2: return "HIGH"
		3: return "CRITICAL"
	return "UNKNOWN"

func get_node_suspicion(node_id: int) -> int:
	return node_suspicion.get(node_id, 0)

func get_recent_anomalies(count: int = 10) -> Array[Dictionary]:
	var start_idx = max(0, anomalies.size() - count)
	var result: Array[Dictionary] = []
	for i in range(start_idx, anomalies.size()):
		result.append(anomalies[i])
	return result

func clear_anomalies():
	anomalies.clear()
	node_suspicion.clear()
	var old_level = alert_level
	alert_level = 0
	if old_level != 0:
		alert_level_changed.emit(old_level, 0)

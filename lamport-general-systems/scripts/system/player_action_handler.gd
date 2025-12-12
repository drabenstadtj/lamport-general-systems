extends RefCounted
class_name PlayerActionHandler

var network_manager: NetworkManager
var actions_this_round: Dictionary = {}

func _init(net_manager: NetworkManager):
	network_manager = net_manager
	reset_round_tracking()

func reboot_node(node_id: int) -> Dictionary:
	var node = network_manager.get_node(node_id)
	
	if not node:
		return {
			"success": false,
			"message": "Invalid node ID",
			"attack_detected": false
		}
	
	if not node.is_crashed():
		return {
			"success": false,
			"message": "Node %d is not crashed" % node_id,
			"attack_detected": false
		}
	
	# Reboot the node
	node.set_state(Enums.NodeState.HEALTHY)
	
	return {
		"success": true,
		"message": "Node %d rebooted successfully" % node_id,
		"attack_detected": false,
		"nodes_affected": [node_id]
	}

func crash_node(node_id: int) -> Dictionary:
	var node = network_manager.get_node(node_id)
	
	if not node:
		return {
			"success": false,
			"message": "Invalid node ID",
			"attack_detected": false
		}
	
	if node.is_crashed():
		return {
			"success": false,
			"message": "Node %d is already crashed" % node_id,
			"attack_detected": false
		}
	
	# Crash the node
	node.set_state(Enums.NodeState.CRASHED)
	
	# Track for attack detection
	if not actions_this_round.has("crashes"):
		actions_this_round["crashes"] = []
	actions_this_round["crashes"].append(node_id)
	
	var attack = detect_attack()
	
	return {
		"success": true,
		"message": "Node %d crashed" % node_id,
		"attack_detected": attack,
		"nodes_affected": [node_id]
	}

func corrupt_node(node_id: int) -> Dictionary:
	var node = network_manager.get_node(node_id)
	
	if not node:
		return {
			"success": false,
			"message": "Invalid node ID",
			"attack_detected": false
		}
	
	if not node.is_healthy():
		return {
			"success": false,
			"message": "Node %d must be healthy to corrupt" % node_id,
			"attack_detected": false
		}
	
	# Corrupt the node
	node.set_state(Enums.NodeState.BYZANTINE)
	
	# Track for attack detection
	if not actions_this_round.has("corrupts"):
		actions_this_round["corrupts"] = []
	actions_this_round["corrupts"].append(node_id)
	
	var attack = detect_attack()
	
	return {
		"success": true,
		"message": "Node %d corrupted" % node_id,
		"attack_detected": attack,
		"nodes_affected": [node_id]
	}

func command_door(value: Enums.VoteValue) -> Dictionary:
	if network_manager.current_level != Enums.SecurityLevel.MAINTENANCE:
		return {
			"success": false,
			"message": "Must be at Maintenance level to command door",
			"attack_detected": false
		}

	network_manager.current_door_state = value
	var value_str = "OPEN" if value == Enums.VoteValue.OPEN else "LOCKED"
	
	var result = {
		"success": true,
		"message": "Door commanded to %s" % value_str,
		"attack_detected": false,
		"action_type": "door",  # Mark as door action
		"door_opened": value == Enums.VoteValue.OPEN
	}

	if value == Enums.VoteValue.OPEN:
		result["win_type"] = "restoration"

	return result

func exploit_door() -> Dictionary:
	if not network_manager.failsafe_active:
		return {
			"success": false,
			"message": "Failsafe not active - cannot exploit door",
			"attack_detected": false
		}

	network_manager.current_door_state = Enums.VoteValue.OPEN
	
	return {
		"success": true,
		"message": "Door physically forced open (failsafe exploit)",
		"attack_detected": false,
		"action_type": "door",  # Mark as door action
		"door_opened": true,
		"win_type": "sabotage"
	}

func detect_attack() -> bool:
	var crash_count = actions_this_round.get("crashes", []).size()
	var corrupt_count = actions_this_round.get("corrupts", []).size()
	var total_byzantine = _count_byzantine_nodes()

	# Check attack patterns (for n=3f+1)
	if crash_count >= 2:
		print("ATTACK DETECTED: 2+ crashes in one round")
		return true

	if corrupt_count >= 2:
		print("ATTACK DETECTED: 2+ corruptions in one round")
		return true

	# With f=1, can tolerate 1 Byzantine, so 2+ is attack
	if total_byzantine > network_manager.f:
		print("ATTACK DETECTED: %d Byzantine nodes (max tolerable: %d)" % [total_byzantine, network_manager.f])
		return true

	# Check if commander was targeted
	var commander = network_manager.get_commander()
	if not commander.is_healthy():
		var commander_crashed = actions_this_round.get("crashes", []).has(0)
		var commander_corrupted = actions_this_round.get("corrupts", []).has(0)
		if commander_crashed or commander_corrupted:
			print("ATTACK DETECTED: Commander node targeted")
			return true

	return false

func _count_byzantine_nodes() -> int:
	var count = 0
	for node in network_manager.nodes:
		if node.is_byzantine():
			count += 1
	return count

func reset_round_tracking():
	actions_this_round = {
		"crashes": [],
		"corrupts": []
	}

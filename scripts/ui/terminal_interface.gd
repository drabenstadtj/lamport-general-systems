extends Control
class_name TerminalUI

# VARIABLES

var current_path: String = "/home/user"
var accept_input: bool = true
var command_history: Array[String] = []
var history_index: int = -1

var network_manager: NetworkManager = null
var controlled_node_id: int = -1
var connected_node: NetworkNode = null  # The node we're "SSH'd" into

var local_filesystem: Dictionary = {
	"type": "dir",
	"children": {
		"home": {
			"type": "dir",
			"children": {
				"user": {
					"type": "dir",
					"children": {}
				}
			}
		}
	}
}

@onready var output_scroll: ScrollContainer = $MarginContainer/ScrollContainer
@onready var output_label: RichTextLabel = $MarginContainer/ScrollContainer/VBoxContainer/OutputLabel
@onready var input_field: LineEdit = $MarginContainer/ScrollContainer/VBoxContainer/InputContainer/InputField
@onready var prompt_label: Label = $MarginContainer/ScrollContainer/VBoxContainer/InputContainer/PromptLabel

# INITIALIZATION

func _ready():

	input_field.grab_focus()
	print_to_terminal("Terminal ready. Type 'help' for commands.")
	input_field.text_submitted.connect(_on_command_entered)
	input_field.gui_input.connect(_on_input_field_gui_input)

	await get_tree().process_frame
	network_manager = get_tree().get_first_node_in_group("network_manager")
	update_prompt()

func get_filesystem() -> Dictionary:
	return connected_node.filesystem if connected_node else local_filesystem

func is_connected_to_node() -> bool:
	return connected_node != null

func require_connection() -> bool:
	# Returns true if connected, prints error and returns false if not
	if not is_connected_to_node():
		print_to_terminal("ERROR: Not connected to any node")
		print_to_terminal("Use 'connect <node_id>' to connect first")
		return false
	return true

func setup_network_context(node_id: int):
	controlled_node_id = node_id
	update_prompt()
	print_to_terminal("=== Connected to Node %d ===" % node_id)

# PATH UTILITIES

func resolve_path(path: String) -> Dictionary:
	"""Returns {"node": Dictionary or null, "parent": Dictionary or null, "name": String}"""
	var clean_path = path

	# Handle relative paths
	if not path.begins_with("/"):
		clean_path = current_path.path_join(path)

	# Normalize path (handle . and ..)
	var parts = clean_path.split("/", false)
	var normalized: Array[String] = []

	for part in parts:
		if part == "..":
			if normalized.size() > 0:
				normalized.pop_back()
		elif part != ".":
			normalized.append(part)

	# Traverse to find node
	var current = get_filesystem()
	var parent = null
	var node_name = ""

	for i in range(normalized.size()):
		var part = normalized[i]
		node_name = part

		if current["type"] != "dir":
			return {"node": null, "parent": null, "name": ""}

		if not current["children"].has(part):
			return {"node": null, "parent": current, "name": part}

		parent = current
		current = current["children"][part]

	return {"node": current, "parent": parent, "name": node_name}

func get_node_at_path(path: String):
	"""Returns the filesystem node at path, or null if not found."""
	return resolve_path(path)["node"]

func get_current_dir() -> Dictionary:
	var result = get_node_at_path(current_path)
	if result and result["type"] == "dir":
		return result
	return get_filesystem()

func normalize_path(path: String) -> String:
	var clean_path = path if path.begins_with("/") else current_path.path_join(path)
	var parts = clean_path.split("/", false)
	var normalized: Array[String] = []

	for part in parts:
		if part == "..":
			if normalized.size() > 0:
				normalized.pop_back()
		elif part != ".":
			normalized.append(part)

	return "/" + "/".join(normalized)

# INPUT HANDLING

func _input(event):
	if not accept_input:
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER:
			_on_command_entered(input_field.text)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_BACKSPACE:
			if input_field.text.length() > 0:
				input_field.text = input_field.text.substr(0, input_field.text.length() - 1)
				input_field.caret_column = input_field.text.length()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:
			handle_tab_complete()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_UP:
			navigate_history(1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			navigate_history(-1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_PAGEUP:
			var sb := output_scroll.get_v_scroll_bar()
			sb.value = maxf(sb.min_value, sb.value - 200.0)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_PAGEDOWN:
			var sb := output_scroll.get_v_scroll_bar()
			sb.value = minf(sb.max_value, sb.value + 200.0)
			get_viewport().set_input_as_handled()
		elif event.unicode != 0 and event.unicode < 128:
			var character = char(event.unicode)
			input_field.text += character
			input_field.caret_column = input_field.text.length()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_output(-1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_output(1)
			get_viewport().set_input_as_handled()
			
func _on_input_field_gui_input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_TAB:
				handle_tab_complete()
				get_viewport().set_input_as_handled()
			KEY_PAGEUP:
				_scroll_output(-1)
				get_viewport().set_input_as_handled()
			KEY_PAGEDOWN:
				_scroll_output(1)
				get_viewport().set_input_as_handled()

func _on_command_entered(text: String):
	if text.strip_edges() == "":
		return

	command_history.append(text)
	history_index = -1

	print_to_terminal("$ " + text)
	process_command(text)

	input_field.release_focus()
	input_field.text = ""
	await get_tree().process_frame
	input_field.grab_focus()

func navigate_history(direction: int):
	if command_history.is_empty():
		return

	history_index += direction
	history_index = clamp(history_index, -1, command_history.size() - 1)

	if history_index == -1:
		input_field.text = ""
	else:
		var actual_index = command_history.size() - 1 - history_index
		input_field.text = command_history[actual_index]

	input_field.caret_column = input_field.text.length()

# COMMAND PROCESSING

func process_command(command: String):
	var parts = command.split(" ", false)

	if parts.size() == 0:
		return

	var cmd = parts[0].to_lower()
	var args = parts.slice(1)

	match cmd:
		"ls":
			cmd_ls(args)
		"cd":
			cmd_cd(args)
		"pwd":
			cmd_pwd()
		"cat":
			cmd_cat(args)
		"tail":
			cmd_tail(args)
		"clear":
			cmd_clear()
		"help":
			cmd_help()
		"reboot":
			cmd_reboot()
		"crash":
			cmd_crash()
		"corrupt":
			cmd_corrupt()
		"status":
			cmd_status()
		"network":
			cmd_network()
		"consensus":
			cmd_consensus(args)
		"connect":
			cmd_connect(args)
		"disconnect":
			cmd_disconnect()
		"block":
			cmd_block(args)
		"unblock":
			cmd_unblock(args)
		"links":
			cmd_links()
		"spoof":
			cmd_spoof(args)
		"unspoof":
			cmd_unspoof(args)
		"spoofs":
			cmd_spoofs()
		"alerts":
			cmd_alerts()
		"suspicion":
			cmd_suspicion()
		"cameras":
			cmd_cameras()
		_:
			print_to_terminal("Command not found: " + cmd)
			print_to_terminal("Type 'help' for available commands")

# FILE SYSTEM COMMANDS

func cmd_help():
	print_to_terminal("Available commands:")
	print_to_terminal("")
	print_to_terminal("[color=cyan]File System:[/color]")
	print_to_terminal("  ls           - list files and directories")
	print_to_terminal("  cd <dir>     - change directory")
	print_to_terminal("  pwd          - print working directory")
	print_to_terminal("  cat <file>   - display file contents")
	print_to_terminal("  tail <file>  - display last 10 lines of file")
	print_to_terminal("  clear        - clear terminal screen")
	print_to_terminal("")
	print_to_terminal("[color=cyan]Node Control:[/color]")
	print_to_terminal("  reboot       - reboot this node")
	print_to_terminal("  crash        - crash this node")
	print_to_terminal("  corrupt      - corrupt this node")
	print_to_terminal("  status       - show this node's status")
	print_to_terminal("")
	print_to_terminal("[color=cyan]Network:[/color]")
	print_to_terminal("  network      - list all nodes and states")
	print_to_terminal("  connect <id> - connect to a node (SSH)")
	print_to_terminal("  disconnect   - disconnect from current node")
	print_to_terminal("  consensus <OPEN|LOCKED> - trigger consensus")
	print_to_terminal("")
	print_to_terminal("[color=cyan]Link Control:[/color]")
	print_to_terminal("  block <node> [rounds] - block messages to node")
	print_to_terminal("  unblock <node>        - unblock messages to node")
	print_to_terminal("  links                 - show all blocked links")
	print_to_terminal("")
	print_to_terminal("[color=cyan]Message Interception:[/color]")
	print_to_terminal("  spoof <node> <value>  - send fake value to node")
	print_to_terminal("  unspoof [node]        - clear spoof (all if no node)")
	print_to_terminal("  spoofs                - show active spoofs")
	print_to_terminal("")
	print_to_terminal("[color=cyan]Detection System:[/color]")
	print_to_terminal("  alerts                - show network alert status")
	print_to_terminal("  suspicion             - show node suspicion levels")
	print_to_terminal("")
	print_to_terminal("[color=cyan]Security:[/color]")
	print_to_terminal("  cameras               - open security camera view")

func cmd_ls(args: Array = []):
	var target_path = current_path if args.is_empty() else args[0]
	var node = get_node_at_path(target_path)

	if node == null:
		print_to_terminal("ls: cannot access '%s': No such file or directory" % target_path)
		return

	if node["type"] != "dir":
		print_to_terminal(target_path.get_file())
		return

	var children = node["children"]
	if children.is_empty():
		return

	# Sort: directories first, then files
	var dirs: Array[String] = []
	var files: Array[String] = []

	for child_name in children.keys():
		if children[child_name]["type"] == "dir":
			dirs.append(child_name)
		else:
			files.append(child_name)

	dirs.sort()
	files.sort()

	for dir_name in dirs:
		print_to_terminal("[color=blue]%s/[/color]" % dir_name)
	for file_name in files:
		print_to_terminal(file_name)

func cmd_cd(args: Array):
	if args.is_empty():
		current_path = "/home/user"
		return

	var target = args[0].trim_suffix("/")
	var new_path = normalize_path(target)
	var node = get_node_at_path(new_path)

	if node == null:
		print_to_terminal("cd: %s: No such file or directory" % target)
		return

	if node["type"] != "dir":
		print_to_terminal("cd: %s: Not a directory" % target)
		return

	current_path = new_path
	update_prompt()

func cmd_pwd():
	print_to_terminal(current_path if current_path != "" else "/")

func cmd_cat(args: Array):
	if args.is_empty():
		print_to_terminal("cat: missing file argument")
		return

	var node = get_node_at_path(args[0])

	if node == null:
		print_to_terminal("cat: %s: No such file or directory" % args[0])
		return

	if node["type"] == "dir":
		print_to_terminal("cat: %s: Is a directory" % args[0])
		return

	print_to_terminal(node["content"])

func cmd_tail(args: Array):
	if args.is_empty():
		print_to_terminal("tail: missing file argument")
		return

	var num_lines = 10
	var filename = args[0]

	if args[0] == "-n" and args.size() >= 3:
		num_lines = int(args[1])
		filename = args[2]

	var node = get_node_at_path(filename)

	if node == null:
		print_to_terminal("tail: %s: No such file or directory" % filename)
		return

	if node["type"] == "dir":
		print_to_terminal("tail: %s: Is a directory" % filename)
		return

	var lines = node["content"].split("\n")
	var start_index = max(0, lines.size() - num_lines)
	var tail_lines = lines.slice(start_index)

	print_to_terminal("\n".join(tail_lines))

func cmd_clear():
	output_label.text = ""
	await get_tree().process_frame
	output_scroll.get_v_scroll_bar().value = 0


# NODE CONTROL COMMANDS

func cmd_reboot():
	if not network_manager or controlled_node_id < 0:
		print_to_terminal("ERROR: Terminal not connected to a node")
		return

	if network_manager.reboot_node(controlled_node_id):
		print_to_terminal("Rebooting node %d..." % controlled_node_id)
	else:
		print_to_terminal("ERROR: Cannot reboot node %d" % controlled_node_id)

func cmd_crash():
	if not network_manager or controlled_node_id < 0:
		print_to_terminal("ERROR: Terminal not connected to a node")
		return

	if network_manager.crash_node(controlled_node_id):
		print_to_terminal("Crashing node %d..." % controlled_node_id)
	else:
		print_to_terminal("ERROR: Cannot crash node %d" % controlled_node_id)

func cmd_corrupt():
	if not network_manager or controlled_node_id < 0:
		print_to_terminal("ERROR: Terminal not connected to a node")
		return

	if network_manager.corrupt_node(controlled_node_id):
		print_to_terminal("Corrupting node %d..." % controlled_node_id)
	else:
		print_to_terminal("ERROR: Cannot corrupt node %d" % controlled_node_id)

func cmd_status():
	if not network_manager or controlled_node_id < 0:
		print_to_terminal("ERROR: Terminal not connected to a node")
		return

	var node = network_manager.get_network_node(controlled_node_id)
	if not node:
		print_to_terminal("ERROR: Node %d not found" % controlled_node_id)
		return

	var state_str = _get_state_name(node.state, true)
	print_to_terminal("=== NODE %d STATUS ===" % controlled_node_id)
	print_to_terminal("State: %s" % state_str)

func cmd_connect(args: Array):
	if args.is_empty():
		print_to_terminal("Usage: connect <node_id>")
		print_to_terminal("Example: connect 2")
		return

	if not network_manager:
		print_to_terminal("ERROR: Network not initialized")
		return

	var target_node_id = int(args[0])
	var node = network_manager.get_network_node(target_node_id)

	if not node:
		print_to_terminal("ERROR: Node %d not found" % target_node_id)
		return

	# Connect to this node (like SSH)
	controlled_node_id = target_node_id
	connected_node = node
	current_path = "/home/user"  # Reset to home directory
	update_prompt()
	print_to_terminal("=== Connected to Node %d ===" % target_node_id)

func cmd_disconnect():
	if not is_connected_to_node():
		print_to_terminal("Not connected to any node")
		return

	print_to_terminal("Disconnected from Node %d" % controlled_node_id)
	controlled_node_id = -1
	connected_node = null
	current_path = "/home/user"
	update_prompt()

# NETWORK COMMANDS

func cmd_network():
	if not network_manager:
		print_to_terminal("ERROR: Network not initialized")
		return

	var health = network_manager.get_network_health()

	print_to_terminal("=== NETWORK STATUS ===")
	print_to_terminal("Nodes: %d total" % health["total"])
	print_to_terminal("  Healthy: %d" % health["healthy"])
	print_to_terminal("  Crashed: %d" % health["crashed"])
	print_to_terminal("  Byzantine: %d" % health["byzantine"])
	print_to_terminal("")

	for i in range(health["total"]):
		var node = network_manager.get_network_node(i)
		if node:
			var state_str = _get_state_name(node.state, true)
			print_to_terminal("Node %d: %s" % [i, state_str])

func cmd_consensus(args: Array):
	if not network_manager:
		print_to_terminal("ERROR: Network not initialized")
		return

	if args.is_empty():
		print_to_terminal("Usage: consensus <OPEN|LOCKED>")
		return

	var proposal_str = args[0].to_upper()
	var proposal = Enums.VoteValue.LOCKED

	if proposal_str == "OPEN":
		proposal = Enums.VoteValue.OPEN
	elif proposal_str == "LOCKED":
		proposal = Enums.VoteValue.LOCKED
	else:
		print_to_terminal("Invalid vote value. Use OPEN or LOCKED")
		return

	print_to_terminal("Initiating consensus for: [color=cyan]%s[/color]..." % proposal_str)
	print_to_terminal("")

	var result = network_manager.run_consensus(proposal)

	# Display result summary
	_display_consensus_result(result)

func _display_consensus_result(result: Dictionary):
	var success = result.get("success", false)
	var consensus_val = result.get("consensus", null)
	var confidence = result.get("confidence", 0.0)
	var rounds = result.get("rounds_used", 0)
	var blocked: Array = result.get("blocked_messages", [])

	print_to_terminal("=== CONSENSUS RESULT ===")

	if success:
		var val_name = "OPEN" if consensus_val == Enums.VoteValue.OPEN else "LOCKED"
		print_to_terminal("[color=green]SUCCESS[/color]: Network agreed on [color=cyan]%s[/color]" % val_name)
		print_to_terminal("  Confidence: %.0f%%" % (confidence * 100))
		print_to_terminal("  Rounds used: %d" % rounds)
	else:
		var reason = result.get("reason", "Unknown")
		print_to_terminal("[color=red]FAILED[/color]: %s" % reason)
		if consensus_val != null:
			var val_name = "OPEN" if consensus_val == Enums.VoteValue.OPEN else "LOCKED"
			print_to_terminal("  Network chose: %s (%.0f%% confidence)" % [val_name, confidence * 100])

	# Show blocked messages if any
	if not blocked.is_empty():
		print_to_terminal("")
		print_to_terminal("[color=yellow]Blocked messages:[/color] %d" % blocked.size())
		for msg in blocked.slice(0, 5):  # Show first 5
			print_to_terminal("  %s: Node %d -> Node %d" % [msg["type"], msg["from"], msg["to"]])
		if blocked.size() > 5:
			print_to_terminal("  ... and %d more" % (blocked.size() - 5))

	print_to_terminal("")
	print_to_terminal("output written to logs/consensus.log")

# LINK BLOCKING COMMANDS

func cmd_block(args: Array):
	if not network_manager or controlled_node_id < 0:
		print_to_terminal("ERROR: Terminal not connected to a node")
		return

	if args.is_empty():
		print_to_terminal("Usage: block <target_node> [rounds]")
		print_to_terminal("Blocks messages FROM this node TO target")
		return

	var target_id = int(args[0])
	var rounds = 1 if args.size() < 2 else int(args[1])

	if target_id < 0 or target_id >= network_manager.num_nodes:
		print_to_terminal("ERROR: Invalid node ID: %d" % target_id)
		return

	if target_id == controlled_node_id:
		print_to_terminal("ERROR: Cannot block messages to self")
		return

	network_manager.block_link(controlled_node_id, target_id, rounds)
	print_to_terminal("[color=yellow]Blocked[/color] link to Node %d for %d round(s)" % [target_id, rounds])

func cmd_unblock(args: Array):
	if not network_manager or controlled_node_id < 0:
		print_to_terminal("ERROR: Terminal not connected to a node")
		return

	if args.is_empty():
		print_to_terminal("Usage: unblock <target_node>")
		return

	var target_id = int(args[0])
	network_manager.unblock_link(controlled_node_id, target_id)
	print_to_terminal("[color=green]Unblocked[/color] link to Node %d" % target_id)

func cmd_links():
	if not network_manager:
		print_to_terminal("ERROR: Network not initialized")
		return

	var blocked = network_manager.get_blocked_links()

	if blocked.is_empty():
		print_to_terminal("No blocked links")
		return

	print_to_terminal("=== BLOCKED LINKS ===")
	for link in blocked:
		print_to_terminal("  Node %d -> Node %d (%d round(s) remaining)" % [link["from"], link["to"], link["rounds"]])

# MESSAGE INTERCEPTION COMMANDS

func cmd_spoof(args: Array):
	if not require_connection():
		return

	if args.size() < 2:
		print_to_terminal("Usage: spoof <target_node> <OPEN|LOCKED>")
		print_to_terminal("Makes this node send a different value to target")
		return

	var target_id = int(args[0])
	var value_str = args[1].to_upper()

	if target_id < 0 or target_id >= network_manager.num_nodes:
		print_to_terminal("ERROR: Invalid node ID: %d" % target_id)
		return

	if target_id == controlled_node_id:
		print_to_terminal("ERROR: Cannot spoof messages to self")
		return

	var value: Enums.VoteValue
	if value_str == "OPEN":
		value = Enums.VoteValue.OPEN
	elif value_str == "LOCKED":
		value = Enums.VoteValue.LOCKED
	else:
		print_to_terminal("ERROR: Invalid value. Use OPEN or LOCKED")
		return

	connected_node.set_spoof(target_id, value)
	print_to_terminal("[color=yellow]Spoof set:[/color] Messages to Node %d will show %s" % [target_id, value_str])

func cmd_unspoof(args: Array):
	if not require_connection():
		return

	if args.is_empty():
		# Clear all spoofs
		connected_node.clear_all_spoofs()
		print_to_terminal("[color=green]Cleared[/color] all spoofed messages")
		return

	var target_id = int(args[0])
	if not connected_node.has_spoof_for(target_id):
		print_to_terminal("No spoof set for Node %d" % target_id)
		return

	connected_node.clear_spoof(target_id)
	print_to_terminal("[color=green]Cleared[/color] spoof for Node %d" % target_id)

func cmd_spoofs():
	if not require_connection():
		return

	var spoofs = connected_node.get_all_spoofs()

	if spoofs.is_empty():
		print_to_terminal("No active spoofs on this node")
		return

	print_to_terminal("=== ACTIVE SPOOFS ===")
	for target_id in spoofs.keys():
		var value = spoofs[target_id]
		var value_str = "OPEN" if value == Enums.VoteValue.OPEN else "LOCKED"
		print_to_terminal("  -> Node %d: %s" % [target_id, value_str])

# DETECTION SYSTEM COMMANDS

func cmd_alerts():
	if not network_manager or not network_manager.network_state:
		print_to_terminal("ERROR: Network not initialized")
		return

	var state = network_manager.network_state
	var level_name = state.get_alert_level_name()
	var level_color = _get_alert_color(state.alert_level)

	print_to_terminal("=== NETWORK ALERTS ===")
	print_to_terminal("Alert Level: [color=%s]%s[/color]" % [level_color, level_name])
	print_to_terminal("")

	var anomalies = state.get_recent_anomalies(10)
	if anomalies.is_empty():
		print_to_terminal("No recent anomalies detected")
		return

	print_to_terminal("Recent Anomalies:")
	for anomaly in anomalies:
		var severity_str = _get_severity_indicator(anomaly["severity"])
		print_to_terminal("  %s [Node %d] %s: %s" % [severity_str, anomaly["node_id"], anomaly["type"], anomaly["details"]])

func cmd_suspicion():
	if not network_manager or not network_manager.network_state:
		print_to_terminal("ERROR: Network not initialized")
		return

	var state = network_manager.network_state

	print_to_terminal("=== NODE SUSPICION LEVELS ===")

	var has_suspicion = false
	for i in range(network_manager.num_nodes):
		var suspicion = state.get_node_suspicion(i)
		if suspicion > 0:
			has_suspicion = true
			var bar = _get_suspicion_bar(suspicion)
			var color = _get_suspicion_color(suspicion)
			print_to_terminal("  Node %d: [color=%s]%s[/color] (%d)" % [i, color, bar, suspicion])

	if not has_suspicion:
		print_to_terminal("No suspicious activity detected")

func cmd_cameras() -> void:
	var count: int = SecurityCameraManager.get_all_cameras().size()
	if count == 0:
		print_to_terminal("[color=red]No cameras available.[/color]")
		return
	print_to_terminal("[color=cyan]Opening camera view (%d camera(s))...[/color]" % count)
	SecurityCameraManager.open_camera_view()

func _get_alert_color(level: int) -> String:
	match level:
		0: return "green"
		1: return "yellow"
		2: return "orange"
		3: return "red"
	return "white"

func _get_severity_indicator(severity: int) -> String:
	match severity:
		1: return "[color=yellow]![/color]"
		2: return "[color=orange]!![/color]"
		3: return "[color=red]!!![/color]"
	return "?"

func _get_suspicion_bar(suspicion: int) -> String:
	var filled = mini(suspicion, 10)
	var bar = ""
	for i in range(filled):
		bar += "|"
	for i in range(10 - filled):
		bar += "."
	return "[" + bar + "]"

func _get_suspicion_color(suspicion: int) -> String:
	if suspicion >= 10:
		return "red"
	elif suspicion >= 6:
		return "orange"
	elif suspicion >= 3:
		return "yellow"
	return "green"

# UTILITIES

func _scroll_output(direction: int) -> void:
	var sb: ScrollBar = output_scroll.get_v_scroll_bar()
	var step := output_scroll.size.y * 0.8
	sb.value = clampf(sb.value + direction * step, sb.min_value, sb.max_value)

func _get_state_name(state: Enums.NodeState, colored: bool = true) -> String:
	if colored:
		match state:
			Enums.NodeState.HEALTHY:
				return "[color=green]HEALTHY[/color]"
			Enums.NodeState.CRASHED:
				return "[color=red]CRASHED[/color]"
			Enums.NodeState.BYZANTINE:
				return "[color=yellow]BYZANTINE[/color]"
	else:
		match state:
			Enums.NodeState.HEALTHY:
				return "HEALTHY"
			Enums.NodeState.CRASHED:
				return "CRASHED"
			Enums.NodeState.BYZANTINE:
				return "BYZANTINE"
	return "UNKNOWN"

# TAB COMPLETION

func handle_tab_complete():
	var text = input_field.text
	var parts = text.split(" ", false)

	if parts.is_empty():
		return

	if parts.size() == 1:
		autocomplete_command(parts[0])
	else:
		autocomplete_filename(parts[-1])

func autocomplete_command(partial: String):
	var commands = ["ls", "cd", "pwd", "help", "cat", "tail", "clear",
					"reboot", "crash", "corrupt", "status", "network", "consensus", "connect",
					"disconnect", "block", "unblock", "links", "spoof", "unspoof", "spoofs",
					"alerts", "suspicion"]
	var matches: Array[String] = []

	for cmd in commands:
		if cmd.begins_with(partial):
			matches.append(cmd)

	if matches.size() == 1:
		input_field.text = matches[0] + " "
		input_field.caret_column = input_field.text.length()
	elif matches.size() > 1:
		print_to_terminal("Possible commands: " + ", ".join(matches))

func autocomplete_filename(partial: String):
	var search_path: String
	var file_part: String

	if partial.contains("/"):
		var last_slash = partial.rfind("/")
		search_path = normalize_path(partial.substr(0, last_slash + 1))
		file_part = partial.substr(last_slash + 1)
	else:
		search_path = current_path
		file_part = partial

	var dir_node = get_node_at_path(search_path)
	if dir_node == null or dir_node["type"] != "dir":
		return

	var matches: Array[String] = []
	for child_name in dir_node["children"].keys():
		if child_name.begins_with(file_part):
			matches.append(child_name)

	if matches.size() == 1:
		var parts = input_field.text.split(" ", false)
		var completed = matches[0]

		if dir_node["children"][completed]["type"] == "dir":
			completed += "/"

		if partial.contains("/"):
			var last_slash = partial.rfind("/")
			parts[-1] = partial.substr(0, last_slash + 1) + completed
		else:
			parts[-1] = completed

		input_field.text = " ".join(parts)
		input_field.caret_column = input_field.text.length()
	elif matches.size() > 1:
		print_to_terminal(", ".join(matches))

# PUBLIC API
var _autoscroll_queued := false

func print_to_terminal(line: String) -> void:
	output_label.append_text(line + "\n")
	_queue_autoscroll()

func _queue_autoscroll() -> void:
	if _autoscroll_queued:
		return
	_autoscroll_queued = true
	_autoscroll_async()

func _autoscroll_async() -> void:
	# Wait for RichTextLabel fit-content + VBox layout + ScrollContainer to update.
	await get_tree().process_frame
	await get_tree().process_frame

	_autoscroll_queued = false

	var sb: ScrollBar = output_scroll.get_v_scroll_bar()
	sb.value = sb.max_value


func append_to_file(path: String, line: String) -> bool:
	var resolved = resolve_path(path)
	var node = resolved["node"]

	if node == null or node["type"] == "dir":
		return false

	if node.get("read_only", false):
		return false

	if node["content"] != "" and not node["content"].ends_with("\n"):
		node["content"] += "\n"
	node["content"] += line + "\n"
	return true

func update_prompt():
	var path_display = current_path

	# Shorten /home/user to ~
	if current_path.begins_with("/home/user"):
		path_display = current_path.replace("/home/user", "~")
		if path_display == "":
			path_display = "~"

	if controlled_node_id >= 0:
		prompt_label.text = "user@node%d:%s$ " % [controlled_node_id, path_display]
	else:
		prompt_label.text = "user@terminal:%s$ " % path_display

extends Control
class_name TerminalUI

# VARIABLES

var root_directory: Dictionary = {}
var current_path: String = "/home/user"
var accept_input: bool = true
var command_history: Array[String] = []
var history_index: int = -1

var network_manager: NetworkManager = null
var controlled_node_id: int = -1

@onready var output_label = $MarginContainer/VBoxContainer/OutputLabel
@onready var input_field = $MarginContainer/VBoxContainer/InputContainer/InputField
@onready var prompt_label = $MarginContainer/VBoxContainer/InputContainer/PromptLabel

# INITIALIZATION

func _ready():
	output_label.scroll_following = true
	
	input_field.grab_focus()
	print_to_terminal("Terminal ready. Type 'help' for commands.")
	input_field.text_submitted.connect(_on_command_entered)
	input_field.gui_input.connect(_on_input_field_gui_input)
	
	await get_tree().process_frame
	network_manager = get_tree().get_first_node_in_group("network_manager")
	update_prompt()

func load_filesystem(filesystem_scene: PackedScene = null):
	if filesystem_scene:
		var filesystem_instance = filesystem_scene.instantiate()
		
		filesystem_instance._ready()  # Force _ready to run
		root_directory = {
			"type": "dir",
			"children": filesystem_instance.root
		}
		
		filesystem_instance.queue_free()
	else:
		push_error("No Filesystem provided.")

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
	var current = root_directory
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
	return root_directory

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
			output_label.scroll_vertical -= 100
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_PAGEDOWN:
			output_label.scroll_vertical += 100
			get_viewport().set_input_as_handled()
		elif event.unicode != 0 and event.unicode < 128:
			var character = char(event.unicode)
			input_field.text += character
			input_field.caret_column = input_field.text.length()
			get_viewport().set_input_as_handled()

func _on_input_field_gui_input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			handle_tab_complete()
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
	print_to_terminal("  connect <id> - connect to a different node")
	print_to_terminal("  consensus <OPEN|LOCKED> - trigger consensus")

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
	
	controlled_node_id = target_node_id
	update_prompt()
	print_to_terminal("=== Connected to Node %d ===" % target_node_id)

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

	print_to_terminal("Initiating consensus for: %s" % proposal_str)
	network_manager.run_consensus(proposal)

# UTILITIES

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
					"reboot", "crash", "corrupt", "status", "network", "consensus", "connect"]
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

func print_to_terminal(text: String):
	output_label.text += text + "\n"

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

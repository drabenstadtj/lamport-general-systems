extends Control
class_name TerminalUI

# FILE SYSTEM CLASS

class FileNode:
	var name: String
	var is_directory: bool
	var content: String = ""
	var children: Array = []
	var parent: FileNode = null
	
	func _init(node_name: String, is_dir: bool = false):
		name = node_name
		is_directory = is_dir
	
	func add_child(child: FileNode):
		child.parent = self
		children.append(child)
	
	func get_child_by_name(child_name: String) -> FileNode:
		for child in children:
			if child.name == child_name:
				return child
		return null

# VARIABLES

var root_directory: FileNode
var current_directory: FileNode
var accept_input: bool = true
var command_history: Array[String] = []
var history_index: int = -1

var network_manager: NetworkManager = null
var controlled_node_id: int = -1  # Which node this terminal controls

@onready var output_label = $MarginContainer/VBoxContainer/OutputLabel
@onready var input_field = $MarginContainer/VBoxContainer/InputContainer/InputField
@onready var prompt_label = $MarginContainer/VBoxContainer/InputContainer/PromptLabel

# INITIALIZATION

func _ready():
	setup_file_system()
	
	output_label.scroll_following = true
	
	input_field.grab_focus()
	print_to_terminal("Terminal ready. Type 'help' for commands.")
	input_field.text_submitted.connect(_on_command_entered)
	input_field.gui_input.connect(_on_input_field_gui_input)
	
	# Find NetworkManager
	await get_tree().process_frame
	network_manager = get_tree().get_first_node_in_group("network_manager")

func setup_network_context(node_id: int):
	"""Called by Terminal (parent) to set which node this UI controls."""
	controlled_node_id = node_id
	update_prompt()  # NOW update the prompt with the node ID
	print_to_terminal("=== Connected to Node %d ===" % node_id)

func setup_file_system():
	root_directory = FileNode.new("root", true)
	
	var home = FileNode.new("home", true)
	root_directory.add_child(home)
	
	var user = FileNode.new("user", true)
	home.add_child(user)
	
	var documents = FileNode.new("documents", true)
	var projects = FileNode.new("projects", true)
	var downloads = FileNode.new("downloads", true)
	
	user.add_child(documents)
	user.add_child(projects)
	user.add_child(downloads)
	
	# Add files
	var readme = FileNode.new("readme.txt", false)
	readme.content = "Welcome to the terminal!\nThis is a test file."
	user.add_child(readme)
	
	var log_file = FileNode.new("system.log", false)
	log_file.content = """System Log - Lamport General Systems
Facility operational status: DEGRADED
Warning: Byzantine fault tolerance at minimum threshold"""
	user.add_child(log_file)
	
	var notes = FileNode.new("notes.txt", false)
	notes.content = "Node maintenance log:\n- Check consensus thresholds\n- Monitor network health"
	documents.add_child(notes)

	var consensus_log = FileNode.new("consensus.log", false)
	consensus_log.content = "=== Consensus Log ===\nNode logs will appear here during consensus rounds.\n"
	user.add_child(consensus_log)

	current_directory = user

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
			cmd_ls()
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
		
		# Node-specific commands
		"reboot":
			cmd_reboot()
		"crash":
			cmd_crash()
		"corrupt":
			cmd_corrupt()
		"status":
			cmd_status()
		
		# Network-wide commands
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

func cmd_ls():
	if current_directory.children.size() == 0:
		return
	
	for child in current_directory.children:
		if child.is_directory:
			print_to_terminal("[color=blue]" + child.name + "/[/color]")
		else:
			print_to_terminal(child.name)

func cmd_cd(args: Array):
	if args.size() == 0:
		print_to_terminal("cd: missing directory argument")
		return
	
	var target_name = args[0].trim_suffix("/")
	
	if target_name == "..":
		if current_directory.parent != null:
			current_directory = current_directory.parent
		return
	
	if target_name == ".":
		return
	
	# Declare 'target' once at the top of the function
	var target: FileNode = null
	
	if target_name.begins_with("/"):
		target = resolve_absolute_path(target_name)
		if target == null:
			print_to_terminal("cd: " + target_name + ": No such directory")
			return
		if not target.is_directory:
			print_to_terminal("cd: " + target_name + ": Not a directory")
			return
		current_directory = target
		return
	
	target = current_directory.get_child_by_name(target_name)
	
	if target == null:
		print_to_terminal("cd: " + target_name + ": No such directory")
		return
	
	if not target.is_directory:
		print_to_terminal("cd: " + target_name + ": Not a directory")
		return
	
	current_directory = target

func cmd_pwd():
	var path_parts = []
	var current = current_directory
	
	while current.parent != null:
		path_parts.insert(0, current.name)
		current = current.parent
	
	var full_path = "/" + "/".join(path_parts)
	print_to_terminal(full_path)

func cmd_cat(args: Array):
	if args.size() == 0:
		print_to_terminal("cat: missing file argument")
		return
	
	var filename = args[0]
	var file = get_file_by_path(filename)
	
	if file == null:
		print_to_terminal("cat: " + filename + ": No such file")
		return
	
	if file.is_directory:
		print_to_terminal("cat: " + filename + ": Is a directory")
		return
	
	print_to_terminal(file.content)

func cmd_tail(args: Array):
	if args.size() == 0:
		print_to_terminal("tail: missing file argument")
		return
	
	var num_lines = 10
	var filename = args[0]
	
	if args[0] == "-n" and args.size() >= 3:
		num_lines = int(args[1])
		filename = args[2]
	
	var file = get_file_by_path(filename)
	
	if file == null:
		print_to_terminal("tail: " + filename + ": No such file")
		return
	
	if file.is_directory:
		print_to_terminal("tail: " + filename + ": Is a directory")
		return
	
	var lines = file.content.split("\n")
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
	if args.size() == 0:
		print_to_terminal("Usage: connect <node_id>")
		print_to_terminal("Example: connect 2")
		return
		
	if not network_manager:
		print_to_terminal("ERROR: Network not initialized")
		return
	
	# Convert string argument to int
	var target_node_id = int(args[0])
	
	# Check if target node exists
	var node = network_manager.get_network_node(target_node_id)
	if not node:
		print_to_terminal("ERROR: Node %d not found" % target_node_id)
		return
	
	# Switch to new node
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
	
	if args.size() == 0:
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

func resolve_absolute_path(path: String) -> FileNode:
	var clean_path = path.trim_prefix("/")
	if clean_path == "":
		return root_directory
	
	var parts = clean_path.split("/", false)
	var current = root_directory
	
	for part in parts:
		if part == "..":
			if current.parent != null:
				current = current.parent
			continue
		
		if part == ".":
			continue
		
		var child = current.get_child_by_name(part)
		if child == null:
			return null
		current = child
	
	return current

func get_file_by_path(path: String) -> FileNode:
	if path.begins_with("/"):
		return resolve_absolute_path(path)
	return current_directory.get_child_by_name(path)

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
	
	if parts.size() == 0:
		return
	
	if parts.size() == 1:
		autocomplete_command(parts[0])
	else:
		var partial = parts[-1]
		autocomplete_filename(partial, parts.size() - 1)

func autocomplete_command(partial: String):
	var commands = ["ls", "cd", "pwd", "help", "cat", "tail", "clear", 
					"reboot", "crash", "corrupt", "status", "network", "consensus", "connect"]
	var matches = []
	
	for cmd in commands:
		if cmd.begins_with(partial):
			matches.append(cmd)
	
	if matches.size() == 1:
		input_field.text = matches[0] + " "
		input_field.caret_column = input_field.text.length()
	elif matches.size() > 1:
		print_to_terminal("Possible commands: " + ", ".join(matches))

func autocomplete_filename(partial: String, _arg_index: int):
	var matches = []
	var search_dir = current_directory
	var prefix = ""
	
	if partial.begins_with("/"):
		var last_slash = partial.rfind("/")
		var dir_path = partial.substr(0, last_slash + 1)
		var file_part = partial.substr(last_slash + 1)
		
		if dir_path == "/":
			search_dir = root_directory
		else:
			search_dir = resolve_absolute_path(dir_path.trim_suffix("/"))
			if search_dir == null:
				return
		
		prefix = dir_path
		partial = file_part
	
	for child in search_dir.children:
		if child.name.begins_with(partial):
			matches.append(child.name)
	
	if matches.size() == 1:
		var parts = input_field.text.split(" ", false)
		parts[-1] = prefix + matches[0]
		if search_dir.get_child_by_name(matches[0]).is_directory:
			parts[-1] += "/"
		input_field.text = " ".join(parts)
		input_field.caret_column = input_field.text.length()
	elif matches.size() > 1:
		print_to_terminal(", ".join(matches))

# PUBLIC API

func print_to_terminal(text: String):
	output_label.text += text + "\n"

func append_to_file(path: String, line: String) -> bool:
	var file = get_file_by_path(path)
	if file != null and not file.is_directory:
		if file.content != "" and not file.content.ends_with("\n"):
			file.content += "\n"
		file.content += line + "\n"
		return true
	return false

func update_prompt():
	prompt_label.text = "user@node%d:~$ " % controlled_node_id if controlled_node_id >= 0 else "user@terminal:~$ "

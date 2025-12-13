extends Control

# ============================================================================
# FILE SYSTEM CLASS
# ============================================================================

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

# ============================================================================
# VARIABLES
# ============================================================================

var root_directory: FileNode
var current_directory: FileNode
var accept_input: bool = true
var command_history: Array[String] = []
var history_index: int = -1   


@onready var output_label = $MarginContainer/VBoxContainer/OutputLabel
@onready var input_field = $MarginContainer/VBoxContainer/InputContainer/InputField
@onready var prompt_label = $MarginContainer/VBoxContainer/InputContainer/PromptLabel

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	setup_file_system()
	update_prompt()
	
	input_field.grab_focus()
	print_to_terminal("Terminal ready. Type 'help' for commands.")
	input_field.text_submitted.connect(_on_command_entered)
	input_field.gui_input.connect(_on_input_field_gui_input)

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
	
	# Add some files with content
	var readme = FileNode.new("readme.txt", false)
	readme.content = "Welcome to the terminal!\nThis is a test file.\nI am under the water. Please help me."
	user.add_child(readme)
	
	var log_file = FileNode.new("system.log", false)

	log_file.content = """        __.,,-------.._
	 ,'"   _      _   "`.
	/.__, ._  -=- _"`    Y
   (.____.-.`      ""`   j
	VvvvvvV`.Y,.    _.,-'       ,     ,     ,
		Y    ||,   '"\\         ,/    ,/    ./
        |   ,'  ,     `-..,'_,'/___,'/   ,'/   ,
   ..  ,;,,',-'"\\,'  ,  .     '     ' ""' '--,/    .. ..
 ,'. `.`---'     `, /  , Y -=-    ,'   ,   ,. .`-..||_|| ..
ff\\\\`. `._        /f ,'j j , ,' ,   , f ,  \\=\\ Y   || ||`||_..
l` \\` `.`."`-..,-' j  /./ /, , / , / /l \\   \\=\\l   || `' || ||...
 `  `   `-._ `-.,-/ ,' /`"/-/-/-/-"'''"`.`.  `'.\\--`'--..`'_`' || ,
            "`-_,',  ,'  f    ,   /      `._    ``._     ,  `-.`'//         ,
		  ,-"'' _.,-'    l_,-'_,,'          "`-._ . "`. /|     `.'\\ ,       |
		,',.,-'"          \\=) ,`-.         ,    `-'._`.V |       \\ // .. . /j
		|f\\\\               `._ )-."`.     /|         `.| |        `.`-||-\\/
		l` \\`                 "`._   "`--' j          j' j          `-`---'
		 `  `                     "`_,-','/       ,-'"  /
								 ,'",__,-'       /,, ,-'
								 Vvv'            VVv'"""

	user.add_child(log_file)
	
	var notes = FileNode.new("notes.txt", false)
	notes.content = "TODO:\n- Implement more commands\n- Add color themes\n"
	documents.add_child(notes)
	
	current_directory = user

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event):
	if not accept_input:
		return
	
	if event is InputEventKey and event.pressed:  
		# Handle special keys
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
		elif event.unicode != 0 and event.unicode < 128:
			# Add regular character
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
	
	# Add to history
	command_history.append(text)
	history_index = -1  # Reset history navigation
	
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
		# Access history in reverse order (most recent first)
		var actual_index = command_history.size() - 1 - history_index
		input_field.text = command_history[actual_index]
	
	input_field.caret_column = input_field.text.length()

# ============================================================================
# COMMAND PROCESSING
# ============================================================================

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
		"help":
			cmd_help()
		_:
			print_to_terminal("Command not found: " + cmd)

# ============================================================================
# COMMAND IMPLEMENTATIONS
# ============================================================================

func cmd_help():
	print_to_terminal("Available commands:")
	print_to_terminal("  ls         - list files and directories")
	print_to_terminal("  cd <dir>   - change directory")
	print_to_terminal("  pwd        - print working directory")
	print_to_terminal("  cat <file> - display file contents")
	print_to_terminal("  tail <file> - display last 10 lines of file")
	print_to_terminal("  tail -n <num> <file> - display last N lines")
	print_to_terminal("  help       - show this message")

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
	
	var target_name = args[0].trim_suffix("/")  # Add this line to strip trailing /
	
	# Handle going back
	if target_name == "..":
		if current_directory.parent != null:
			current_directory = current_directory.parent
		return
	
	# Handle staying put
	if target_name == ".":
		return
	
	# Handle absolute paths (start with /)
	if target_name.begins_with("/"):
		var target = resolve_absolute_path(target_name)
		if target == null:
			print_to_terminal("cd: " + target_name + ": No such directory")
			return
		if not target.is_directory:
			print_to_terminal("cd: " + target_name + ": Not a directory")
			return
		current_directory = target
		return
	
	# Handle relative paths (just a name)
	var target = current_directory.get_child_by_name(target_name)
	
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
	
	# Walk up the tree to build the path
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
	
	var num_lines = 10  # Default to last 10 lines
	var filename = args[0]
	
	# Check if first arg is -n flag
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
	
	# Split content into lines and get last N
	var lines = file.content.split("\n")
	var start_index = max(0, lines.size() - num_lines)
	var tail_lines = lines.slice(start_index)
	
	print_to_terminal("\n".join(tail_lines))

# ============================================================================
# TAB COMPLETION
# ============================================================================

func handle_tab_complete():
	var text = input_field.text
	var parts = text.split(" ", false)
	
	if parts.size() == 0:
		return
	
	# If just typing a command
	if parts.size() == 1:
		autocomplete_command(parts[0])
	# If typing arguments (like filenames)
	else:
		var cmd = parts[0]
		var partial = parts[-1]  # Last part being typed
		autocomplete_filename(partial, parts.size() - 1)

func autocomplete_command(partial: String):
	var commands = ["ls", "cd", "pwd", "help", "cat", "tail"]
	var matches = []
	
	for cmd in commands:
		if cmd.begins_with(partial):
			matches.append(cmd)
	
	if matches.size() == 1:
		input_field.text = matches[0] + " "
		input_field.caret_column = input_field.text.length()
	elif matches.size() > 1:
		print_to_terminal("Possible commands: " + ", ".join(matches))

func autocomplete_filename(partial: String, arg_index: int):
	var matches = []
	var search_dir = current_directory
	var prefix = ""
	
	# Handle absolute paths
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
	
	# Find all children that match the partial text
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

# ============================================================================
# PATH RESOLUTION UTILITIES
# ============================================================================

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

# ============================================================================
# PUBLIC API (for other scripts)
# ============================================================================

func get_file_content(path: String) -> String:
	var file = get_file_by_path(path)
	if file != null and not file.is_directory:
		return file.content
	return ""

func set_file_content(path: String, new_content: String) -> bool:
	var file = get_file_by_path(path)
	if file != null and not file.is_directory:
		file.content = new_content
		return true
	return false

# ============================================================================
# UI UTILITIES
# ============================================================================

func update_prompt():
	prompt_label.text = "user@terminal:~$ "

func print_to_terminal(text: String):
	output_label.text += text + "\n"

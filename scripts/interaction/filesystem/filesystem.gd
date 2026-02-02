class_name Filesystem
extends Node

var root: Dictionary = {}
@export var print_parse: bool = true

func _ready():
	root = _parse_node(self, "")

func _parse_node(node: Node, path: String) -> Dictionary:
	var entries: Dictionary = {}
	
	for child in node.get_children():
		var child_path = path + "/" + child.name
		
		if child is FileNode:
			entries[child.get_filename()] = {
				"type": "file",
				"file_type": child.file_type,
				"content": child.content,
				"read_only": child.read_only,
				"access_level": child.access_level
			}
			if print_parse:
				print("  FILE: %s" % (path + "/" + child.get_filename()))
				
		elif child is DirNode:
			if print_parse:
				print("  DIR:  %s/" % child_path)
			entries[child.name] = {
				"type": "dir",
				"access_level": child.access_level,
				"children": _parse_node(child, child_path)
			}
	
	return entries

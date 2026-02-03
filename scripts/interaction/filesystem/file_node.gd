# file_node.gd
class_name FileNode
extends Node

@export_enum("text", "log", "binary", "executable") var file_type: String = "text"
@export_multiline var content: String = ""
@export var read_only: bool = false
@export var access_level: int = 0

func get_filename() -> String:
	var extension: String
	match file_type:
		"text":
			extension = ".txt"
		"log":
			extension = ".log"
		"binary":
			extension = ".bin"
		"executable":
			return name  # no extension for executables
		_:
			extension = ".txt"
	
	return name + extension

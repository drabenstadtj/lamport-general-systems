@tool
extends Label3D
   
func _ready():
	visible = Engine.is_editor_hint()

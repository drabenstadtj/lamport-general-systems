extends Control

const MESSAGE_SCENE := preload("res://scenes/ui/pda_message.tscn")

@onready var message_container: VBoxContainer = $VBoxContainer/ScrollContainer/MessageContainer

func _ready() -> void:
	SaveManager.message_received.connect(_on_message_received)
	_populate()

func _populate() -> void:
	for child in message_container.get_children():
		child.queue_free()

	var messages: Array = SaveManager.current.pda_messages
	for i in range(messages.size() - 1, -1, -1):  # newest first
		_add_message_node(messages[i])

func _add_message_node(msg: Dictionary) -> void:
	var node := MESSAGE_SCENE.instantiate()
	node.get_node("Container/Subject").text = "[%s] %s" % [msg.get("sender", "Unknown"), msg.get("subject", "")]
	node.get_node("Container/Content").text = msg.get("body", "")
	message_container.add_child(node)

func _on_message_received(_msg: Dictionary) -> void:
	if visible:
		_populate()

# network_message.gd
extends RefCounted
class_name NetworkMessage

enum MessageType {
	PRE_PREPARE,
	PREPARE,
	COMMIT
}

var type: MessageType
var sender_id: int
var receiver_id: int 
var proposed_value: Enums.VoteValue
var round_number: int

func _init(msg_type: MessageType, sender: int, receiver: int, value: Enums.VoteValue, round_num: int):
	type = msg_type
	sender_id = sender
	receiver_id = receiver
	proposed_value = value
	round_number = round_num

func get_description() -> String:
	var type_name = ["PRE_PREPARE", "PREPARE", "COMMIT"][type]
	var value_name = "OPEN" if proposed_value == Enums.VoteValue.OPEN else "LOCKED"
	return "%s from Node %d: %s (Round %d)" % [type_name, sender_id, value_name, round_number]

func get_type_name() -> String:
	return ["PRE_PREPARE", "PREPARE", "COMMIT"][type]

func get_value_name() -> String:
	return "OPEN" if proposed_value == Enums.VoteValue.OPEN else "LOCKED"

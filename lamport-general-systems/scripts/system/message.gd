extends RefCounted
class_name BFTMessage

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


func _init(msg_type: MessageType, sender: int, receiver: int, value: Enums.VoteValue, round: int):
	type = msg_type
	sender_id = sender
	receiver_id = receiver
	proposed_value = value
	round_number = round

func get_description() -> String:
	var type_name = ["PRE_PREPARE", "PREPARE", "COMMIT"][type]
	var value_name = "OPEN" if proposed_value == Enums.VoteValue.OPEN else "LOCKED"
	return "%s from Node %d: %s (Round %d)" % [type_name, sender_id, value_name, round_number]

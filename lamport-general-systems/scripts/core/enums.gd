extends Node

enum NodeState {
	HEALTHY,
	CRASHED,
	BYZANTINE
}

enum SecurityLevel {
	MAINTENANCE = 1,
	NORMAL = 2,
	DEFENSIVE = 3
}

enum VoteValue {
	OPEN,
	LOCKED
}

enum ActionType {
	REBOOT_NODE,
	CRASH_NODE,
	CORRUPT_NODE,
	COMMAND_DOOR,
	EXPLOIT_DOOR
}

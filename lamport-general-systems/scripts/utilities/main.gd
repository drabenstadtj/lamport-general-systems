extends Node

# NOTE: This is old test code for BFTNetworkManager which doesn't exist yet.
# Commented out to prevent parse errors. Uncomment when BFTNetworkManager is implemented.

#var network_manager: BFTNetworkManager
#
#func _ready():
#	# Create network manager
#	network_manager = BFTNetworkManager.new()
#	network_manager.name = "BFTNetwork"
#	add_child(network_manager)
#
#	# Connect signals
#	network_manager.network_ready.connect(_on_network_ready)
#	network_manager.consensus_reached.connect(_on_consensus_reached)
#	network_manager.consensus_failed.connect(_on_consensus_failed)
#
#	# Setup and run
#	start_bft_protocol()
#
#func start_bft_protocol():
#	var num_nodes = 7
#	var num_corrupted = 2
#	var initial_value = 1
#
#	print("=== Setting up BFT Network ===")
#	print("Total nodes: %d" % num_nodes)
#	print("Corrupted nodes: %d" % num_corrupted)
#	print("Initial value: %d\n" % initial_value)
#
#	network_manager.setup_network(num_nodes, num_corrupted, initial_value)
#
#func _on_network_ready():
#	print("Network is ready, starting protocol...\n")
#	network_manager.run_protocol()
#
#func _on_consensus_reached(value):
#	print("\nGame State: Consensus reached on value: %s" % str(value))
#	# Your game logic here
#
#func _on_consensus_failed(decisions: Array):
#	print("\nGame State: Nodes disagreed!")
#	# Handle failure case
#
## Optional: Visualize network
#func _process(_delta):
#	# You can add visual debugging here
#	pass
#
## Example: Trigger protocol with input
#func _input(event):
#	if event is InputEventKey and event.pressed:
#		if event.keycode == KEY_SPACE:
#			print("\n--- Restarting Protocol ---\n")
#			start_bft_protocol()

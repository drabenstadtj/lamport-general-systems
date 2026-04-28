extends Node3D
class_name Server

@export var is_active: bool = false
@export var node_id: int = -1
@export var is_powered_on: bool = true

@onready var status_light = $StatusLight
@onready var audio_component: ServerAudioManager = $ServerAudioManager

# Consensus LED animation
var is_in_consensus: bool = false
var consensus_tween: Tween = null
var base_light_color: Color = Color.GREEN
var base_light_energy: float = 5.0
var consensus_blink_start_time: int = 0
const MIN_BLINK_DURATION_MS: int = 800  # Minimum time to show blinking

func _ready():
	if not is_active:
		if status_light:
			status_light.visible = false
			status_light.light_energy = 0.0
	else:
		add_to_group("server")

		await NetworkManager.all_nodes_ready

		NetworkManager.node_state_changed.connect(_on_node_state_changed)
		NetworkManager.consensus_started.connect(_on_consensus_started)
		NetworkManager.consensus_completed.connect(_on_consensus_completed)

		sync_with_network_state()
		update_status_light()

		await get_tree().process_frame
		var power_button = find_power_button()
		if power_button:
			power_button._update_prompt()


func sync_with_network_state():
	var node = NetworkManager.get_network_node(node_id)
	if node:
		match node.state:
			Enums.NodeState.ONLINE:
				is_powered_on = true
			Enums.NodeState.ERROR:
				is_powered_on = true
			Enums.NodeState.OFFLINE:
				is_powered_on = false
			Enums.NodeState.COMPROMISED:
				is_powered_on = true
		
		# Sync audio state
		if audio_component:
			if is_powered_on:
				audio_component.start_idle_system()
			else:
				audio_component.stop_idle_system()
		
		update_status_light()
		
@warning_ignore("unused_parameter")
func _on_node_state_changed(changed_node_id: int, old_state: Enums.NodeState, new_state: Enums.NodeState):
	if changed_node_id != node_id:
		return
	
	var was_powered_on = is_powered_on
	
	match new_state:
		Enums.NodeState.ONLINE:
			is_powered_on = true
		Enums.NodeState.ERROR:
			is_powered_on = true
		Enums.NodeState.OFFLINE:
			is_powered_on = false
		Enums.NodeState.COMPROMISED:
			is_powered_on = true
	
	# Handle audio transitions
	if audio_component and was_powered_on != is_powered_on:
		if is_powered_on:
			audio_component.play_power_on_sequence()
		else:
			audio_component.play_power_off_sequence()
	
	update_status_light()

func update_status_light():
	if not status_light:
		return
	
	if not is_active:
		status_light.visible = false
		status_light.light_energy = 0.0
		return
	
	status_light.visible = true
	
	var node = NetworkManager.get_network_node(node_id)
	if node:
		match node.state:
			Enums.NodeState.ONLINE:
				status_light.light_color = Color.GREEN
				status_light.light_energy = 5.0
			Enums.NodeState.ERROR:
				status_light.light_color = Color.RED
				status_light.light_energy = 5.0
			Enums.NodeState.OFFLINE:
				status_light.light_color = Color(1.0, 0.4, 0.0)
				status_light.light_energy = 0.5
			Enums.NodeState.COMPROMISED:
				status_light.light_color = Color.YELLOW
				status_light.light_energy = 5.0
	else:
		if is_powered_on:
			status_light.light_color = Color.GREEN
			status_light.light_energy = 5.0
		else:
			status_light.light_color = Color.BLACK
			status_light.light_energy = 0.0

func toggle_power():
	if not is_active:
		return
	
	var node = NetworkManager.get_network_node(node_id)
	if node:
		if node.is_powered_down():
			NetworkManager.power_on_node(node_id)
		elif node.is_crashed() or node.is_healthy():
			NetworkManager.power_off_node(node_id)

func find_power_button() -> PowerButtonInteractable:
	for child in get_children():
		if child is PowerButtonInteractable:
			return child
		var result = _find_power_button_recursive(child)
		if result:
			return result
	return null

func _find_power_button_recursive(node: Node) -> PowerButtonInteractable:
	for child in node.get_children():
		if child is PowerButtonInteractable:
			return child
		var result = _find_power_button_recursive(child)
		if result:
			return result
	return null

func get_power_state() -> bool:
	return is_powered_on

# Consensus LED Animation

func _on_consensus_started(_proposal: Enums.VoteValue):
	if not is_active or not is_powered_on:
		return

	is_in_consensus = true
	consensus_blink_start_time = Time.get_ticks_msec()
	start_consensus_blink()

func _on_consensus_completed(_result: Dictionary):
	is_in_consensus = false
	# Ensure minimum blink duration so player can see the effect
	var elapsed = Time.get_ticks_msec() - consensus_blink_start_time
	var remaining = max(0, MIN_BLINK_DURATION_MS - elapsed)
	if remaining > 0:
		await get_tree().create_timer(remaining / 1000.0).timeout
	stop_consensus_blink()

func start_consensus_blink():
	if not status_light:
		return

	# Store current color/energy as base
	base_light_color = status_light.light_color
	base_light_energy = status_light.light_energy

	# Start blinking tween
	_do_consensus_blink()

func _do_consensus_blink():
	if not is_in_consensus or not status_light:
		return

	# Kill any existing tween
	if consensus_tween and consensus_tween.is_valid():
		consensus_tween.kill()

	consensus_tween = create_tween()
	consensus_tween.set_loops()

	# Blink pattern: bright -> dim -> bright
	var blink_color = Color.CYAN
	var dim_energy = base_light_energy * 0.3
	var bright_energy = base_light_energy * 1.5

	# Quick flicker effect
	consensus_tween.tween_property(status_light, "light_color", blink_color, 0.05)
	consensus_tween.parallel().tween_property(status_light, "light_energy", bright_energy, 0.05)
	consensus_tween.tween_property(status_light, "light_energy", dim_energy, 0.1)
	consensus_tween.tween_property(status_light, "light_color", base_light_color, 0.05)
	consensus_tween.parallel().tween_property(status_light, "light_energy", base_light_energy, 0.05)
	consensus_tween.tween_interval(0.15)

func stop_consensus_blink():
	if consensus_tween and consensus_tween.is_valid():
		consensus_tween.kill()
		consensus_tween = null

	# Restore to proper state
	update_status_light()

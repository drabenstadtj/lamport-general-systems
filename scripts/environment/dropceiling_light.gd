@tool
extends Node3D

@export var light_color: Color = Color(0.941, 1.0, 0.824, 1.0):
	set(value):
		light_color = value
		update_light()

@export var light_energy: float = .25:
	set(value):
		light_energy = value
		update_light()

@export var flicker: bool = false

var _flicker_timer: float = 0.0
var _flicker_state: bool = true
var _burst_count: int = 0

func _process(delta: float):
	if Engine.is_editor_hint() or not flicker or light_energy <= 0.0:
		return
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		if _burst_count > 0:
			# mid-burst: rapid on/off
			_flicker_state = !_flicker_state
			_flicker_timer = randf_range(0.03, 0.1)
			_burst_count -= 1
		else:
			# between bursts: light is on, wait a while
			_flicker_state = true
			_flicker_timer = randf_range(2.0, 8.0)
			_burst_count = randi_range(2, 6)
		_apply_flicker()

func _apply_flicker():
	var light = get_node_or_null("OmniLight3D") as OmniLight3D
	if light:
		light.light_energy = light_energy if _flicker_state else 0.0
	var mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance:
		var mat = mesh_instance.get_active_material(0) as StandardMaterial3D
		if mat:
			mat.emission_enabled = _flicker_state

func _ready():
	var mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance:
		var mat = mesh_instance.get_active_material(0)
		if mat:
			mesh_instance.set_surface_override_material(0, mat.duplicate())
	update_light()

func update_light():
	if not has_node("OmniLight3D"):
		return

	var light = get_node("OmniLight3D") as OmniLight3D
	if light:
		light.light_color = light_color
		light.light_energy = light_energy

	var mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance:
		var mat = mesh_instance.get_active_material(0) as StandardMaterial3D
		if mat:
			mat.emission_enabled = light_energy > 0.0
			mat.emission_energy_multiplier = 8.0 if light_energy > 0.0 else 0.0

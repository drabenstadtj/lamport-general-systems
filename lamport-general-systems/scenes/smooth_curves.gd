@tool
extends Path3D

@export var bake_interval: float = 0.05:
	set(value):
		bake_interval = value
		if curve:
			curve.bake_interval = value

@export var apply_smoothing: bool = false:
	set(value):
		if value and curve:
			smooth_curve()

func _ready():
	if curve:
		curve.bake_interval = bake_interval

func smooth_curve():
	# Make the curve smoother by adjusting bake interval
	curve.bake_interval = bake_interval
	print("Curve smoothed with bake interval: ", bake_interval)

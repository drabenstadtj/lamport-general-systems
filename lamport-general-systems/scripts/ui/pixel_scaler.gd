extends SubViewportContainer

func _ready():
	get_tree().root.size_changed.connect(_update_scale)
	_update_scale()

func _update_scale():
	var window_size = get_tree().root.size
	var viewport_size = $SubViewport.size
	
	# Integer scaling only (2x, 3x, 4x, never fractional)
	var scale_x = floor(window_size.x / viewport_size.x)
	var scale_y = floor(window_size.y / viewport_size.y)
	var scale = max(1, min(scale_x, scale_y))
	
	# Apply the integer scale
	custom_minimum_size = viewport_size * scale
	size = viewport_size * scale
	
	# Center the container
	position = (window_size - (viewport_size * scale)) / 2

extends Node

func _ready():
	create_sorted_rainbow_palette()

func create_sorted_rainbow_palette():
	var num_colors = 64  # Fewer colors = more visible dithering
	var colors = []
	
	# Generate rainbow colors
	for i in range(num_colors):
		var hue = float(i) / float(num_colors)
		var color = Color.from_hsv(hue, 0.8, 0.8)
		colors.append(color)
	
	# Sort by luminosity (darkest to lightest)
	colors.sort_custom(func(a, b): 
		var lum_a = a.r * 0.299 + a.g * 0.587 + a.b * 0.114
		var lum_b = b.r * 0.299 + b.g * 0.587 + b.b * 0.114
		return lum_a < lum_b
	)
	
	# Create palette texture
	var img = Image.create(num_colors, 1, false, Image.FORMAT_RGB8)
	for x in range(num_colors):
		img.set_pixel(x, 0, colors[x])
	
	img.save_png("res://rainbow_palette_sorted.png")
	print("Sorted rainbow palette created!")

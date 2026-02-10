extends Control

@onready var cursor: TextureRect = $Cursor

# View references
@onready var mail_view = $MarginContainer/VBoxContainer/ViewBox/MailView
@onready var network_view = $MarginContainer/VBoxContainer/ViewBox/NetworkView
@onready var map_view = $MarginContainer/VBoxContainer/ViewBox/MapView
@onready var settings_view = $MarginContainer/VBoxContainer/ViewBox/SettingsView

# Button references
@onready var mail_button = $MarginContainer/VBoxContainer/BottomBar/Mail
@onready var network_button = $MarginContainer/VBoxContainer/BottomBar/Network
@onready var map_button = $MarginContainer/VBoxContainer/BottomBar/Map
@onready var settings_button = $MarginContainer/VBoxContainer/BottomBar/Settings

func _ready():
	if cursor:
		cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE  
		cursor.z_index = 1000
	
	# Connect button signals
	mail_button.pressed.connect(_on_mail_pressed)
	network_button.pressed.connect(_on_network_pressed)
	map_button.pressed.connect(_on_map_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	
	# Show default view
	show_view("mail")

func _input(event):
	if event is InputEventMouseMotion and visible and cursor:
		var anchor_offset = Vector2(0.039, 0.003)
		var parent_size = cursor.get_parent_control().size
		var pixel_offset = anchor_offset * parent_size
		cursor.position = event.position - pixel_offset

func show_view(view_name: String):
	# Hide all views
	mail_view.visible = false
	network_view.visible = false
	map_view.visible = false
	settings_view.visible = false
	
	# Show requested view
	match view_name:
		"mail":
			mail_view.visible = true
		"network":
			network_view.visible = true
		"map":
			map_view.visible = true
		"settings":
			settings_view.visible = true

func _on_mail_pressed():
	show_view("mail")

func _on_network_pressed():
	show_view("network")

func _on_map_pressed():
	show_view("map")

func _on_settings_pressed():
	show_view("settings")

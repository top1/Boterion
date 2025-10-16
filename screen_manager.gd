# ScreenManager.gd
extends Control

# Get references to all your screen containers
@onready var main_menu_screen = $MainMenuScreen
@onready var equip_screen = $EquipScreen
@onready var game_screen = $GameScreen

# A dictionary to easily access screens by name
var screens: Dictionary

func _ready():
	# Populate the dictionary
	screens = {
		"main_menu": main_menu_screen,
		"equipment": equip_screen,
		"game": game_screen
	}
	
	# Hide all screens except the one we want to start with
	for screen_name in screens:
		screens[screen_name].hide()
	
	# Show the initial screen
	show_screen("game") # Or "main_menu" if you build one

func show_screen(screen_name: String):
	if not screens.has(screen_name):
		print("Error: Screen '%s' not found." % screen_name)
		return
	
	# Hide all other screens
	for key in screens:
		if key != screen_name:
			screens[key].hide()
	
	# Show the requested screen
	screens[screen_name].show()

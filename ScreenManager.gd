# ScreenManager.gd
extends Control

# Get references to all your screen containers
@onready var main_menu_screen = $MainMenuScreen
@onready var equip_screen = $EquipScreen
@onready var game_screen = $GameScreen
@onready var warning_dialog = %WarningDialog
@onready var reward_screen = %RewardScreen
# A dictionary to easily access screens by name
var screens: Dictionary

func _ready():
	# Populate the dictionary
	screens = {
		"equipment": equip_screen,
		"game": game_screen,
		"reward": reward_screen
	}
	
	# Hide all screens except the one we want to start with
	for screen_name in screens:
		screens[screen_name].hide()
	
	# Show the initial screen
	show_screen("game") # Or "main_menu" if you build one

func show_screen(screen_name: String):
	# --- GENERIC SAFETY CHECK ---
	# Check if the CURRENT screen allows us to leave.
	for screen_key in screens:
		var screen_node = screens[screen_key]
		if screen_node.visible:
			if screen_node.has_method("can_leave_screen"):
				if not screen_node.can_leave_screen():
					# The screen should handle showing its own warning/reason
					if screen_node.has_method("get_leave_warning"):
						warning_dialog.dialog_text = screen_node.get_leave_warning()
						warning_dialog.popup_centered()
					return
	# --- END SAFETY CHECK ---

	if not screens.has(screen_name):
		print("Error: Screen '%s' not found." % screen_name)
		return
	
	# (Der Rest deiner Funktion bleibt exakt gleich)
	# Hide all other screens
	for key in screens:
		if key != screen_name:
			screens[key].hide()
	
	# Show the requested screen
	if screens[screen_name].has_method("show_screen"):
		screens[screen_name].show_screen()
	else:
		screens[screen_name].show()


func _on_equipment_button_pressed() -> void:
	# Tell the parent ScreenManager to show the equipment screen
	get_parent().show_screen("equipment")


func _on_back_pressed() -> void:
	show_screen("main_menu")

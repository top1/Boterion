extends Control

@onready var load_button = %LoadButton

func _ready():
	_update_buttons()

func show_screen():
	show()
	_update_buttons()

func _update_buttons():
	if load_button:
		# Check via SaveManager if it exists (assuming SaveManager is autoloaded)
		if has_node("/root/SaveManager"):
			load_button.disabled = not get_node("/root/SaveManager").has_save_file()
		else:
			load_button.disabled = true # Safety fallback

func _on_new_game_pressed():
	_reset_game_state()
	
	var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
	if screen_manager:
		screen_manager.show_screen("game")

func _on_load_game_pressed():
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").load_game()
		
	var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
	if screen_manager:
		screen_manager.show_screen("game")

func _on_quit_pressed():
	get_tree().quit()

func _reset_game_state():
	RobotState.robot_base_max_energy = 120
	RobotState.robot_base_max_storage = 50
	RobotState.current_energy = 120
	RobotState.current_storage = 0
	RobotState.scrap = 0
	RobotState.electronics = 0
	RobotState.food = 0
	RobotState.base_max_energy = 100
	RobotState.base_energy_current = 100
	RobotState.inventory = []
	RobotState.known_blueprints = []
	RobotState.active_artifacts = []
	RobotState.artifact_inventory = []
	RobotState.map_data = {}
	RobotState.map_seed = randi()
	
	# CRITICAL FIX: Regenerate the map immediately!
	# MapView expects valid data when it shows up.
	RobotState.initialize_map_if_needed()
	
	RobotState.emit_signal("resources_changed")
	RobotState.emit_signal("inventory_changed")
	RobotState.emit_signal("energy_changed", 120)

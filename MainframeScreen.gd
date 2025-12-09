extends Control

@onready var resource_label = %ResourceLabel
@onready var research_button = %ResearchButton
@onready var blueprint_selection = %BlueprintSelection
@onready var back_button = %BackButton

# Placeholder for potential blueprints (in a real scenario, these would be loaded from a folder)
# For now, we will rely on the user creating some, or we can generate dummy ones if needed.
# We'll assume RobotState has a list of "all_possible_blueprints" or we fetch them here.
var all_blueprints: Array[Item] = []

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	research_button.pressed.connect(_on_research_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	
	# Connect option buttons
	for child in blueprint_selection.get_children():
		if child is Button:
			child.pressed.connect(_on_blueprint_selected.bind(child))

	# Load blueprints (Mocking for now, assuming we have some resources)
	_load_all_blueprints()

func show_screen():
	show()
	_update_ui()
	blueprint_selection.hide()
	research_button.show()
	research_button.disabled = false

func _update_ui():
	resource_label.text = "[center]Base Energy: [color=#ffff00]%d[/color] | Scrap: [color=#aaaaaa]%d[/color] | Electronics: [color=#00ffff]%d[/color][/center]" % [RobotState.base_energy_current, RobotState.scrap, RobotState.electronics]
	
	research_button.text = "INITIATE RESEARCH PROTOCOL (Cost: %d Energy)" % RobotState.daily_research_cost
	
	if RobotState.base_energy_current < RobotState.daily_research_cost:
		research_button.disabled = true
		research_button.text += " [INSUFFICIENT ENERGY]"
	else:
		research_button.disabled = false

func _on_research_pressed():
	if RobotState.pay_research_cost():
		_update_ui()
		_show_blueprint_options()
	else:
		# Should not happen if button is disabled, but safety check
		pass

func _show_blueprint_options():
	research_button.hide()
	blueprint_selection.show()
	
	# Pick 3 random blueprints that are NOT known
	var options = []
	var candidates = all_blueprints.duplicate()
	candidates.shuffle()
	
	for item in candidates:
		if not RobotState.known_blueprints.has(item):
			options.append(item)
			if options.size() >= 3:
				break
	
	# If we don't have enough new blueprints, fill with known ones (fallback) or duplicates
	# For this prototype, let's just show what we found.
	
	var buttons = blueprint_selection.get_children()
	for i in range(buttons.size()):
		if i < options.size():
			var item = options[i]
			buttons[i].text = "%s\n\n%s" % [item.item_name, _get_stats_string(item)]
			buttons[i].set_meta("item", item)
			buttons[i].show()
		else:
			buttons[i].hide()

func _get_stats_string(item: Item) -> String:
	var s = ""
	for key in item.stats_modifier:
		s += "+%d %s\n" % [item.stats_modifier[key], key.capitalize()]
	return s

func _on_blueprint_selected(button: Button):
	var item = button.get_meta("item")
	if item:
		RobotState.unlock_blueprint(item)
		# Go back to main view or show success?
		# For now, just reset
		show_screen()

func _on_back_pressed():
	var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
	if screen_manager:
		screen_manager.show_screen("game") # Or main menu if we had one

func _on_save_pressed():
	SaveManager.save_game()
	# Optional: Show visual feedback (we can use the WarningDialog from Main, or just a print for now)
	var warning = get_tree().get_first_node_in_group("WarningDialog") # Assuming Main.tscn puts it in a group or we find it
	if %ResourceLabel:
		var original_text = %ResourceLabel.text
		%ResourceLabel.text = "[center][color=#00ff00]GAME SAVED SUCCESSFULLY![/color][/center]"
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(%ResourceLabel):
			%ResourceLabel.text = original_text

func _load_all_blueprints():
	# Load from "res://items/"
	var dir = DirAccess.open("res://items/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".tres"):
				var item = load("res://items/" + file_name)
				if item is Item and item.blueprint_id != "":
					all_blueprints.append(item)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path 'res://items/'.")

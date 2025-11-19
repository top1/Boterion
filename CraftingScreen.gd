extends Control

@onready var blueprint_list = %BlueprintList
@onready var item_name_label = %ItemNameLabel
@onready var item_stats_label = %ItemStatsLabel
@onready var cost_label = %CostLabel
@onready var craft_button = %CraftButton
@onready var back_button = %BackButton

var selected_blueprint: Item = null

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	craft_button.pressed.connect(_on_craft_pressed)
	_clear_details()

func show_screen():
	show()
	_refresh_list()
	_clear_details()

func _refresh_list():
	# Clear existing items
	for child in blueprint_list.get_children():
		child.queue_free()
	
	# Populate with known blueprints
	for item in RobotState.known_blueprints:
		var btn = Button.new()
		btn.text = item.item_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_blueprint_selected.bind(item))
		blueprint_list.add_child(btn)

func _on_blueprint_selected(item: Item):
	selected_blueprint = item
	_update_details()

func _update_details():
	if not selected_blueprint:
		_clear_details()
		return
		
	item_name_label.text = "[b][color=#ffaa00]%s[/color][/b]" % selected_blueprint.item_name
	
	# Stats
	var stats = "Type: %s\n" % selected_blueprint.item_type
	for key in selected_blueprint.stats_modifier:
		stats += "+%d %s\n" % [selected_blueprint.stats_modifier[key], key.capitalize()]
	item_stats_label.text = stats
	
	# Cost
	var recipe = selected_blueprint.crafting_recipe
	var cost_text = "Fabrication Cost:\n"
	
	var can_afford = RobotState.can_craft(selected_blueprint)
	
	var scrap_color = "#00ff00" if RobotState.scrap >= recipe.get("scrap", 0) else "#ff0000"
	var elec_color = "#00ff00" if RobotState.electronics >= recipe.get("electronics", 0) else "#ff0000"
	var energy_color = "#00ff00" if RobotState.base_energy_current >= recipe.get("energy", 0) else "#ff0000"
	
	cost_text += "[color=%s]%d / %d Scrap[/color]\n" % [scrap_color, RobotState.scrap, recipe.get("scrap", 0)]
	cost_text += "[color=%s]%d / %d Electronics[/color]\n" % [elec_color, RobotState.electronics, recipe.get("electronics", 0)]
	cost_text += "[color=%s]%d / %d Base Energy[/color]" % [energy_color, RobotState.base_energy_current, recipe.get("energy", 0)]
	
	cost_label.text = cost_text
	
	craft_button.disabled = not can_afford

func _clear_details():
	selected_blueprint = null
	item_name_label.text = "Select a Blueprint"
	item_stats_label.text = ""
	cost_label.text = ""
	craft_button.disabled = true

func _on_craft_pressed():
	if selected_blueprint:
		RobotState.craft_item(selected_blueprint)
		_update_details() # Refresh colors/button state

func _on_back_pressed():
	var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
	if screen_manager:
		screen_manager.show_screen("game")

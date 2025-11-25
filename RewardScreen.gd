# RewardScreen.gd
extends Control

# UI References
@onready var scrap_count_label = %ScrapCount
@onready var elec_count_label = %ElecCount
@onready var food_count_label = %FoodCount
@onready var continue_button = %ContinueButton

# Blueprint Stage References
@onready var blueprint_stage = %BlueprintStage
@onready var blueprint_label = %BlueprintLabel
@onready var mystery_box = %MysteryBox
@onready var revealed_item_icon = %RevealedItemIcon
@onready var revealed_item_name = %RevealedItemName

var _current_loot: Dictionary = {}
var _found_blueprints: Array = []

func _ready():
	# FIX: Force full screen layout to prevent offset issues
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.visible = false
	blueprint_stage.visible = false

func show_rewards(collected_loot: Dictionary):
	_current_loot = collected_loot
	_found_blueprints.clear()
	
	# Extract blueprints from loot if they are passed as special objects or separate list
	# For now, let's assume blueprints might be mixed in or we handle them separately.
	# If the loot dict contains "blueprints" key with an array:
	if collected_loot.has("blueprints"):
		_found_blueprints = collected_loot["blueprints"]
	
	# Reset UI
	scrap_count_label.text = "0"
	elec_count_label.text = "0"
	food_count_label.text = "0"
	continue_button.visible = false
	blueprint_stage.visible = false
	
	# Start Animations
	_tween_resources()

func _tween_resources():
	var scrap = _current_loot.get("scrap_metal", 0)
	var elec = _current_loot.get("electronics", 0)
	var food = _current_loot.get("food", 0)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	# Animate numbers
	tween.tween_method(func(val): scrap_count_label.text = str(val), 0, scrap, 1.5)
	tween.tween_method(func(val): elec_count_label.text = str(val), 0, elec, 1.5)
	tween.tween_method(func(val): food_count_label.text = str(val), 0, food, 1.5)
	
	# Chain next step
	tween.chain().tween_callback(_on_resources_finished)

func _on_resources_finished():
	if not _found_blueprints.is_empty():
		_start_blueprint_reveal()
	else:
		_show_continue()

func _start_blueprint_reveal():
	blueprint_stage.visible = true
	blueprint_label.text = "ANOMALOUS SIGNAL DETECTED..."
	mystery_box.visible = true
	mystery_box.scale = Vector2.ONE
	mystery_box.rotation = 0
	revealed_item_icon.visible = false
	revealed_item_name.visible = false
	
	# Pulse animation for mystery box
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(mystery_box, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mystery_box, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	
	# Allow user to click to open
	mystery_box.gui_input.connect(_on_mystery_box_clicked)
	# Make sure it can receive input
	mystery_box.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_mystery_box_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Disconnect to prevent double clicks
		if mystery_box.gui_input.is_connected(_on_mystery_box_clicked):
			mystery_box.gui_input.disconnect(_on_mystery_box_clicked)
		
		_reveal_next_blueprint()

func _reveal_next_blueprint():
	# Stop the pulse tween (we need to store it if we want to kill it cleanly, or just overwrite)
	# Simple shake animation
	var tween = create_tween()
	for i in range(10):
		var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		tween.tween_property(mystery_box, "position", mystery_box.position + offset, 0.05)
		tween.tween_property(mystery_box, "position", mystery_box.position - offset, 0.05)
	
	tween.tween_callback(_show_blueprint_content)

func _show_blueprint_content():
	var item = _found_blueprints.pop_front()
	
	mystery_box.visible = false
	revealed_item_icon.texture = item.item_texture
	revealed_item_icon.visible = true
	revealed_item_icon.scale = Vector2(0.1, 0.1)
	
	revealed_item_name.text = item.item_name
	revealed_item_name.visible = true
	revealed_item_name.modulate.a = 0
	
	blueprint_label.text = "BLUEPRINT DECODED"
	
	# Rarity Color (Simple mapping for now)
	var color = Color.WHITE
	match item.rarity:
		"RARE": color = Color.CYAN
		"EPIC": color = Color.PURPLE
		"LEGENDARY": color = Color.GOLD
	
	revealed_item_name.modulate = color
	revealed_item_name.modulate.a = 0 # Reset alpha for fade in
	
	# --- PARTICLES ---
	var particles = preload("res://RewardParticles.tscn").instantiate()
	particles.position = revealed_item_icon.position + revealed_item_icon.size / 2
	# Adjust color based on rarity
	if item.rarity == "RARE": particles.modulate = Color.CYAN
	elif item.rarity == "EPIC": particles.modulate = Color.PURPLE
	elif item.rarity == "LEGENDARY": particles.modulate = Color.GOLD
	else: particles.modulate = Color.WHITE
	
	blueprint_stage.add_child(particles)
	particles.emitting = true
	# -----------------
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(revealed_item_icon, "scale", Vector2(1.5, 1.5), 0.5)
	tween.tween_property(revealed_item_name, "modulate:a", 1.0, 0.5)
	
	tween.chain().tween_interval(1.0)
	tween.chain().tween_callback(_check_more_blueprints)

func _check_more_blueprints():
	if not _found_blueprints.is_empty():
		# Reset for next one
		_start_blueprint_reveal()
	else:
		_show_continue()

func _show_continue():
	continue_button.visible = true
	continue_button.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(continue_button, "modulate:a", 1.0, 0.5)

func _on_continue_pressed():
	# Add resources to RobotState
	RobotState.add_resources(_current_loot)
	
	# Calculate total items for stats (optional, but good for tracking)
	var _total_items = 0
	for key in _current_loot:
		var val = _current_loot[key]
		if val is int or val is float:
			_total_items += int(val)
		elif val is Array:
			_total_items += val.size()
			
	# Start new day and return to game
	RobotState.start_new_day()
	get_tree().get_first_node_in_group("ScreenManager").show_screen("game")

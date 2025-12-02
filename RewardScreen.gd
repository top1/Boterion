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
var _found_artifacts: Array = [] # New
var _scanned_rooms: Array = []

var scanned_rooms_container: HBoxContainer
var scanned_rooms_label: Label

const ROOM_TEXTURES = {
	RoomData.RoomType.STANDARD: preload("res://graphics/rooms/living_s.png"),
	RoomData.RoomType.TEC: preload("res://graphics/rooms/tec_s.png"),
	RoomData.RoomType.HABITAT: preload("res://graphics/rooms/habitat_s.png"),
}

func _ready():
	# FIX: Force full screen layout to prevent offset issues
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.visible = false
	blueprint_stage.visible = false
	
	_setup_scanned_rooms_ui()

func _setup_scanned_rooms_ui():
	# Find the main content container
	var content_vbox = $CenterWrapper/ContentVBox
	var resources_container = %ResourcesContainer
	
	# Create a container for our section
	var section_vbox = VBoxContainer.new()
	section_vbox.name = "ScannedRoomsSection"
	section_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	section_vbox.add_theme_constant_override("separation", 10)
	
	# Insert it AFTER the resources container
	# We get the index of resources_container and add 1
	var idx = resources_container.get_index()
	content_vbox.add_child(section_vbox)
	content_vbox.move_child(section_vbox, idx + 1)
	
	scanned_rooms_label = Label.new()
	scanned_rooms_label.text = "NEW ROOMS MAPPED"
	scanned_rooms_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scanned_rooms_label.add_theme_font_size_override("font_size", 20) # Slightly smaller
	scanned_rooms_label.modulate = Color(0, 1, 0) # Green
	scanned_rooms_label.visible = false
	section_vbox.add_child(scanned_rooms_label)
	
	scanned_rooms_container = HBoxContainer.new()
	scanned_rooms_container.alignment = BoxContainer.ALIGNMENT_CENTER
	scanned_rooms_container.add_theme_constant_override("separation", 10) # Tighter spacing
	section_vbox.add_child(scanned_rooms_container)

func show_rewards(collected_loot: Dictionary):
	_current_loot = collected_loot
	_found_blueprints.clear()
	
	# Extract blueprints from loot if they are passed as special objects or separate list
	# For now, let's assume blueprints might be mixed in or we handle them separately.
	# If the loot dict contains "blueprints" key with an array:
	if collected_loot.has("blueprints"):
		_found_blueprints = collected_loot["blueprints"]
		
	if collected_loot.has("scanned_rooms"):
		_scanned_rooms = collected_loot["scanned_rooms"]
	else:
		_scanned_rooms = []
		
	if collected_loot.has("artifacts"):
		_found_artifacts = collected_loot["artifacts"]
	else:
		_found_artifacts = []
	
	# Clear old scanned rooms
	if scanned_rooms_container:
		for child in scanned_rooms_container.get_children():
			child.queue_free()
	if scanned_rooms_label:
		scanned_rooms_label.visible = false
	
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
	# Animate numbers
	tween.tween_method(func(val):
		scrap_count_label.text = str(val)
		_play_tick_sound()
	, 0, scrap, 1.5)
	
	tween.tween_method(func(val):
		elec_count_label.text = str(val)
		# _play_tick_sound() # Optional: Don't overlap too much
	, 0, elec, 1.5)
	
	tween.tween_method(func(val):
		food_count_label.text = str(val)
	, 0, food, 1.5)
	
	# Chain next step
	tween.chain().tween_callback(_show_scanned_rooms)

func _show_scanned_rooms():
	if _scanned_rooms.is_empty():
		_on_resources_finished()
		return
		
	scanned_rooms_label.visible = true
	scanned_rooms_label.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(scanned_rooms_label, "modulate:a", 1.0, 0.5)
	
	for room in _scanned_rooms:
		tween.tween_callback(func(): _add_scanned_room_icon(room))
		tween.tween_interval(0.3)
		
	tween.chain().tween_interval(1.0)
	tween.chain().tween_callback(_on_resources_finished)

func _add_scanned_room_icon(room):
	var tex_rect = TextureRect.new()
	tex_rect.texture = ROOM_TEXTURES.get(room.type, ROOM_TEXTURES[RoomData.RoomType.STANDARD])
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.custom_minimum_size = Vector2(48, 48) # Smaller size
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.pivot_offset = Vector2(24, 24)
	tex_rect.scale = Vector2.ZERO # Start small
	
	# --- TOOLTIP ---
	var type_str = "Unknown"
	match room.type:
		RoomData.RoomType.STANDARD: type_str = "Standard Room"
		RoomData.RoomType.TEC: type_str = "Tech Room"
		RoomData.RoomType.HABITAT: type_str = "Habitat"
		RoomData.RoomType.FACTORY: type_str = "ANCIENT FACTORY"
	
	var tooltip = "%s (ID: %s)\n" % [type_str, room.room_id]
	tooltip += "Distance: %d\n" % room.distance
	tooltip += "Loot Potential:\n"
	tooltip += "  Electronics: %d\n" % room.loot_pool["electronics"]["current"]
	tooltip += "  Scrap: %d\n" % room.loot_pool["scrap_metal"]["current"]
	tooltip += "  Food: %d\n" % room.loot_pool["food"]["current"]
	tooltip += "  Blueprints: %d" % room.loot_pool["blueprints"]["current"]
	
	tex_rect.tooltip_text = tooltip
	# ---------------
	
	scanned_rooms_container.add_child(tex_rect)
	
	# --- FACTORY HIGHLIGHT ---
	if room.type == RoomData.RoomType.FACTORY:
		var border = ReferenceRect.new()
		border.editor_only = false
		border.border_color = Color(1, 0.8, 0.2) # Gold
		border.border_width = 2.0
		border.set_anchors_preset(Control.PRESET_FULL_RECT)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.add_child(border)
		
		# Optional: Pulse effect for factory
		var pulse = create_tween()
		pulse.set_loops()
		pulse.tween_property(tex_rect, "modulate", Color(1.2, 1.2, 1.2), 0.5)
		pulse.tween_property(tex_rect, "modulate", Color(1, 1, 1), 0.5)
	# -------------------------
	
	# Pop animation
	var t = create_tween()
	t.tween_property(tex_rect, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(tex_rect, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Play sound if available
	_play_tick_sound()

func _on_resources_finished():
	if not _found_blueprints.is_empty():
		_start_blueprint_reveal()
	elif not _found_artifacts.is_empty():
		_start_artifact_reveal()
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
	
	# --- SOUNDS ---
	if %RevealPlayer.stream:
		%RevealPlayer.play()
	# --------------
	
	# --- FLASH EFFECT ---
	var flash = %FlashOverlay
	flash.visible = true
	flash.modulate.a = 1.0
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.5)
	flash_tween.tween_callback(func(): flash.visible = false)
	# --------------------
	
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
	elif not _found_artifacts.is_empty():
		_start_artifact_reveal()
	else:
		_show_continue()

func _show_continue():
	continue_button.visible = true
	continue_button.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(continue_button, "modulate:a", 1.0, 0.5)

func _on_continue_pressed():
	# Add resources to RobotState
	print("DEBUG: RewardScreen calling add_resources with: ", _current_loot)
	RobotState.add_resources(_current_loot)
	
	# Add Artifacts
	if _current_loot.has("artifacts"):
		for art in _current_loot["artifacts"]:
			RobotState.add_artifact(art)
	
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

func _play_tick_sound():
	# Simple limiter to prevent audio spam
	if %ResourceTickPlayer.stream and not %ResourceTickPlayer.playing:
		%ResourceTickPlayer.play()

# --- ARTIFACT REVEAL LOGIC ---

func _start_artifact_reveal():
	blueprint_stage.visible = true
	blueprint_label.text = "ANCIENT ARTIFACT DETECTED!"
	blueprint_label.modulate = Color(1, 0.8, 0.2) # Gold
	
	mystery_box.visible = true
	mystery_box.scale = Vector2.ONE
	mystery_box.rotation = 0
	# Use a different texture or color for artifact box if possible?
	mystery_box.modulate = Color(1, 0.8, 0.2) # Tint it Gold
	
	revealed_item_icon.visible = false
	revealed_item_name.visible = false
	
	# Pulse animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(mystery_box, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mystery_box, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_SINE)
	
	# Connect input
	if mystery_box.gui_input.is_connected(_on_mystery_box_clicked):
		mystery_box.gui_input.disconnect(_on_mystery_box_clicked)
	mystery_box.gui_input.connect(_on_artifact_box_clicked)
	mystery_box.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_artifact_box_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mystery_box.gui_input.is_connected(_on_artifact_box_clicked):
			mystery_box.gui_input.disconnect(_on_artifact_box_clicked)
		_reveal_next_artifact()

func _reveal_next_artifact():
	# Shake harder for artifact
	var tween = create_tween()
	for i in range(15):
		var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
		tween.tween_property(mystery_box, "position", mystery_box.position + offset, 0.04)
		tween.tween_property(mystery_box, "position", mystery_box.position - offset, 0.04)
	
	tween.tween_callback(_show_artifact_content)

func _show_artifact_content():
	var artifact = _found_artifacts.pop_front()
	
	mystery_box.visible = false
	mystery_box.modulate = Color.WHITE # Reset tint
	
	# revealed_item_icon.texture = artifact.icon # TODO
	revealed_item_icon.visible = true
	revealed_item_icon.scale = Vector2(0.1, 0.1)
	revealed_item_icon.modulate = Color(1, 0.8, 0.2) # Gold placeholder
	
	revealed_item_name.text = artifact.name
	revealed_item_name.visible = true
	revealed_item_name.modulate = Color(1, 0.8, 0.2)
	revealed_item_name.modulate.a = 0
	
	blueprint_label.text = "ARTIFACT ACQUIRED"
	
	# Add description label dynamically if needed, or just show name
	
	# --- FLASH EFFECT ---
	var flash = %FlashOverlay
	flash.visible = true
	flash.modulate = Color(1, 0.9, 0.5, 1.0) # Gold flash
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.8)
	flash_tween.tween_callback(func(): flash.visible = false)
	
	# --- PARTICLES ---
	var particles = preload("res://RewardParticles.tscn").instantiate()
	particles.position = revealed_item_icon.position + revealed_item_icon.size / 2
	particles.modulate = Color(1, 0.8, 0.2) # Gold
	blueprint_stage.add_child(particles)
	particles.emitting = true
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(revealed_item_icon, "scale", Vector2(1.5, 1.5), 0.8)
	tween.tween_property(revealed_item_name, "modulate:a", 1.0, 0.5)
	
	tween.chain().tween_interval(1.5)
	tween.chain().tween_callback(_check_more_artifacts)

func _check_more_artifacts():
	if not _found_artifacts.is_empty():
		_start_artifact_reveal()
	else:
		_show_continue()

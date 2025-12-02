# RobotEquipScreen.gd
extends Control
class_name RobotEquipScreen

signal equipment_changed

# --- UI-Referenzen ---
# (Deine bisherigen Referenzen)
@onready var confirm_button = %ConfirmButton
@onready var inventory_grid = $MainLayout/InventoryPanel/ItemGrid

# NEU: Referenzen für die Auflade-Sektion
@onready var base_energy_label = %BaseEnergyLabel
@onready var robot_energy_label = %RobotEnergyLabel
@onready var charge_slider = %ChargeSlider
@onready var charge_info_label = %ChargeInfoLabel

# Equipment slots reference
@onready var equipment_slots: Array = [
	$"MainLayout/RobotPanel/HeadSlot",
	$"MainLayout/RobotPanel/LeftArm",
	$"MainLayout/RobotPanel/RightArm",
	$"MainLayout/RobotPanel/BodySlot",
	$"MainLayout/RobotPanel/BodySlot2",
	$"MainLayout/RobotPanel/BodySlot3",
	$"MainLayout/RobotPanel/BodySlot4"
]

# --- Logik ---

var _is_initializing: bool = false

func show_screen():
	show()
	print("--- ROBOT EQUIP SCREEN OPENED ---")
	
	# Flag to prevent "free energy" logic during initialization
	_is_initializing = true
	
	# Wait for a frame to ensure all slots are initialized and ready
	await get_tree().process_frame
	
	# FAILSAFE: If Max Energy is still at base (100) but we have items, 
	# it means _ready() didn't catch them (e.g. added later). Force update.
	# We check if we have ANY equipped item.
	var has_equipment = false
	for slot in equipment_slots:
		if slot.current_equipped_item:
			has_equipment = true
			break
			
	if has_equipment and RobotState.MAX_ENERGY == RobotState.robot_base_max_energy:
		print("--- DEBUG: Failsafe triggered! Recalculating bonuses... ---")
		var bonuses = _calculate_equipment_bonuses()
		RobotState.update_equipment_bonuses(bonuses.energy, bonuses.storage)
	
	# Done initializing
	_is_initializing = false
	
	# FIX: Ensure we update stats to set initial slider state correctly
	update_robot_stats()
	
	# _update_charge_info() # Removed
	_update_inventory_list()
	_update_artifact_display() # FORCE UPDATE ON SHOW
	
	# Trigger the requested animation
	# _animate_slider_initialization() # Removed

func _calculate_equipment_bonuses() -> Dictionary:
	var bonus_energy = 0
	var bonus_storage = 0
	
	print("--- DEBUG: Calculating Equipment Bonuses ---")
	for slot in equipment_slots:
		if slot.current_equipped_item:
			print("Slot %s has item: %s" % [slot.name, slot.current_equipped_item.item_name])
			var modifiers = slot.current_equipped_item.stats_modifier
			
			# Check for "energy" OR "max_energy"
			if modifiers.has("energy"):
				bonus_energy += modifiers["energy"]
			elif modifiers.has("max_energy"):
				bonus_energy += modifiers["max_energy"]
				
			# Check for "storage" OR "max_storage"
			if modifiers.has("storage"):
				bonus_storage += modifiers["storage"]
			elif modifiers.has("max_storage"):
				bonus_storage += modifiers["max_storage"]
	
	print("Total Bonuses: Energy=%d, Storage=%d" % [bonus_energy, bonus_storage])
	return {
		"energy": bonus_energy,
		"storage": bonus_storage
	}

func _on_confirm_button_pressed():
	# Only update bonuses and close screen
	var bonuses = _calculate_equipment_bonuses()
	RobotState.update_equipment_bonuses(bonuses.energy, bonuses.storage)
	
	var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
	if screen_manager:
		screen_manager.show_screen("game")

func _ready():
	# HIDE OLD RECHARGE UI
	if charge_slider: charge_slider.visible = false
	if charge_info_label: charge_info_label.visible = false
	if base_energy_label: base_energy_label.visible = false
	
	# RESTORE ROBOT STATS LABEL
	if robot_energy_label:
		robot_energy_label.visible = true
	
	# charge_slider.value_changed.connect(_on_charge_slider_changed) # Removed
	
	# Use the class property equipment_slots instead of creating a new array
	for slot in equipment_slots:
		slot.item_equipped.connect(_on_equipment_changed)
		slot.item_unequipped.connect(_on_equipment_changed)
	
	# Calculate initial equipment bonuses
	_on_equipment_changed()
	
	# Connect to inventory changes so the grid updates when we add debug items
	RobotState.inventory_changed.connect(_update_inventory_list)
	
	# Connect to artifacts changed
	if not RobotState.artifacts_changed.is_connected(_update_artifact_display):
		RobotState.artifacts_changed.connect(_update_artifact_display)
	
	_setup_artifact_display()
	update_robot_stats()
	_update_inventory_list()

func _setup_artifact_display():
	# 1. ACTIVE SLOTS (Top Right of RobotPanel)
	var robot_panel = $MainLayout/RobotPanel
	if not robot_panel: return
	
	# Remove old container if it exists on root
	if has_node("ArtifactContainer"):
		get_node("ArtifactContainer").queue_free()
		
	if not robot_panel.has_node("ActiveArtifacts"):
		var active_container = VBoxContainer.new()
		active_container.name = "ActiveArtifacts"
		# Anchor to Top Right
		active_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		active_container.position = Vector2(robot_panel.size.x - 70, 10)
		active_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		robot_panel.add_child(active_container)
		
		var label = Label.new()
		label.text = "EQUIPPED"
		label.add_theme_font_size_override("font_size", 10)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		active_container.add_child(label)
		
		for i in range(RobotState.MAX_ARTIFACT_SLOTS):
			var slot = PanelContainer.new()
			slot.name = "Slot_%d" % i
			slot.custom_minimum_size = Vector2(50, 50)
			
			# Attach Script
			slot.set_script(load("res://ArtifactSlot.gd"))
			slot.slot_index = i
			slot.is_storage = false
			
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
			style.border_width_left = 1; style.border_width_top = 1; style.border_width_right = 1; style.border_width_bottom = 1
			style.border_color = Color(0.5, 0.5, 0.5)
			slot.add_theme_stylebox_override("panel", style)
			
			var icon = TextureRect.new()
			icon.name = "Icon"
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(40, 40)
			icon.modulate = Color(1, 1, 1, 0.5)
			
			slot.add_child(icon)
			active_container.add_child(slot)

	# 2. ARTIFACT STORAGE (Right Side of RobotPanel, below Active Slots)
	
	# Clean up old locations
	var main_layout = $MainLayout
	if main_layout.has_node("ArtifactPanel"):
		main_layout.get_node("ArtifactPanel").queue_free()
	var inventory_panel = $MainLayout/InventoryPanel
	if inventory_panel.has_node("ArtifactStorage"):
		inventory_panel.get_node("ArtifactStorage").queue_free()
		
	if not robot_panel.has_node("ArtifactStorage"):
		var storage_container = VBoxContainer.new()
		storage_container.name = "ArtifactStorage"
		
		# Anchor to Right Side, below Active Slots
		# Let's use anchors relative to parent size
		storage_container.layout_mode = 1 # Anchors
		storage_container.anchors_preset = -1 # Custom
		storage_container.anchor_left = 0.85 # Start at 85% width
		storage_container.anchor_right = 0.98 # End at 98% width
		storage_container.anchor_top = 0.5 # Start at middle height
		storage_container.anchor_bottom = 0.95 # End near bottom
		storage_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		
		robot_panel.add_child(storage_container)
		
		var label = Label.new()
		label.text = "STORAGE"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		label.add_theme_font_size_override("font_size", 10)
		storage_container.add_child(label)
		
		var scroll = ScrollContainer.new()
		scroll.name = "ScrollContainer" # IMPORTANT: Set name for get_node path
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.custom_minimum_size = Vector2(100, 100) # Force width and height
		
		storage_container.add_child(scroll)
		
		var grid = GridContainer.new()
		grid.name = "StorageGrid"
		grid.columns = 1 # Vertical stack to fit in the side column
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.custom_minimum_size = Vector2(50, 50) # Force size
		scroll.add_child(grid)
		
	_update_artifact_display()

func _update_artifact_display():
	# Update Active Slots
	var robot_panel = $MainLayout/RobotPanel
	var active_container = robot_panel.get_node_or_null("ActiveArtifacts")
	if active_container:
		var active_artifacts = RobotState.active_artifacts
		for i in range(RobotState.MAX_ARTIFACT_SLOTS):
			var slot = active_container.get_node_or_null("Slot_%d" % i)
			if slot:
				if i < active_artifacts.size():
					slot.set_artifact(active_artifacts[i])
				else:
					slot.set_artifact(null)
					
	# Update Storage
	# Path: RobotPanel -> ArtifactStorage -> ScrollContainer -> StorageGrid
	var storage_container = robot_panel.get_node_or_null("ArtifactStorage")
	if not storage_container:
		print("DEBUG: ArtifactStorage container not found!")
		return
	
	var storage_grid = storage_container.get_node_or_null("ScrollContainer/StorageGrid")
	
	if storage_grid:
		# Clear old
		for child in storage_grid.get_children():
			child.queue_free()
			
		print("DEBUG: Artifact Inventory Size: %d" % RobotState.artifact_inventory.size())
		
		# Add new
		for art in RobotState.artifact_inventory:
			var slot = PanelContainer.new()
			slot.custom_minimum_size = Vector2(50, 50)
			
			# Attach Script
			slot.set_script(load("res://ArtifactSlot.gd"))
			slot.is_storage = true
			slot.set_artifact(art) # Set immediately
			
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
			style.border_width_left = 1; style.border_width_top = 1; style.border_width_right = 1; style.border_width_bottom = 1
			style.border_color = Color(0.5, 0.5, 0.5)
			slot.add_theme_stylebox_override("panel", style)
			
			var icon = TextureRect.new()
			icon.name = "Icon"
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(40, 40)
			
			slot.add_child(icon)
			storage_grid.add_child(slot)
			
			# Force update display again to ensure icon is set (though set_artifact does it)
			slot.update_display()
			
	else:
		print("DEBUG: StorageGrid not found! Path: ArtifactStorage/ScrollContainer/StorageGrid")

func _update_inventory_list():
	# Clear existing children
	for child in inventory_grid.get_children():
		child.queue_free()
	
	# Populate with current inventory
	for item in RobotState.inventory:
		var slot = PanelContainer.new()
		slot.custom_minimum_size = Vector2(80, 80)
		
		var btn = Button.new()
		# ATTACH THE SCRIPT!
		btn.set_script(load("res://Inventory_slot.gd"))
		# Set the item property, which triggers update_display()
		btn.item = item
		
		# FIX: Use icon if available, otherwise full name with wrap
		if not item.item_texture:
			# Only set text if no icon (Inventory_slot handles icon now)
			var short_name = item.item_name.split("(")[0].strip_edges()
			btn.text = short_name
			btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			btn.clip_text = true
			
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.pressed.connect(_on_inventory_item_pressed.bind(item))
		
		slot.add_child(btn)
		inventory_grid.add_child(slot)

func _on_inventory_item_pressed(item):
	# Try to find a compatible slot
	for slot in equipment_slots:
		# Safety check if slot has the method (in case script is still missing on node)
		if slot.has_method("can_accept_item") and slot.can_accept_item(item):
			# If slot is empty, just equip
			if slot.current_equipped_item == null:
				slot.equip_item(item)
				RobotState.inventory.erase(item)
				_update_inventory_list()
				return
			# If slot is full, maybe swap? For now, just skip to next empty or compatible
			
	# Second pass: Swap with first compatible slot if no empty ones found
	for slot in equipment_slots:
		if slot.has_method("can_accept_item") and slot.can_accept_item(item):
			var old_item = slot.current_equipped_item
			slot.equip_item(item)
			RobotState.inventory.erase(item)
			if old_item:
				RobotState.inventory.append(old_item)
			_update_inventory_list()
			return

func _on_equipment_changed(_item = null):
	# Capture old max energy before recalculating
	var old_max_energy = RobotState.MAX_ENERGY
	
	var bonuses = _calculate_equipment_bonuses()
	RobotState.update_equipment_bonuses(bonuses.energy, bonuses.storage)
	
	# Calculate the difference (new capacity added)
	var diff = RobotState.MAX_ENERGY - old_max_energy
	
	# If we gained capacity (e.g. equipped a battery), add that charge instantly!
	# BUT NOT IF INITIALIZING (prevents free energy exploit on screen open)
	if diff > 0 and not _is_initializing:
		RobotState.current_energy += diff
		# Clamp just in case, though logic implies it's safe
		RobotState.current_energy = min(RobotState.current_energy, RobotState.MAX_ENERGY)
	
	update_robot_stats()

func update_robot_stats():
	# Update the main label
	if robot_energy_label:
		var text = "ROBOT STATS:\n"
		text += "Energy: %d / %d\n" % [RobotState.current_energy, RobotState.MAX_ENERGY]
		text += "Storage: %d / %d\n" % [RobotState.current_storage, RobotState.MAX_STORAGE]
		
		# Add Artifact Bonuses info
		var move_bonus = RobotState.get_artifact_bonus(RobotState.Artifact.EffectType.REDUCE_MOVE_COST)
		if move_bonus > 0:
			text += "Move Cost: -%d%%\n" % (move_bonus * 100)
			
		var scan_bonus = RobotState.get_artifact_bonus(RobotState.Artifact.EffectType.REDUCE_SCAN_COST)
		if scan_bonus > 0:
			text += "Scan Cost: -%d%%\n" % (scan_bonus * 100)
			
		robot_energy_label.text = text

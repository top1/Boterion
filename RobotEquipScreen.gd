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

func show_screen():
	show()
	# Update slider with new max from equipment
	var bonuses = _calculate_equipment_bonuses()
	RobotState.update_equipment_bonuses(bonuses.energy, bonuses.storage)
	
	# Update slider range
	charge_slider.max_value = RobotState.MAX_ENERGY
	# FIX: Prevent discharging!
	charge_slider.min_value = RobotState.current_energy
	charge_slider.value = RobotState.current_energy
	
	# Disable if already full
	charge_slider.editable = RobotState.current_energy < RobotState.MAX_ENERGY
	
	update_robot_stats()
	_update_charge_info()
	_update_inventory_list()

func _update_charge_info():
	var target_energy = int(charge_slider.value)
	var energy_needed = target_energy - RobotState.current_energy
	energy_needed = max(0, energy_needed)
	
	charge_info_label.text = "Charge Cost: %d Base Energy" % energy_needed
	
	# Update the Robot Energy label to show the projection
	robot_energy_label.text = "Robot Energy: %d -> %d / %d" % [RobotState.current_energy, target_energy, RobotState.MAX_ENERGY]


func _on_charge_slider_changed(new_value: float):
	# Clamp the slider to what is actually affordable/achievable
	var max_achievable = RobotState.current_energy + RobotState.base_energy_current
	
	# FIX: Strict lower bound check
	if new_value < RobotState.current_energy:
		charge_slider.value = RobotState.current_energy
		return
	
	if new_value > max_achievable:
		# Snap back if user tries to drag past limit
		charge_slider.value = max_achievable
		# The setter will trigger this signal again, so we return to avoid double update
		return

	_update_charge_info()


func _calculate_equipment_bonuses() -> Dictionary:
	var bonus_energy = 0
	var bonus_storage = 0
	
	for slot in equipment_slots:
		if slot.current_equipped_item:
			var modifiers = slot.current_equipped_item.stats_modifier
			if modifiers.has("energy"):
				bonus_energy += modifiers["energy"]
			if modifiers.has("storage"):
				bonus_storage += modifiers["storage"]
	
	return {
		"energy": bonus_energy,
		"storage": bonus_storage
	}


func _on_confirm_button_pressed():
	var bonuses = _calculate_equipment_bonuses()
	RobotState.update_equipment_bonuses(bonuses.energy, bonuses.storage)
	
	var energy_to_charge = int(charge_slider.value) - RobotState.current_energy
	if energy_to_charge > 0:
		RobotState.charge_robot_from_base(energy_to_charge)
	
	var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
	if screen_manager:
		screen_manager.show_screen("game")

func _ready():
	charge_slider.value_changed.connect(_on_charge_slider_changed)
	
	# Use the class property equipment_slots instead of creating a new array
	for slot in equipment_slots:
		slot.item_equipped.connect(_on_equipment_changed)
		slot.item_unequipped.connect(_on_equipment_changed)
	
	# Calculate initial equipment bonuses
	_on_equipment_changed()
	
	# NOW that equipment is loaded and bonuses applied, ensure we start full!
	RobotState.ensure_initial_full_charge()
	
	# Connect to inventory changes so the grid updates when we add debug items
	RobotState.inventory_changed.connect(_update_inventory_list)
	
	update_robot_stats()
	_update_inventory_list()

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
			
		# var desc = item.description if "description" in item else "" # Handled by script now
		# btn.tooltip_text = item.item_name + "\n" + desc
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
			# Ideally we'd swap, but let's keep it simple: only equip to empty slots first
			
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
	if diff > 0:
		RobotState.current_energy += diff
		# Clamp just in case, though logic implies it's safe
		RobotState.current_energy = min(RobotState.current_energy, RobotState.MAX_ENERGY)
	
	# When equipment changes, update slider range but keep current value
	charge_slider.max_value = RobotState.MAX_ENERGY
	# FIX: Update min value too
	charge_slider.min_value = RobotState.current_energy
	charge_slider.value = max(charge_slider.value, RobotState.current_energy)
	
	charge_slider.editable = RobotState.current_energy < RobotState.MAX_ENERGY
	
	update_robot_stats()

func update_robot_stats():
	# 1. Update der Stat-Labels (die neue Übersicht)
	# Use colors to distinguish (using modulate since these are standard Labels)
	base_energy_label.text = "BASE ENERGY (HOME): %d / %d" % [RobotState.base_energy_current, RobotState.base_max_energy]
	base_energy_label.modulate = Color(0, 1, 1) # Cyan
	
	# Sync slider max
	charge_slider.max_value = RobotState.MAX_ENERGY
	
	# FIX: Always sync min_value and editable state here to catch all updates (including _ready)
	charge_slider.min_value = RobotState.current_energy
	charge_slider.editable = RobotState.current_energy < RobotState.MAX_ENERGY
	
	# If the slider is not being dragged (or we just opened the screen), sync its value too?
	# For now, let's just update the text. The slider value is handled in show_screen and _on_equipment_changed.
	robot_energy_label.text = "ROBOT BATTERY (RUN): %d / %d" % [RobotState.current_energy, RobotState.MAX_ENERGY]
	robot_energy_label.modulate = Color(0, 1, 0) # Green

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
	if robot_energy_label: robot_energy_label.visible = false
	
	# charge_slider.value_changed.connect(_on_charge_slider_changed) # Removed
	
	# Use the class property equipment_slots instead of creating a new array
	for slot in equipment_slots:
		slot.item_equipped.connect(_on_equipment_changed)
		slot.item_unequipped.connect(_on_equipment_changed)
	
	# Calculate initial equipment bonuses
	_on_equipment_changed()
	
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
	# Just update labels if needed, or leave empty if we removed the labels
	# robot_energy_label.text = "ROBOT BATTERY: %d / %d" % [RobotState.current_energy, RobotState.MAX_ENERGY]
	pass

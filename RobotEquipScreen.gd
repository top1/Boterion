# RobotEquipScreen.gd
extends Control
class_name RobotEquipScreen

signal equipment_changed

# --- UI-Referenzen ---
# (Deine bisherigen Referenzen)
@onready var confirm_button = %ConfirmButton
@onready var battery_item_grid = %BatteryItemGrid # Annahme, du hast so etwas

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
	charge_slider.value = RobotState.current_energy
	
	update_robot_stats()
	_update_charge_info()

func _update_charge_info():
	var target_energy = int(charge_slider.value)
	var energy_needed = target_energy - RobotState.current_energy
	energy_needed = max(0, energy_needed)
	
	charge_info_label.text = "Charge Cost: %d Base Energy" % energy_needed
	
	# Update the Robot Energy label to show the projection
	robot_energy_label.text = "Robot Energy: %d -> %d / %d" % [RobotState.current_energy, target_energy, RobotState.MAX_ENERGY]


func _on_charge_slider_changed(new_value: float):
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
	
	update_robot_stats()

func _on_equipment_changed(_item = null):
	var bonuses = _calculate_equipment_bonuses()
	RobotState.update_equipment_bonuses(bonuses.energy, bonuses.storage)
	
	# When equipment changes, update slider range but keep current value
	charge_slider.max_value = RobotState.MAX_ENERGY
	charge_slider.value = min(charge_slider.value, RobotState.MAX_ENERGY)
	
	update_robot_stats()

func update_robot_stats():
	# 1. Update der Stat-Labels (die neue Übersicht)
	base_energy_label.text = "Base Energy: %d / %d" % [RobotState.base_energy_current, RobotState.base_max_energy]
	
	# Sync slider max
	charge_slider.max_value = RobotState.MAX_ENERGY
	
	# If the slider is not being dragged (or we just opened the screen), sync its value too?
	# For now, let's just update the text. The slider value is handled in show_screen and _on_equipment_changed.
	robot_energy_label.text = "Robot Energy: %d / %d" % [RobotState.current_energy, RobotState.MAX_ENERGY]

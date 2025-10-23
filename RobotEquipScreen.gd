# RobotEquipScreen.gd
extends Control
class_name RobotEquipScreen
# --- UI-Referenzen ---
# (Deine bisherigen Referenzen)
@onready var confirm_button = %ConfirmButton
@onready var battery_item_grid = %BatteryItemGrid # Annahme, du hast so etwas

# NEU: Referenzen für die Auflade-Sektion
@onready var base_energy_label = %BaseEnergyLabel
@onready var robot_energy_label = %RobotEnergyLabel
@onready var charge_slider = %ChargeSlider
@onready var charge_info_label = %ChargeInfoLabel

# --- Logik ---

func show_screen():
	show()
	# KORRIGIERT: Rufe die Funktion mit dem korrekten, alten Namen auf
	update_robot_stats()
	
	var map_view = get_tree().get_first_node_in_group("MapView")
	if map_view and not map_view.is_plan_empty():
		confirm_button.disabled = true
		confirm_button.text = "PLAN IN PROGRESS"
	else:
		confirm_button.disabled = false
		confirm_button.text = "CONFIRM & RETURN"

# KORRIGIERT: Benenne diese Funktion um, damit sie vom ScreenManager gefunden wird
func update_robot_stats():
	# 1. Update der Stat-Labels (die neue Übersicht)
	base_energy_label.text = "Base Energy: %d / %d" % [RobotState.base_energy_current, RobotState.base_max_energy]
	robot_energy_label.text = "Robot Energy: %d / %d" % [RobotState.current_energy, RobotState.MAX_ENERGY]
	
	# 2. Konfiguriere den Lade-Slider
	charge_slider.min_value = RobotState.current_energy
	charge_slider.max_value = RobotState.MAX_ENERGY
	charge_slider.value = RobotState.current_energy
	
	# 3. Update der Info-Anzeige für den Slider
	_on_charge_slider_changed(charge_slider.value)


func _on_charge_slider_changed(new_value: float):
	var target_energy = int(new_value)
	var energy_needed = target_energy - RobotState.current_energy
	
	if energy_needed > RobotState.base_energy_current:
		target_energy = RobotState.current_energy + RobotState.base_energy_current
		charge_slider.value = target_energy
		energy_needed = target_energy - RobotState.current_energy

	charge_info_label.text = "Charge Cost: %d Base Energy" % energy_needed


func _on_confirm_button_pressed():
	var bonus_energy = 0
	var bonus_storage = 0
	RobotState.update_equipment_bonuses(bonus_energy, bonus_storage)

	var energy_to_charge = int(charge_slider.value) - RobotState.current_energy
	if energy_to_charge > 0:
		RobotState.charge_robot_from_base(energy_to_charge)

	var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
	if screen_manager:
		screen_manager.show_screen("game")

func _ready():
	charge_slider.value_changed.connect(_on_charge_slider_changed)

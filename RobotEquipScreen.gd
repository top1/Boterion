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

# Diese Funktion wird vom ScreenManager aufgerufen, wenn der Screen angezeigt wird.
func show_screen():
	show()
	# Aktualisiere die gesamte Anzeige mit den frischesten Werten aus RobotState.
	_update_display()
	
	# Sperre den Confirm-Button, wenn eine Mission geplant ist.
	var map_view = get_tree().get_first_node_in_group("MapView") # Annahme für Gruppennamen
	if map_view and not map_view.is_plan_empty():
		confirm_button.disabled = true
		confirm_button.text = "PLAN IN PROGRESS"
	else:
		confirm_button.disabled = false
		confirm_button.text = "CONFIRM & RETURN"

# NEU: Eine zentrale Funktion, die alle Anzeigen aktualisiert.
func _update_display():
	# 1. Update der Stat-Labels (die neue Übersicht)
	base_energy_label.text = "Base Energy: %d / %d" % [RobotState.base_energy_current, RobotState.base_max_energy]
	robot_energy_label.text = "Robot Energy: %d / %d" % [RobotState.current_energy, RobotState.MAX_ENERGY]
	
	# 2. Konfiguriere den Lade-Slider
	charge_slider.min_value = RobotState.current_energy # Man kann nicht weniger Energie haben als jetzt
	charge_slider.max_value = RobotState.MAX_ENERGY   # Man kann nicht mehr als das Maximum laden
	charge_slider.value = RobotState.current_energy    # Der Slider startet bei der aktuellen Energie
	
	# 3. Update der Info-Anzeige für den Slider
	_on_charge_slider_changed(charge_slider.value)


# NEU: Diese Funktion wird aufgerufen, wenn der Slider bewegt wird.
func _on_charge_slider_changed(new_value: float):
	var target_energy = int(new_value)
	var energy_needed = target_energy - RobotState.current_energy
	
	# Sicherheitsabfrage: Wenn wir mehr Energie brauchen, als die Basis hat,
	# begrenzen wir das Ziel auf das, was wir uns leisten können.
	if energy_needed > RobotState.base_energy_current:
		target_energy = RobotState.current_energy + RobotState.base_energy_current
		charge_slider.value = target_energy # Schiebe den Slider visuell zurück
		energy_needed = target_energy - RobotState.current_energy

	charge_info_label.text = "Charge Cost: %d Base Energy" % energy_needed


# VERBINDEN: Stelle sicher, dass diese Funktion mit dem "pressed"-Signal des Sliders verbunden ist!
func _on_confirm_button_pressed():
	# 1. Berechne die Ausrüstungs-Boni (dein bisheriger Code hier)
	var bonus_energy = 0 # ... berechne Boni aus Items
	var bonus_storage = 0
	RobotState.update_equipment_bonuses(bonus_energy, bonus_storage)

	# 2. NEU: Führe die Aufladung durch
	var energy_to_charge = int(charge_slider.value) - RobotState.current_energy
	if energy_to_charge > 0:
		# Rufe eine neue Funktion in RobotState auf, die die Transaktion sicher durchführt
		RobotState.charge_robot_from_base(energy_to_charge)

	# 3. Wechsle zurück zum MapView
	var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
	if screen_manager:
		screen_manager.show_screen("game")

func _ready():
	# VERBINDEN: Stelle sicher, dass das value_changed Signal des Sliders hiermit verbunden ist!
	charge_slider.value_changed.connect(_on_charge_slider_changed)

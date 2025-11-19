# RobotState.gd
extends Node

signal energy_changed(new_max_energy)

# --- KARTEN-VERWALTUNG ---
var map_data: Dictionary = {}
const MapGenerator = preload("res://MapGenerator.gd")
var map_generator = MapGenerator.new()
var map_seed = 1337

# --- BASIS-ENERGIE ---
var base_max_energy: int = 100 # Das tägliche Energie-Budget der Basis
var base_energy_current: int = 100

# --- ROBOTER-WERTE (KORRIGIERT) ---
# Core robot stats
var robot_base_max_energy: int = 60
var robot_base_max_storage: int = 50
var bonus_max_energy: int = 0
var bonus_max_storage: int = 0
var MAX_ENERGY: int = 60
var MAX_STORAGE: int = 50

# Current values
var current_energy: int = 0 # Start at 0, not MAX_ENERGY
var current_storage: int = 0

# --- KOSTEN-KONSTANTEN ---
const MOVE_COST_PER_UNIT: int = 10
const SCAN_COST: int = 5
const ENERGY_PER_ELECTRONIC: int = 3
const ENERGY_PER_SCRAP: int = 2
const ENERGY_PER_BLUEPRINT: int = 10
const ENERGY_PER_FOOD: int = 4


var _has_initialized_full_charge: bool = false

func _ready():
	_recalculate_max_values()
	# We do NOT charge here anymore. We wait for the equipment to be loaded.

func ensure_initial_full_charge():
	if not _has_initialized_full_charge:
		print("--- ROBOTSTATE: Performing INITIAL FULL CHARGE (incl. equipment) ---")
		current_energy = MAX_ENERGY
		_has_initialized_full_charge = true
		emit_signal("energy_changed", MAX_ENERGY)

func initialize_map_if_needed():
	if map_data.is_empty():
		print("--- ROBOTSTATE: Generating NEW persistent map data ---")
		map_data = map_generator.generate_map_data(map_seed)
	else:
		print("--- ROBOTSTATE: Using EXISTING persistent map data ---")

func _recalculate_max_values():
	var old_max = MAX_ENERGY
	MAX_ENERGY = robot_base_max_energy + bonus_max_energy
	MAX_STORAGE = robot_base_max_storage + bonus_max_storage
	
	# Only clamp, never auto-fill
	current_energy = min(current_energy, MAX_ENERGY)
	current_storage = min(current_storage, MAX_STORAGE)
	
	emit_signal("energy_changed", MAX_ENERGY)

func update_equipment_bonuses(bonus_energy: int, bonus_storage: int):
	bonus_max_energy = bonus_energy
	bonus_max_storage = bonus_storage
	_recalculate_max_values()

func start_new_day():
	# Only reset base energy, NOT robot energy
	base_energy_current = base_max_energy
	
	print("--- NEW DAY STARTED ---")
	print("Base Energy reset to: %d / %d" % [base_energy_current, base_max_energy])
	print("Robot Energy remains: %d / %d" % [current_energy, MAX_ENERGY])

func charge_robot_from_base(amount_to_charge: int):
	# Sicherheitsabfrage: Stelle sicher, dass wir genug Basis-Energie haben.
	if base_energy_current >= amount_to_charge:
		# Führe die Transaktion durch
		base_energy_current -= amount_to_charge
		current_energy += amount_to_charge
		
		# Stelle sicher, dass die Roboter-Energie das Maximum nicht überschreitet.
		current_energy = min(current_energy, MAX_ENERGY)
		
		print("Charged robot with %d energy. Cost: %d Base Energy." % [amount_to_charge, amount_to_charge])
	else:
		print("ERROR: Not enough base energy to perform charge!")

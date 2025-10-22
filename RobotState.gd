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
var robot_base_max_energy: int = 60 # Eindeutiger Name!
var robot_base_max_storage: int = 50
var bonus_max_energy: int = 0
var bonus_max_storage: int = 0
var MAX_ENERGY: int = 60 # Berechneter Maximalwert für den Roboter
var MAX_STORAGE: int = 50 # Berechneter Maximalwert für den Roboter

# --- LIVE-WERTE DES ROBOTERS ---
var current_energy: int = 60
var current_storage: int = 0

# --- KOSTEN-KONSTANTEN ---
const MOVE_COST_PER_UNIT: int = 10
const SCAN_COST: int = 5
const ENERGY_PER_ELECTRONIC: int = 3
const ENERGY_PER_SCRAP: int = 2
const ENERGY_PER_BLUEPRINT: int = 10
const ENERGY_PER_FOOD: int = 4


func _ready():
	_recalculate_max_values()

func initialize_map_if_needed():
	if map_data.is_empty():
		print("--- ROBOTSTATE: Generating NEW persistent map data ---")
		map_data = map_generator.generate_map_data(map_seed)
	else:
		print("--- ROBOTSTATE: Using EXISTING persistent map data ---")

func _recalculate_max_values():
	# KORRIGIERT: Verwendet jetzt den neuen, eindeutigen Variablennamen
	MAX_ENERGY = robot_base_max_energy + bonus_max_energy
	MAX_STORAGE = robot_base_max_storage + bonus_max_storage
	current_energy = MAX_ENERGY
	emit_signal("energy_changed", MAX_ENERGY)

func update_equipment_bonuses(bonus_energy: int, bonus_storage: int):
	bonus_max_energy = bonus_energy
	bonus_max_storage = bonus_storage
	_recalculate_max_values()

func start_new_day():
	# Setzt die Basis-Energie auf das tägliche Maximum zurück.
	base_energy_current = base_max_energy
	
	print("--- NEW DAY STARTED ---")
	print("Base Energy reset to: %d / %d" % [base_energy_current, base_max_energy])
	print("Robot Energy is now: %d / %d" % [current_energy, MAX_ENERGY])

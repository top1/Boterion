# RobotState.gd
extends Node

signal energy_changed(new_max_energy)

# --- KARTEN-VERWALTUNG ---
var map_data: Dictionary = {}
const MapGenerator = preload("res://MapGenerator.gd")
var map_generator = MapGenerator.new()
var map_seed = 1337

# --- BASIS-WERTE ---
var base_max_energy: int = 60
var base_max_storage: int = 50

# --- BONI & MAXIMALWERTE ---
var bonus_max_energy: int = 0
var bonus_max_storage: int = 0
var MAX_ENERGY: int = 60
var MAX_STORAGE: int = 50

# --- LIVE-WERTE ---
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

# Stellt sicher, dass die Karte nur einmal am Anfang generiert wird.
func initialize_map_if_needed():
	if map_data.is_empty():
		print("--- ROBOTSTATE: Generating NEW persistent map data ---")
		map_data = map_generator.generate_map_data(map_seed)
	else:
		print("--- ROBOTSTATE: Using EXISTING persistent map data ---")

# Berechnet die Max-Werte neu UND setzt die aktuelle Energie auf das neue Maximum.
func _recalculate_max_values():
	MAX_ENERGY = base_max_energy + bonus_max_energy
	MAX_STORAGE = base_max_storage + bonus_max_storage
	current_energy = MAX_ENERGY # Der Bugfix von vorhin
	emit_signal("energy_changed", MAX_ENERGY)

# Funktion, die vom EquipScreen aufgerufen wird.
func update_equipment_bonuses(bonus_energy: int, bonus_storage: int):
	bonus_max_energy = bonus_energy
	bonus_max_storage = bonus_storage
	_recalculate_max_values()

# KORRIGIERT: Deine ursprüngliche Funktion, die vom ScreenManager aufgerufen wird.
func start_new_day():
	current_energy = MAX_ENERGY

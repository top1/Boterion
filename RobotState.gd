# RobotState.gd - NEUE, VERBESSERTE VERSION
extends Node

# --- KOSTEN-KONSTANTEN ---
const MOVE_COST_PER_UNIT: int = 10
const SCAN_COST: int = 20

# --- NEUE KOSTEN FÜR LOOT/SCAVENGE ---
# "Scavenge" ist für Materialien
const ENERGY_PER_ELECTRONIC: int = 8
const ENERGY_PER_SCRAP: int = 5

# "Loot" ist für wertvollere Gegenstände
const ENERGY_PER_BLUEPRINT: int = 50
const ENERGY_PER_FOOD: int = 10
# --- Signale ---
signal energy_changed(current_energy, max_energy)
signal storage_changed(current_storage, max_storage)

# --- Basis-Werte des Roboters ---
var base_max_energy: int = 60
var base_max_storage: int = 500

# --- Boni durch Ausrüstung ---
var bonus_max_energy: int = 0
var bonus_max_storage: int = 0

# --- Finale, berechnete Maximalwerte ---
var MAX_ENERGY: int
var MAX_STORAGE: int

# --- Aktuelle Werte ---
var current_energy: int = 0: 
	set(value):
		current_energy = clamp(value, 0, MAX_ENERGY)
		emit_signal("energy_changed", current_energy, MAX_ENERGY)

var current_storage: int = 0:
	set(value):
		current_storage = clamp(value, 0, MAX_STORAGE)
		emit_signal("storage_changed", current_storage, MAX_STORAGE)

# --- NEUE ZENTRALE UPDATE-FUNKTION ---
# Der EquipScreen ruft diese Funktion auf und meldet nur die reinen Boni.
func update_equipment_bonuses(energy_bonus: int, storage_bonus: int):
	print("Boni erhalten: %d Energie, %d Lager" % [energy_bonus, storage_bonus])
	self.bonus_max_energy = energy_bonus
	self.bonus_max_storage = storage_bonus
	_recalculate_total_stats()

# Interne Funktion, um die finalen Werte neu zu berechnen.
func _recalculate_total_stats():
	# 1. Berechne die neuen Maximalwerte
	MAX_ENERGY = base_max_energy + bonus_max_energy
	MAX_STORAGE = base_max_storage + bonus_max_storage
	
	# 2. Passe die aktuellen Werte an und sende Signale aus
	#    (self.current_energy ruft die set-Funktion auf)
	self.current_energy = MAX_ENERGY
	self.current_storage = current_storage

func _ready():
	# 1. Berechne die finalen Maximalwerte zum ersten Mal.
	_recalculate_total_stats()
	# 2. Setze die Start-Energie des Roboters auf den neuen Maximalwert.
	self.current_energy = MAX_ENERGY
	
func start_new_day():
	self.current_energy = MAX_ENERGY

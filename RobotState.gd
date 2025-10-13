# RobotState.gd
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
signal energy_changed
signal storage_changed # <-- NEUES SIGNAL

# --- Energie ---
const MAX_ENERGY: int = 400
var current_energy: int = MAX_ENERGY:
	set(value):
		current_energy = clamp(value, 0, MAX_ENERGY)
		emit_signal("energy_changed")

# --- Speicher (NEUE VARIABLEN) ---
const MAX_STORAGE: int = 200
var current_storage: int = 0:
	set(value):
		current_storage = clamp(value, 0, MAX_STORAGE)
		emit_signal("storage_changed")

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
# Core robot stats
var robot_base_max_energy: int = 120
var robot_base_max_storage: int = 50
var bonus_max_energy: int = 0
var bonus_max_storage: int = 0
var MAX_ENERGY: int = 60
var MAX_STORAGE: int = 50

# Current values
var current_energy: int = 0 # Start at 0, not MAX_ENERGY
var current_storage: int = 0

# --- KOSTEN-KONSTANTEN ---
const MOVE_COST_PER_UNIT: int = 2
const SCAN_COST: int = 5
const ENERGY_PER_ELECTRONIC: int = 3
const ENERGY_PER_SCRAP: int = 2
const ENERGY_PER_BLUEPRINT: int = 10
const ENERGY_PER_FOOD: int = 4

# --- PERSISTENT RESOURCES & INVENTORY ---
var scrap: int = 0
var electronics: int = 0
var food: int = 0

var inventory: Array[Resource] = [] # Array of Item resources
var known_blueprints: Array[Resource] = [] # Array of Item resources (unlocked recipes)

# Daily Research Logic
var daily_research_cost: int = 0
var daily_research_options: Array[Resource] = []

# --- SIGNALS ---
signal resources_changed
signal inventory_changed
signal blueprints_changed


var _has_initialized_full_charge: bool = false

func _ready():
	_recalculate_max_values()
	
	# --- DEBUG: ADD NEW ITEMS FOR TESTING ---
	call_deferred("_debug_add_test_items")

func _debug_add_test_items():
	print("--- DEBUG: Adding Test Items ---")
	var items_to_add = [
		"res://items/solar_panel.tres",
		"res://items/quantum_storage.tres",
		"res://items/heavy_duty_frame.tres",
		"res://items/overclocked_core.tres",
		"res://items/capacitor_bank.tres",
		"res://items/potato_battery.tres",
		"res://items/duct_tape_pouch.tres",
		"res://items/rusty_antenna.tres",
		"res://items/cardboard_box.tres",
		"res://items/lithium_ion_cell.tres",
		"res://items/cargo_net.tres",
		"res://items/swiss_army_bot_tool.tres",
		"res://items/mini_fusion_reactor.tres",
		"res://items/expanded_cargo_pod.tres",
		"res://items/zero_point_module.tres",
		"res://items/black_hole_pocket.tres"
	]
	
	for path in items_to_add:
		if ResourceLoader.exists(path):
			var item = load(path)
			if item:
				# Add to inventory
				inventory.append(item)
				# Add to known blueprints
				if not known_blueprints.has(item):
					known_blueprints.append(item)
				print("DEBUG: Added %s to inventory and blueprints." % item.item_name)
	
	emit_signal("inventory_changed")
	emit_signal("blueprints_changed")
	_recalculate_max_values() # In case passive stats apply immediately (though they usually need equipping)

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

func start_new_day(regenerate_map: bool = false):
	# Only reset base energy, NOT robot energy
	base_energy_current = base_max_energy
	
	# Reset Robot Storage (unloaded at base)
	current_storage = 0

	print("--- NEW DAY STARTED ---")
	print("Base Energy reset to: %d / %d" % [base_energy_current, base_max_energy])
	print("Robot Energy remains: %d / %d" % [current_energy, MAX_ENERGY])
	print("Robot Storage unloaded: 0 / %d" % MAX_STORAGE)

	# Ensure map exists (but don't clear it unless we want to force regen)
	initialize_map_if_needed()
	
	generate_daily_research_offer()
func calculate_path_cost(target_room_distance: int, action_cost: int) -> void:
	var travel_cost = target_room_distance * MOVE_COST_PER_UNIT
	var return_cost = target_room_distance * MOVE_COST_PER_UNIT
	var total = travel_cost + action_cost + return_cost
	print("DEBUG PATH COST: Dist: %d | Travel: %d | Action: %d | Return: %d | Total: %d" % [target_room_distance, travel_cost, action_cost, return_cost, total])
func add_resources(loot_dict: Dictionary):
	if loot_dict.has("scrap_metal"):
		scrap += loot_dict["scrap_metal"]
	if loot_dict.has("electronics"):
		electronics += loot_dict["electronics"]
	if loot_dict.has("food"):
		food += loot_dict["food"]
		# Optional: Auto-convert food to energy? Or keep it?
		# For now, let's keep it as a resource, maybe for healing or trading later.
	
	emit_signal("resources_changed")
	print("Resources Updated: Scrap=%d, Elec=%d, Food=%d" % [scrap, electronics, food])

func generate_daily_research_offer():
	# Random cost between 40 and 100
	daily_research_cost = randi_range(40, 100)
	# Clear previous options (we will generate them only when paid, or pre-generate? 
	# Let's generate them when paid to avoid saving them for now, or pre-generate if we want to show them locked)
	daily_research_options.clear()
	print("Daily Research Cost set to: %d" % daily_research_cost)

func pay_research_cost() -> bool:
	if base_energy_current >= daily_research_cost:
		base_energy_current -= daily_research_cost
		return true
	return false

func unlock_blueprint(item: Resource):
	if not known_blueprints.has(item):
		known_blueprints.append(item)
		emit_signal("blueprints_changed")
		print("Unlocked Blueprint: %s" % item.item_name)

func can_craft(item: Resource) -> bool:
	var recipe = item.crafting_recipe
	if recipe.is_empty():
		return false
		
	var cost_scrap = recipe.get("scrap", 0)
	var cost_elec = recipe.get("electronics", 0)
	var cost_energy = recipe.get("energy", 0) # Base energy cost for crafting
	
	if scrap < cost_scrap: return false
	if electronics < cost_elec: return false
	if base_energy_current < cost_energy: return false
	
	return true

func craft_item(item: Resource):
	if can_craft(item):
		var recipe = item.crafting_recipe
		scrap -= recipe.get("scrap", 0)
		electronics -= recipe.get("electronics", 0)
		base_energy_current -= recipe.get("energy", 0)
		
		inventory.append(item)
		emit_signal("resources_changed")
		emit_signal("inventory_changed")
		print("Crafted Item: %s" % item.item_name)
	else:
		print("Cannot craft item: Insufficient resources")

func charge_robot_from_base(amount_to_charge: int):
	# 1. Calculate how much we actually need and can afford
	var needed = MAX_ENERGY - current_energy
	var available = base_energy_current
	
	# The actual amount is the smallest of: requested, needed, available
	var actual_charge = min(amount_to_charge, min(needed, available))
	
	if actual_charge <= 0:
		print("Charge skipped: No energy needed or no base energy available.")
		return

	# 2. Perform the transaction
	base_energy_current -= actual_charge
	current_energy += actual_charge
	
	# Double check clamp (redundant but safe)
	current_energy = min(current_energy, MAX_ENERGY)
	
	print("Charged robot with %d energy. Cost: %d Base Energy." % [actual_charge, actual_charge])

func increase_base_energy(amount: int):
	base_max_energy += amount
	base_energy_current += amount # Give immediate benefit too
	print("Base Energy Increased! New Max: %d" % base_max_energy)
	# We might want a signal here if we had a UI listening for it live, 
	# but screens usually update on show().

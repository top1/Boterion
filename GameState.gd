# GameState.gd
extends Node

# --- PRELOAD SCRIPTS ---
# This tells Godot to load these class definitions so we can use them
const Robot = preload("res://Robot.gd")
const Room = preload("res://Room.gd")

# --- GAME DATA STORE ---
# Having this data here makes it globally accessible
const GAME_DATA = {
	"ROOM_ARCHETYPES": {
		"Habitation": { "description": "A personal living space.", "scavenge_table": {"scrap_metal": [5, 20]}, "loot_table": {"food": 0.6}},
		"Storage": { "description": "A storage or cargo area.", "scavenge_table": {"scrap_metal": [50, 100]}, "loot_table": {}},
		"Workshop": { "description": "Fabrication tools and computer terminals.", "scavenge_table": {"electronics": [10, 25]}, "loot_table": {"blueprint_tier1": 0.2}}
	},
	"GEAR_BLUEPRINTS": {
		"battery_mk1": { "build_cost": {"scrap_metal": 50}, "capacity": 100 },
		"storage_mk1": { "build_cost": {"scrap_metal": 30}, "storage_slots": 100 },
		"basic_breaker": { "build_cost": {}, "efficiency": {"Standard": 20, "Electronic": 150, "Barricaded": 180}}
	}
}


# --- CORE RESOURCES ---
var day = 1
var player_food = 20
var base_energy = 1000
var inventory = { "scrap_metal": 100, "electronics": 50, "food": 5 }
var known_blueprints = ["battery_mk1", "storage_mk1"]

# --- WORLD STATE ---
var corridor_map = []
var robot = Robot.new() # NEW: We create an instance of our Robot class
var seed_value = 1337

# This function is called automatically when the game starts
func _ready():
	randomize() # Initialize Godot's random number generator
	seed(seed_value) # Set the seed
	_generate_map_packed(21)
	_initialize_robot()

func _initialize_robot():
	# Create and equip starting gear
	var bp = GAME_DATA.GEAR_BLUEPRINTS
	var bat_bp = bp.battery_mk1
	var sto_bp = bp.storage_mk1
	var tol_bp = bp.basic_breaker
	
	robot.equip("battery", Robot.Battery.new("battery_mk1", "", bat_bp.build_cost, bat_bp.capacity))
	robot.equip("storage", Robot.Storage.new("storage_mk1", "", sto_bp.build_cost, sto_bp.storage_slots))
	robot.equip("tool_primary", Robot.Tool.new("basic_breaker", "", tol_bp.build_cost, tol_bp.efficiency))
	robot.charge(robot.max_battery)

# --- MAP GENERATION LOGIC (ported to GDScript) ---
func _generate_map_packed(corridor_length: int):
	var room_id_counter = 1
	var left_side_result = _generate_packed_side(corridor_length, room_id_counter)
	var right_side_result = _generate_packed_side(corridor_length, left_side_result.id_counter)
	
	for i in range(corridor_length):
		corridor_map.append({'left': left_side_result.side_map[i], 'right': right_side_result.side_map[i]})

func _generate_packed_side(corridor_length: int, start_id: int):
	var side_map = []
	side_map.resize(corridor_length) # Initialize with nulls
	
	var current_pos = 0
	var room_id_counter = start_id
	var room_phys_types = {'small': 1, 'medium': 3, 'big': 5}
	var room_arch_types = GAME_DATA.ROOM_ARCHETYPES.keys()

	while current_pos < corridor_length:
		var remaining_space = corridor_length - current_pos
		var valid_options = []
		for type in room_phys_types:
			if room_phys_types[type] <= remaining_space:
				valid_options.append([type, room_phys_types[type]])
		if valid_options.is_empty(): break

		var choice = valid_options.pick_random()
		var phys_type = choice[0]
		var chosen_size = choice[1]
		var door_position = current_pos + (chosen_size - 1) / 2
		
		var arch_type = room_arch_types.pick_random()
		var new_room = Room.new(room_id_counter, arch_type, chosen_size, GAME_DATA)
		side_map[door_position] = new_room
		
		room_id_counter += 1
		current_pos += chosen_size
	
	return {"side_map": side_map, "id_counter": room_id_counter}

# Add this function to GameState.gd

func run_mission(mission_plan: Array) -> Dictionary:
	var report = {
		"energy_spent": 0,
		"resources_gained": {},
		"log": []
	}
	
	for target in mission_plan:
		var target_room_id = target["room_id"]
		
		# Find the room and its position in the corridor
		var room_pos = -1
		var room_obj = null
		for i in corridor_map.size():
			var pos_data = corridor_map[i]
			if pos_data.left and pos_data.left.room_id == target_room_id:
				room_pos = i
				room_obj = pos_data.left
				break
			if pos_data.right and pos_data.right.room_id == target_room_id:
				room_pos = i
				room_obj = pos_data.right
				break
		
		if not room_obj:
			report.log.append("Target Room ID %d not found. Aborting." % target_room_id)
			break

		# --- Simulate the Mission ---
		var travel_cost = abs(room_pos - robot.position) * robot.move_cost
		var tool = robot.gear_slots.tool_primary
		var door_cost = tool.efficiency.get(room_obj.door_type, 999)
		
		# Check if the mission is even possible
		if robot.current_battery < travel_cost + door_cost + travel_cost:
			report.log.append("Not enough battery for Room %d. Mission aborted." % target_room_id)
			break
			
		# Execute travel and door break
		robot.position = room_pos
		robot.current_battery -= (travel_cost + door_cost)
		report.energy_spent += (travel_cost + door_cost)
		report.log.append("Traveled to Room %d. Broke %s door (Cost: %d)." % [target_room_id, room_obj.door_type, door_cost])
		
		# For this prototype, we'll hardcode the action to SCAVENGE and spend 50% energy
		var energy_for_action = robot.current_battery - travel_cost # Leave enough for return
		var energy_to_spend = energy_for_action * 0.50
		
		var efficiency = energy_to_spend / 50.0
		for item in room_obj.scavenge_table:
			var min_q = room_obj.scavenge_table[item][0]
			var max_q = room_obj.scavenge_table[item][1]
			var quantity = int(randi_range(min_q, max_q) * efficiency)
			if quantity > 0:
				report.resources_gained[item] = report.resources_gained.get(item, 0) + quantity
		report.log.append("Scavenged room for %d energy." % energy_to_spend)
		
		robot.current_battery -= energy_to_spend
		
		# Return to base
		robot.current_battery -= travel_cost
		robot.position = 0
		report.log.append("Robot returned to base.")

	# --- Finalize ---
	# Add the scavenged resources to the main inventory
	for item in report.resources_gained:
		inventory[item] = inventory.get(item, 0) + report.resources_gained[item]
		
	return report

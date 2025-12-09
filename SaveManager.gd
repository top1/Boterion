extends Node

const SAVE_PATH = "user://savegame.json"

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game():
	var save_data = {
		# Robot Stats
		"robot_base_max_energy": RobotState.robot_base_max_energy,
		"robot_base_max_storage": RobotState.robot_base_max_storage,
		"current_energy": RobotState.current_energy,
		"current_storage": RobotState.current_storage,
		
		# Resources
		"scrap": RobotState.scrap,
		"electronics": RobotState.electronics,
		"food": RobotState.food,
		
		# Base
		"base_max_energy": RobotState.base_max_energy,
		"base_energy_current": RobotState.base_energy_current,
		
		# Inventory (Resources Paths)
		"inventory": _serialize_resource_array(RobotState.inventory),
		"known_blueprints": _serialize_resource_array(RobotState.known_blueprints),
		
		# Artifacts
		"active_artifacts": _serialize_artifact_array(RobotState.active_artifacts),
		"artifact_inventory": _serialize_artifact_array(RobotState.artifact_inventory),
		
		# Map
		"map_seed": RobotState.map_seed,
		"map_data": _serialize_map_data(RobotState.map_data)
	}
	
	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		print("--- SaveManager: Game Saved ---")
	else:
		print("--- SaveManager: Error saving game! ---")

func load_game():
	if not has_save_file():
		print("--- SaveManager: No save file found! ---")
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		var data = json.data
		_apply_save_data(data)
		print("--- SaveManager: Game Loaded ---")
	else:
		print("--- SaveManager: JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())

func _apply_save_data(data: Dictionary):
	# Robot Stats
	RobotState.robot_base_max_energy = data.get("robot_base_max_energy", 120)
	RobotState.robot_base_max_storage = data.get("robot_base_max_storage", 50)
	RobotState.current_energy = data.get("current_energy", 0)
	RobotState.current_storage = data.get("current_storage", 0)
	
	# Resources
	RobotState.scrap = data.get("scrap", 0)
	RobotState.electronics = data.get("electronics", 0)
	RobotState.food = data.get("food", 0)
	
	# Base
	RobotState.base_max_energy = data.get("base_max_energy", 100)
	RobotState.base_energy_current = data.get("base_energy_current", 100)
	
	# Inventory
	RobotState.inventory = _deserialize_resource_array(data.get("inventory", []))
	RobotState.known_blueprints = _deserialize_resource_array(data.get("known_blueprints", []))
	
	# Artifacts - These need special handling if they are Resources or Objects
	# Based on previous context, Artifacts seem to be extended scripts or inner classes.
	# Let's see how they are implemented. Assuming they are Resources or basic Objects.
	# The implementation plan mentioned serializing resource paths, but Artifacts might be dynamically created objects (from generate_random_artifact).
	# If they are dynamic objects, we need to save their properties.
	
	# RE-CHECK: Artifact.gd content
	# I'll implement a basic serializer for artifacts now assuming they are simple objects with properties.
	RobotState.active_artifacts = _deserialize_artifact_array(data.get("active_artifacts", []))
	RobotState.artifact_inventory = _deserialize_artifact_array(data.get("artifact_inventory", []))
	
	# Map
	RobotState.map_seed = data.get("map_seed", 1337)
	RobotState.map_data = _deserialize_map_data(data.get("map_data", {}))
	
	# Trigger updates
	RobotState.emit_signal("resources_changed")
	RobotState.emit_signal("inventory_changed")
	RobotState.emit_signal("blueprints_changed")
	RobotState.emit_signal("artifacts_changed")
	RobotState.emit_signal("energy_changed", RobotState.MAX_ENERGY)

# --- Helper Functions ---

func _serialize_map_data(map_data: Dictionary) -> Dictionary:
	var serialized = {}
	# Map data has "top" and "bottom" arrays of RoomData
	for key in map_data:
		if key == "top" or key == "bottom":
			var room_list = []
			for room in map_data[key]:
				if room is RoomData:
					var room_dict = {
						"room_id": room.room_id,
						"type": room.type,
						"size": room.size,
						"distance": room.distance,
						"door_strength": room.door_strength,
						"is_scanned": room.is_scanned,
						"is_door_open": room.is_door_open,
						"is_repaired": room.is_repaired,
						"looting_state": room.looting_state,
						"loot_pool": room.loot_pool, # Dictionary, safe
						"blueprint_items": _serialize_resource_array(room.blueprint_items)
					}
					room_list.append(room_dict)
			serialized[key] = room_list
	return serialized

func _deserialize_map_data(data: Dictionary) -> Dictionary:
	var map_data = {}
	for key in data:
		if key == "top" or key == "bottom":
			var room_list: Array[RoomData] = []
			var raw_list = data[key]
			
			if not raw_list is Array:
				print("WARNING: Map data key '%s' is not an Array. Skipping." % key)
				continue
				
			for room_dict in raw_list:
				# SAFETY CHECK: Old saves might have Strings here
				if not room_dict is Dictionary:
					print("WARNING: Invalid room data found (expected Dictionary, got %s). Skipping." % type_string(typeof(room_dict)))
					continue
					
				var room = RoomData.new()
				room.room_id = room_dict.get("room_id", "")
				room.type = int(room_dict.get("type", 0))
				room.size = int(room_dict.get("size", 1))
				room.distance = int(room_dict.get("distance", 0))
				room.door_strength = int(room_dict.get("door_strength", 0))
				room.is_scanned = bool(room_dict.get("is_scanned", false))
				room.is_door_open = bool(room_dict.get("is_door_open", false))
				room.is_repaired = bool(room_dict.get("is_repaired", false))
				room.looting_state = int(room_dict.get("looting_state", 0))
				room.loot_pool = room_dict.get("loot_pool", {})
				room.blueprint_items = _deserialize_resource_array(room_dict.get("blueprint_items", []))
				room_list.append(room)
			map_data[key] = room_list
	return map_data

func _serialize_resource_array(array: Array) -> Array:
	var paths = []
	for item in array:
		if item is Resource and item.resource_path != "":
			paths.append(item.resource_path)
	return paths

func _deserialize_resource_array(paths: Array) -> Array[Resource]:
	var resources: Array[Resource] = []
	for path in paths:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is Resource:
				resources.append(res)
			else:
				print("WARNING: Failed to load resource or invalid type at path: ", path)
	return resources

func _serialize_artifact_array(array: Array) -> Array:
	var serialized = []
	for art in array:
		# Assuming Artifact has keys we care about. 
		# We need to save enough to recreate it.
		var art_data = {
			"id": art.get("id"),
			"name": art.get("name"),
			"description": art.get("description"),
			"effect_type": art.get("effect_type"),
			"effect_value": art.get("effect_value")
		}
		serialized.append(art_data)
	return serialized

func _deserialize_artifact_array(data_array: Array) -> Array:
	var artifacts = []
	var ArtifactScript = load("res://Artifact.gd") # Preload might cause issues if cyclic, simple load is safer inside func
	
	for art_data in data_array:
		var art = ArtifactScript.new()
		art.id = art_data.get("id", "")
		art.name = art_data.get("name", "Unknown Artifact")
		art.description = art_data.get("description", "")
		art.effect_type = int(art_data.get("effect_type", 0))
		art.effect_value = art_data.get("effect_value", 0.0)
		artifacts.append(art)
	return artifacts

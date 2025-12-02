# MapGenerator.gd
# Generiert die Datenstruktur für die Korridorkarte.

# Wir laden unser RoomData-Skript, um neue Instanzen davon erstellen zu können.
# const RoomData = preload("res://RoomData.gd") # REMOVED: Use global class_name instead


# Die Gesamtbreite des Korridors in Blöcken.
const MAP_LENGTH = 42

# Wir definieren die Raumgrößen und ihre Wahrscheinlichkeiten.
# Das Format ist: [Größe, Gewichtung]. Höhere Gewichtung = höhere Wahrscheinlichkeit.
const ROOM_SIZES_WEIGHTED = [
	[1, 3], # 3/10 Chance
	[3, 4], # 4/10 Chance
	[5, 2], # 2/10 Chance
	[9, 1] # 1/10 Chance
]

var rng = RandomNumberGenerator.new()

# Die Hauptfunktion, die die gesamte Karte generiert.
func generate_map_data(seed_value: int) -> Dictionary:
	rng.seed = seed_value

	# Wir generieren die obere und untere Raumreihe getrennt.
	# Reset factory count for this map generation
	_current_factory_count = 0
	_max_factories = rng.randi_range(2, 3) # Limit to 2-3 factories per map
	
	var top_rooms = _generate_row("A")
	var bottom_rooms = _generate_row("B")

	return {
		"top": top_rooms,
		"bottom": bottom_rooms
	}

var _current_factory_count = 0
var _max_factories = 0

# Interne Hilfsfunktion zur Generierung einer einzelnen Raumreihe (oben oder unten).
func _generate_row(id_prefix: String) -> Array[RoomData]:
	var rooms_array: Array[RoomData] = []
	var current_pos = 0
	var room_counter = 1

	while current_pos < MAP_LENGTH:
		var room_size = 0

		# --- NEUE LOGIK (OPTIMIERT) ---
		# Wir suchen eine passende Größe, indem wir alle möglichen Größen durchprobieren.
		# Damit es zufällig bleibt, mischen wir die Optionen vorher.
		var possible_sizes = [1, 3, 5, 9]
		possible_sizes.shuffle()
		
		var found_fitting_size = false
		
		# Versuche zuerst die zufällig gewählten Größen
		for size in possible_sizes:
			if current_pos + size <= MAP_LENGTH:
				room_size = size
				found_fitting_size = true
				break
		
		# Fallback: Wenn nichts passt (sollte bei size=1 nicht passieren, aber sicher ist sicher),
		# nehmen wir die kleinstmögliche Größe, die noch passt.
		if not found_fitting_size:
			room_size = 1 # Der kleinste Raum passt immer, solange noch 1 Platz frei ist.
		# --- ENDE NEUE LOGIK ---

		# Wenn kein passender Raum mehr gefunden werden kann (sollte nie passieren,
		# da ein 1er-Raum immer passt), brechen wir sicherheitshalber ab.
		if room_size == 0:
			break
			
		# Erstelle das RoomData-Objekt mit der passenden Größe.
		var new_room = RoomData.new()
		new_room.size = room_size
		
		# Calculate distance early
		var door_offset = (room_size - 1) / 2
		new_room.distance = int(current_pos + door_offset) + 1
		
		# Force Factory spawn logic
		# We want 2-3 factories globally.
		# We can use a simple probability check, but we must respect the max count.
		# Let's say we have a 10% chance per room to be a factory, if we haven't reached the limit.
		if _current_factory_count < _max_factories and rng.randf() < 0.1:
			new_room.type = RoomData.RoomType.FACTORY
			_current_factory_count += 1
		else:
			new_room.type = _get_random_room_type()
			
		new_room.room_id = "%s%d" % [id_prefix, room_counter]
		
		# Generiere zufällige Türstärke
		# FIX: Cap door strength at 100 as requested
		new_room.door_strength = min(100, rng.randi_range(10, new_room.size * 42))

		# Generiere zufällige Beute für jede Ressource
		var electronics_amount = rng.randi_range(10, new_room.size * 21)
		new_room.loot_pool["electronics"]["initial"] = electronics_amount
		new_room.loot_pool["electronics"]["current"] = electronics_amount

		var scrap_amount = rng.randi_range(20, new_room.size * 69)
		new_room.loot_pool["scrap_metal"]["initial"] = scrap_amount
		new_room.loot_pool["scrap_metal"]["current"] = scrap_amount

		# --- BLUEPRINT GENERATION ---
		var blueprints_amount = rng.randi_range(0, new_room.size)
		var new_items: Array[Resource] = []
		new_room.blueprint_items = new_items
		
		# Load items if needed (lazy load list)
		if _all_possible_items.is_empty():
			_load_all_items()
			
		for i in range(blueprints_amount):
			if not _all_possible_items.is_empty():
				new_room.blueprint_items.append(_all_possible_items.pick_random())
		
		new_room.loot_pool["blueprints"]["initial"] = new_room.blueprint_items.size()
		new_room.loot_pool["blueprints"]["current"] = new_room.blueprint_items.size()
		# --- END BLUEPRINT GENERATION ---

		var food_amount = rng.randi_range(5, new_room.size * 3)
		new_room.loot_pool["food"]["initial"] = food_amount
		new_room.loot_pool["food"]["current"] = food_amount
		
		
		# Strange counting but first room would otherwhise be on 0-distance
		new_room.distance = int(current_pos + door_offset) + 1

		rooms_array.append(new_room)
		current_pos += new_room.size
		room_counter += 1
		
	return rooms_array

# Wählt eine zufällige Raumgröße basierend auf den Gewichtungen.
func _get_random_room_size() -> int:
	return Utils.get_weighted_random(ROOM_SIZES_WEIGHTED, rng)


# Wählt einen zufälligen Raumtyp.
func _get_random_room_type() -> RoomData.RoomType:
	# Wir holen uns alle möglichen Enum-Werte.
	var room_types = RoomData.RoomType.keys()
	# Wir entfernen den Default-Namen 'size', der von Godot intern hinzugefügt wird.
	room_types.erase("size")
	var random_type_name = room_types.pick_random()
	return RoomData.RoomType[random_type_name]

var _all_possible_items: Array[Resource] = []

func _load_all_items():
	var items_to_load = [
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
	for path in items_to_load:
		if ResourceLoader.exists(path):
			var item = load(path)
			if item:
				_all_possible_items.append(item)

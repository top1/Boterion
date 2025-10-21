# MapView.gd
# Hauptskript zur Steuerung der Kartenansicht.
extends Control

# Wir laden die Szene für unsere Raum-Blöcke vorab.
const RoomBlockScene = preload("res://RoomBlock.tscn")
# Wir laden das Skript für den Kartengenerator.

# Referenzen zu den Containern in unserer Szene.
@onready var top_row_container = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/ScrollContent/VBoxContainer/TopRowContainer
@onready var bottom_row_container = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/ScrollContent/VBoxContainer/BottomRowContainer
@onready var room_info_label = %RoomInfoLabel
@onready var action_buttons_container = $MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/VBoxContainer
@onready var scan_button = %ScanButton
@onready var loot_button = %LootButton
@onready var scavenge_button = %ScavengeButton
@onready var open_button = %OpenButton
@onready var mission_planner_label = $MarginContainer/VBoxContainer/HBoxContainer/Panel/Label# Passe den Pfad ggf. an oder mache das Label unique
@onready var energy_bar = %EnergyBar
@onready var mission_list_label = %MissionListLabel
@onready var remove_last_mission_button = %RemoveLastMissionButton
@onready var loot_action_container = %LootActionContainer
@onready var loot_slider = %LootSlider
@onready var loot_energy_label = %LootEnergyLabel
@onready var energy_bar_label = %EnergyBarLabel
@onready var execute_plan_button = %ExecutePlanButton
@onready var debug_inspector_panel = %DebugInspectorPanel
@onready var debug_visible_label = %DebugVisibleLabel
@onready var debug_hidden_label = %DebugHiddenLabel

var planned_remaining_energy: int = 0
var mission_plan: Array[Dictionary] = []
var last_position_in_plan: int = 0
# Eine Instanz unseres Generators.
var current_selected_room: RoomData = null
var current_selected_button: Button = null
# Die Seed für die Kartengenerierung.
var map_seed = 1337


func _ready():
	# Einmalige Einrichtung, die nie wieder passiert:
	RobotState.initialize_map_if_needed()
	scan_button.pressed.connect(_on_scan_pressed)
	open_button.pressed.connect(_on_open_pressed)
	loot_button.pressed.connect(_on_loot_pressed)
	scavenge_button.pressed.connect(_on_scavenge_pressed)
	remove_last_mission_button.pressed.connect(_on_remove_last_mission)
	loot_slider.value_changed.connect(_on_loot_slider_changed)
	execute_plan_button.pressed.connect(_on_execute_plan_pressed)
	
	# Rufe show_screen() auf, um den initialen Zustand des Spiels zu zeichnen.
	# Diese Funktion wird von nun an vom ScreenManager für jeden neuen Tag aufgerufen.
	show_screen()
# Diese Funktion löscht die alte Karte und zeichnet eine neue.
func draw_map():
	# 1. Alte Raum-Blöcke entfernen, falls vorhanden.
	for child in top_row_container.get_children():
		child.queue_free()
	for child in bottom_row_container.get_children():
		child.queue_free()

	# 2. Neue Kartendaten generieren.
	var top_rooms: Array[RoomData] = RobotState.map_data.top
	var bottom_rooms: Array[RoomData] = RobotState.map_data.bottom
	# 3. Obere Raumreihe füllen.
	#for room_data in top_rooms:
		#var new_block = RoomBlockScene.instantiate()
		## Die Daten an den Block übergeben.
		#new_block.room_data = room_data
		## Verbinde das Signal des Blocks mit unserer Handler-Funktion.
		#new_block.room_selected.connect(_on_room_selected)
		#top_row_container.add_child(new_block)
	for room_data in top_rooms:
		# 1. Erstelle einen unsichtbaren Platzhalter, der die volle Raumbreite einnimmt.
		# Der CenterContainer ist perfekt dafür, da er sein Kind zentriert.
		var placeholder = CenterContainer.new()
		placeholder.custom_minimum_size.x = room_data.size * 50
		
		# 2. Erstelle den sichtbaren "Tür"-Block wie gehabt.
		var door_block = RoomBlockScene.instantiate()
		door_block.room_data = room_data
		door_block.room_selected.connect(_on_room_selected)

		# 3. Füge die Tür zum Platzhalter hinzu. Er wird sie automatisch zentrieren.
		placeholder.add_child(door_block)

		# 4. Füge den PLATZHALTER (nicht die Tür) zur Reihe hinzu.
		top_row_container.add_child(placeholder)


	# 4. Untere Raumreihe füllen.
	for room_data in bottom_rooms:
		var placeholder = CenterContainer.new()
		placeholder.custom_minimum_size.x = room_data.size * 50
		var new_block = RoomBlockScene.instantiate()
		new_block.room_data = room_data
		new_block.room_selected.connect(_on_room_selected)
		placeholder.add_child(new_block)
		bottom_row_container.add_child(placeholder)

# Ersetze die komplette Funktion mit dieser Version
func _on_room_selected(room_data: RoomData, room_node: Button = null):
	# --- 1. SETUP ---
	current_selected_room = room_data
	if room_node:
		current_selected_button = room_node
	action_buttons_container.hide()
	loot_action_container.hide()

	# --- 2. ZUSTAND PRÜFEN ---
	var is_open_or_planned = room_data.is_door_open or is_action_planned_for_room(room_data.room_id, "OPEN")
	var is_loot_scavenge_planned = is_action_planned_for_room(room_data.room_id, "LOOT") or is_action_planned_for_room(room_data.room_id, "SCAVENGE")

	# --- 3. LOGIK-ZWEIGE ---

	# ZUSTAND A: EINE FINALE AKTION (LOOT/SCAVENGE) IST BEREITS GEPLANT
	if is_loot_scavenge_planned:
		room_info_label.text = "Final action for Room %s is already in the plan." % room_data.room_id
		return

	# ZUSTAND B: "OPEN" IST GEPLANT ODER SCHON OFFEN -> ZEIGE DIE LOOT/SCAVENGE-ANSICHT
	elif is_open_or_planned:
		# --- B.1: VORBERECHNUNGEN ---
		var max_energy_on_site = get_max_available_energy_for_action(room_data.distance)
		var max_investable_energy = min(max_energy_on_site, RobotState.MAX_STORAGE - RobotState.current_storage)

		# --- B.2: INFO-TEXT AUFBAUEN ---
		var info_text = "ROOM %s - ACTION PLANNING\n" % room_data.room_id
		info_text += "--------------------\n"
		info_text += "Energy on site: %d | Storage: %d\n" % [max_energy_on_site, (RobotState.MAX_STORAGE - RobotState.current_storage)]
		info_text += "Max investable Energy: %d\n" % max_investable_energy
		info_text += "--------------------\n"
		
		# --- B.3: UI ANZEIGEN UND KONFIGURIEREN (DIE KOMPLETTE LOGIK) ---
		if room_data.is_completely_empty():
			# GEÄNDERT: Baue den Text für leere Räume komplett neu und kurz auf
			info_text = "ROOM %s - ACTION PLANNING\n" % room_data.room_id
			info_text += "--------------------\n"
			info_text += "ROOM IS COMPLETELY EMPTY."
			
			loot_action_container.hide()
			action_buttons_container.show()
			scan_button.hide(); open_button.hide(); loot_button.show(); scavenge_button.show()
			loot_button.disabled = true
			scavenge_button.disabled = true
		else:
			# Dieser Teil wird nur ausgeführt, wenn der Raum NICHT leer ist
			var max_e_theo = max_investable_energy / RobotState.ENERGY_PER_ELECTRONIC
			var max_s_theo = max_investable_energy / RobotState.ENERGY_PER_SCRAP
			var max_b_theo = max_investable_energy / RobotState.ENERGY_PER_BLUEPRINT
			var max_f_theo = max_investable_energy / RobotState.ENERGY_PER_FOOD

			if room_data.is_scanned:
				max_e_theo = min(max_e_theo, room_data.loot_pool.electronics.current)
				max_s_theo = min(max_s_theo, room_data.loot_pool.scrap_metal.current)
				max_b_theo = min(max_b_theo, room_data.loot_pool.blueprints.current)
				max_f_theo = min(max_f_theo, room_data.loot_pool.food.current)
				info_text += "Potential Scavenge: %d E, %d S\n" % [max_e_theo, max_s_theo]
				info_text += "Potential Loot: %d B, %d F" % [max_b_theo, max_f_theo]
			else:
				info_text += "Potential (Theoretical):\n"
				info_text += "Scavenge: %d E, %d S\n" % [max_e_theo, max_s_theo]
				info_text += "Loot: %d B, %d F" % [max_b_theo, max_f_theo]

			# UI Konfiguration
			loot_slider.max_value = max_investable_energy
			loot_slider.min_value = 0
			loot_slider.value = 0
			_on_loot_slider_changed(0)
			
			loot_action_container.show()
			action_buttons_container.show()
			scan_button.hide(); open_button.hide(); loot_button.show(); scavenge_button.show()
			
			loot_button.disabled = false
			scavenge_button.disabled = false
			
			if room_data.is_scavenge_empty():
				scavenge_button.disabled = true
				info_text += "\n\nScavenge resources depleted."
			if room_data.is_loot_empty():
				loot_button.disabled = true
				info_text += "\n\nLoot items depleted."

			match room_data.looting_state:
				RoomData.LootingState.LOOTING:
					scavenge_button.disabled = true
					if not room_data.is_scavenge_empty():
						info_text += "\n\nLooting in progress. Scavenging locked."
				RoomData.LootingState.SCAVENGING:
					loot_button.disabled = true
					if not room_data.is_loot_empty():
						info_text += "\n\nScavenging in progress. Looting locked."
		
		room_info_label.text = info_text
		if debug_inspector_panel.visible:
			update_debug_inspector()
		return

	# ZUSTAND C: STANDARD-VORSCHAU (NOCH NICHTS GEPLANT)
	else:
		var travel_dist = abs(room_data.distance - last_position_in_plan)
		var travel_cost = travel_dist * RobotState.MOVE_COST_PER_UNIT
		
		var info_text = "ROOM %s PREVIEW:\n" % room_data.room_id
		info_text += "--------------------\n"
		info_text += "Travel Cost to here: %d Energy\n" % travel_cost
		info_text += "Status: %s\n" % ("SCANNED" if room_data.is_scanned else "UNSCANNED")
		
		# NEU: Wenn der Raum gescannt ist, zeige den Inhalt an
		if room_data.is_scanned:
			info_text += "Contents:\n"
			info_text += "  Scavenge: %d E, %d S\n" % [room_data.loot_pool.electronics.current, room_data.loot_pool.scrap_metal.current]
			info_text += "  Loot: %d B, %d F\n" % [room_data.loot_pool.blueprints.current, room_data.loot_pool.food.current]

		var can_scan = false
		if not room_data.is_scanned and not is_action_planned_for_room(room_data.room_id, "SCAN"):
			var total_scan_cost = travel_cost + RobotState.SCAN_COST + (room_data.distance * RobotState.MOVE_COST_PER_UNIT)
			if planned_remaining_energy >= total_scan_cost:
				can_scan = true
		
		var can_open = false
		if not room_data.is_door_open and not is_action_planned_for_room(room_data.room_id, "OPEN"):
			var total_open_cost = travel_cost + room_data.door_strength + (room_data.distance * RobotState.MOVE_COST_PER_UNIT)
			if planned_remaining_energy >= total_open_cost:
				can_open = true

		room_info_label.text = info_text
		
		if can_scan or can_open:
			action_buttons_container.show()
			scan_button.visible = can_scan
			open_button.visible = can_open
			loot_button.hide()
			scavenge_button.hide()
		else:
			action_buttons_container.hide()

		if debug_inspector_panel.visible:
			update_debug_inspector()

func _on_scan_pressed():
	if not current_selected_room: return
	var travel_cost = abs(current_selected_room.distance - last_position_in_plan) * RobotState.MOVE_COST_PER_UNIT
	var action_cost = RobotState.SCAN_COST
	var total_cost = travel_cost + action_cost
	
	if planned_remaining_energy >= total_cost:
		var mission = {
			"type": "SCAN", "room_id": current_selected_room.room_id,
			"cost": total_cost, "target_room": current_selected_room,
			"travel_cost": travel_cost, "action_cost": action_cost
		}
		add_mission_to_plan(mission)


func _on_open_pressed():
	if not current_selected_room: return
	var travel_cost = abs(current_selected_room.distance - last_position_in_plan) * RobotState.MOVE_COST_PER_UNIT
	var action_cost = current_selected_room.door_strength
	var total_cost = travel_cost + action_cost
	
	if planned_remaining_energy >= total_cost:
		var mission = {
			"type": "OPEN", "room_id": current_selected_room.room_id,
			"cost": total_cost, "target_room": current_selected_room,
			"travel_cost": travel_cost, "action_cost": action_cost
		}
		add_mission_to_plan(mission)

func add_mission_to_plan(mission: Dictionary):
	mission_plan.append(mission)
	
	# Aktualisiere die GEPLANTEN Werte
	planned_remaining_energy -= mission.cost
	last_position_in_plan = mission.target_room.distance

	# Aktualisiere die Anzeige des Plans und der Energie
	update_mission_plan_display()
	_update_energy_bar_display()
	
	# --- VEREINFACHTE LOGIK ---
	
	# Wenn die geplante Aktion "OPEN" war...
	if mission.type == "OPEN":
		# ...dann rufe _on_room_selected auf, um die Ansicht
		# SOFORT auf die Loot/Scavenge-Optionen zu aktualisieren.
		_on_room_selected(current_selected_room)
	else:
		# Für ALLE ANDEREN Aktionen (Scan, Loot, Scavenge)
		# setzen wir die UI komplett zurück.
		action_buttons_container.hide()
		loot_action_container.hide()
		room_info_label.text = "Select a room for details."
		current_selected_room = null
		current_selected_button = null
	
func update_mission_plan_display():
	# --- 1. SETUP ---
	var display_text = "Mission Plan:\n"
	display_text += "--------------------\n"
	
	# --- 2. MISSIONEN AUFLISTEN MIT ALLEN DETAILS ---
	for mission in mission_plan:
		# Zeile 1: Hauptaktion und Gesamtkosten für diesen Schritt
		display_text += "> %s Room %s (Total: %d)\n" % [mission.type, mission.room_id, mission.cost]
		
		# --- NEU & WIEDERHERGESTELLT: Die Kostenaufschlüsselung ---
		# Zeige die Details nur an, wenn es auch Kosten gab.
		if mission.cost > 0:
			display_text += "    Travel: %d, Action: %d\n" % [mission.get("travel_cost", 0), mission.get("action_cost", 0)]
		# --------------------------------------------------------

		# Zeile 3 (optional): Potenzielle Beute
		if mission.has("potential_loot"):
			var loot_info = mission.potential_loot
			var loot_string_parts = []
			for key in loot_info:
				if loot_info[key] > 0:
					loot_string_parts.append("%d %s" % [loot_info[key], key])
			if not loot_string_parts.is_empty():
				display_text += "    ~Outcome: " + ", ".join(loot_string_parts) + "\n"

	# --- 3. RÜCKWEG UND ZUSAMMENFASSUNG ---
	var final_return_cost = get_final_return_cost()
	
	if final_return_cost > 0:
		display_text += "--------------------\n"
		display_text += "> Return to Base (Cost: %d)\n" % final_return_cost
	
	var total_actions_cost = RobotState.MAX_ENERGY - planned_remaining_energy
	var total_cost_with_return = total_actions_cost + final_return_cost
	
	display_text += "--------------------\n"
	display_text += "Total Planned Cost: %d" % total_cost_with_return

	# --- 4. FINALES UI-UPDATE ---
	mission_list_label.text = display_text
	remove_last_mission_button.disabled = mission_plan.is_empty()
	
func _update_energy_bar_display():
	# Hole dir die Kosten für den finalen Rückweg
	var return_cost = get_final_return_cost()
	
	# Die WIRKLICH verbleibende Energie ist die Energie nach den Aktionen MINUS dem Rückweg
	var final_remaining_energy = planned_remaining_energy - return_cost
	
	# Aktualisiere den Balken und das Label mit den korrekten Werten
	energy_bar.max_value = RobotState.MAX_ENERGY
	energy_bar.value = final_remaining_energy
	energy_bar_label.text = "Energy: %d / %d" % [final_remaining_energy, RobotState.MAX_ENERGY]

func is_action_planned_for_room(room_id: String, action_type: String) -> bool:
	# Gehe durch jede Mission in unserem Plan
	for mission in mission_plan:
		# Wenn die Raum-ID UND der Aktionstyp übereinstimmen...
		if mission.room_id == room_id and mission.type == action_type:
			# ...dann haben wir sie gefunden! Gib "wahr" zurück.
			return true
	
	# Wenn die Schleife durchläuft, ohne etwas zu finden, gib "falsch" zurück.
	return false

func _on_remove_last_mission():
	# Sicherheitsabfrage: Ist überhaupt eine Mission im Plan?
	if mission_plan.is_empty():
		return

	# 1. Hole die letzte Mission aus der Liste und entferne sie gleichzeitig.
	var removed_mission = mission_plan.pop_back()

	# 2. Gib die reservierte Energie zurück.
	planned_remaining_energy += removed_mission.cost

	# 3. Setze die "last_position_in_plan" zurück.
	#    Wenn der Plan jetzt leer ist, ist die letzte Position wieder 0 (Control Room).
	#    Ansonsten ist es die Position der *jetzt* letzten Mission im Plan.
	if mission_plan.is_empty():
		last_position_in_plan = 0
	else:
		var new_last_mission = mission_plan.back() # .back() holt das letzte Element, ohne es zu entfernen
		last_position_in_plan = new_last_mission.target_room.distance

	# 4. Aktualisiere die gesamte UI.
	update_mission_plan_display()
	_update_energy_bar_display()
	
func _on_loot_pressed():
	if not current_selected_room: return
	var energy_commitment = int(loot_slider.value)
	if planned_remaining_energy < energy_commitment: return
		
	# --- NEU: Potenzielle Beute berechnen ---
	var potential_loot_dict = {}
	var potential_b = energy_commitment / RobotState.ENERGY_PER_BLUEPRINT
	var potential_f = energy_commitment / RobotState.ENERGY_PER_FOOD
	
	if current_selected_room.is_scanned:
		potential_b = min(potential_b, current_selected_room.loot_pool.blueprints.current)
		potential_f = min(potential_f, current_selected_room.loot_pool.food.current)
	
	potential_loot_dict["B"] = potential_b
	potential_loot_dict["F"] = potential_f
	# --- ENDE NEU ---
		
	var mission = {
		"type": "LOOT",
		"room_id": current_selected_room.room_id,
		"cost": energy_commitment,
		"target_room": current_selected_room,
		"potential_loot": potential_loot_dict # <-- NEUER EINTRAG
	}
	add_mission_to_plan(mission)

func _on_scavenge_pressed():
	if not current_selected_room: return
	var energy_commitment = int(loot_slider.value)
	if planned_remaining_energy < energy_commitment: return
		
	# --- NEU: Potenzielle Beute berechnen ---
	var potential_loot_dict = {}
	var potential_e = energy_commitment / RobotState.ENERGY_PER_ELECTRONIC
	var potential_s = energy_commitment / RobotState.ENERGY_PER_SCRAP
	
	if current_selected_room.is_scanned:
		potential_e = min(potential_e, current_selected_room.loot_pool.electronics.current)
		potential_s = min(potential_s, current_selected_room.loot_pool.scrap_metal.current)
	
	potential_loot_dict["E"] = potential_e
	potential_loot_dict["S"] = potential_s
	# --- ENDE NEU ---
		
	var mission = {
		"type": "SCAVENGE",
		"room_id": current_selected_room.room_id,
		"cost": energy_commitment,
		"target_room": current_selected_room,
		"potential_loot": potential_loot_dict # <-- NEUER EINTRAG
	}
	add_mission_to_plan(mission)

func _on_loot_slider_changed(value: float):
	var energy_commitment = int(value)
	var preview_text = "Energy to commit: %d\n" % energy_commitment
	preview_text += "--------------------\n"
	preview_text += "Potential Outcome:\n"

	# --- SCAVENGE BERECHNUNG ---
	# 1. Berechne den theoretischen Ertrag rein aus der Energie
	var theoretical_electronics = energy_commitment / RobotState.ENERGY_PER_ELECTRONIC
	var theoretical_scrap = energy_commitment / RobotState.ENERGY_PER_SCRAP

	# 2. Wenn der Raum gescannt ist, limitiere den Ertrag durch den tatsächlichen Inhalt
	if current_selected_room and current_selected_room.is_scanned:
		theoretical_electronics = min(theoretical_electronics, current_selected_room.loot_pool.electronics.current)
		theoretical_scrap = min(theoretical_scrap, current_selected_room.loot_pool.scrap_metal.current)
	
	preview_text += "Scavenge: ~%d Electronics, ~%d Scrap\n" % [theoretical_electronics, theoretical_scrap]

	# --- LOOT BERECHNUNG ---
	# 1. Berechne den theoretischen Ertrag rein aus der Energie
	var theoretical_blueprints = energy_commitment / RobotState.ENERGY_PER_BLUEPRINT
	var theoretical_food = energy_commitment / RobotState.ENERGY_PER_FOOD
	
	# 2. Wenn der Raum gescannt ist, limitiere den Ertrag
	if current_selected_room and current_selected_room.is_scanned:
		theoretical_blueprints = min(theoretical_blueprints, current_selected_room.loot_pool.blueprints.current)
		theoretical_food = min(theoretical_food, current_selected_room.loot_pool.food.current)
		
	preview_text += "Loot: ~%d Blueprints, ~%d Food" % [theoretical_blueprints, theoretical_food]

	# Setze den Text im Label
	loot_energy_label.text = preview_text
	
func get_max_available_energy_for_action(target_room_distance: int) -> int:
	# 1. Berechne die Kosten für den direkten Rückweg vom Ziel zum Control Room (Distanz 0)
	var return_cost = target_room_distance * RobotState.MOVE_COST_PER_UNIT
	
	# 2. Berechne, wie viel Energie nach dem Rückweg noch übrig wäre
	var energy_after_return = planned_remaining_energy - return_cost
	
	# 3. Gib diesen Wert zurück. Wenn er negativ ist, gib 0 zurück (clamp).
	return max(0, energy_after_return)
	
func get_final_return_cost() -> int:
	# Wenn der Plan leer ist, gibt es keine Rückweg-Kosten.
	if mission_plan.is_empty():
		return 0
	
	# Ansonsten berechne die Kosten vom Ziel der letzten Mission.
	var last_mission = mission_plan.back()
	return last_mission.target_room.distance * RobotState.MOVE_COST_PER_UNIT


func _on_confirm_pressed() -> void:
	get_parent().show_screen("main_menu")

func show_screen():
	# 1. Mache den Screen sichtbar.
	show()
	draw_map()
	# 2. SYNCHRONISIERE DEN ZUSTAND FÜR EINEN NEUEN TAG
	# Wenn der Missionsplan leer ist, bedeutet das, wir beginnen eine neue Planung.
	if mission_plan.is_empty():
		# Hole den frischesten Energiewert vom RobotState.
		planned_remaining_energy = RobotState.current_energy
		
		# KORREKTUR: Setze die Position des Roboters zurück zur Basis!
		last_position_in_plan = 0
	
	# 3. Zeichne die UI basierend auf dem (jetzt korrekten) Zustand neu.
	update_mission_plan_display()
	_update_energy_bar_display()

func is_plan_empty() -> bool:
	return mission_plan.is_empty()


func _on_execute_plan_pressed():
	if mission_plan.is_empty():
		return # Nichts zu tun

	print("--- EXECUTING MISSION PLAN ---")
	
	var collected_loot = {}
	
	# Gehe durch jede geplante Mission
	for mission in mission_plan:
		var room = mission.target_room
		if room.looting_state == RoomData.LootingState.NONE:
			if mission.type == "LOOT":
				room.looting_state = RoomData.LootingState.LOOTING
			elif mission.type == "SCAVENGE":
				room.looting_state = RoomData.LootingState.SCAVENGING
		# Führe die Aktion aus
		match mission.type:
			"SCAN":
				room.is_scanned = true
				print("Room %s is now scanned." % room.room_id)
				
			"OPEN":
				room.is_door_open = true
				print("Door to room %s opened." % room.room_id)
				
			"SCAVENGE":
				var energy_planned = mission.cost
				var energy_actually_spent = 0
				# KORRIGIERT: Verwende RobotState
				var scavenged_e = min(room.loot_pool.electronics.current, energy_planned / RobotState.ENERGY_PER_ELECTRONIC)
				var scavenged_s = min(room.loot_pool.scrap_metal.current, energy_planned / RobotState.ENERGY_PER_SCRAP)
				
				energy_actually_spent += scavenged_e * RobotState.ENERGY_PER_ELECTRONIC
				energy_actually_spent += scavenged_s * RobotState.ENERGY_PER_SCRAP
				
				collected_loot["electronics"] = collected_loot.get("electronics", 0) + scavenged_e
				collected_loot["scrap_metal"] = collected_loot.get("scrap_metal", 0) + scavenged_s
				
				room.loot_pool.electronics.current -= scavenged_e
				room.loot_pool.scrap_metal.current -= scavenged_s
				
				var unused_energy = energy_planned - energy_actually_spent
				if unused_energy > 0:
					collected_loot["energy_refund"] = collected_loot.get("energy_refund", 0) + unused_energy
				
			"LOOT":
				var energy_planned = mission.cost
				var energy_actually_spent = 0
				# KORRIGIERT: Verwende RobotState
				var looted_b = min(room.loot_pool.blueprints.current, energy_planned / RobotState.ENERGY_PER_BLUEPRINT)
				var looted_f = min(room.loot_pool.food.current, energy_planned / RobotState.ENERGY_PER_FOOD)
				
				energy_actually_spent += looted_b * RobotState.ENERGY_PER_BLUEPRINT
				energy_actually_spent += looted_f * RobotState.ENERGY_PER_FOOD
				
				collected_loot["blueprints"] = collected_loot.get("blueprints", 0) + looted_b
				collected_loot["food"] = collected_loot.get("food", 0) + looted_f
				
				room.loot_pool.blueprints.current -= looted_b
				room.loot_pool.food.current -= looted_f
				
				var unused_energy = energy_planned - energy_actually_spent
				if unused_energy > 0:
					collected_loot["energy_refund"] = collected_loot.get("energy_refund", 0) + unused_energy

	# --- FINALE BERECHNUNGEN & ZUSTANDS-UPDATES ---
	
	## 1. Berechne die finalen Energiekosten und aktualisiere den Roboter
	#var total_actions_cost = RobotState.MAX_ENERGY - planned_remaining_energy
	#var return_cost = get_final_return_cost()
	## KORRIGIERT: Verwende RobotState
	#RobotState.current_energy -= (total_actions_cost + return_cost)
	#
	## 2. Füge die gesammelte Beute zum globalen Inventar/Lager hinzu
	#var total_items_collected = 0
	#for item_name in collected_loot:
		#total_items_collected += collected_loot[item_name]
	#
	## KORRIGIERT: Verwende RobotState
	#RobotState.current_storage += total_items_collected # Vereinfachung!
	#
	#
	#
	## 3. Bereite den nächsten Tag vor (Plan zurücksetzen)
	#mission_plan.clear()
	#
	## 4. Zeige den Belohnungs-Screen an
	## WICHTIG: Wir müssen zuerst sicherstellen, dass die ScreenManager-Struktur bereit ist.
	## Siehe Schritt 3 für die Code-Änderungen in anderen Dateien.
	#var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
	#if screen_manager:
		## Hole den RewardScreen Node vom Manager
		#var reward_screen = screen_manager.get_node("RewardScreen")
		#if reward_screen and reward_screen.has_method("show_rewards"):
			#reward_screen.show_rewards(collected_loot)
		#
		## Sage dem Manager, den Screen zu wechseln
		#screen_manager.show_screen("reward")
		# 1. Hole den Energie-Refund sicher aus dem Dictionary.
#    .get() ist der sichere Weg, einen Wert zu holen, ohne einen Fehler zu erzeugen.
	var total_refund = collected_loot.get("energy_refund", 0)

	# 2. Entferne den Refund-Eintrag aus dem Dictionary, damit er nicht
	#    im Reward-Screen als "Beute" angezeigt wird.
	#if collected_loot.has("energy_refund"):
		#collected_loot.erase("energy_refund")

	# 3. Berechne die finalen Energiekosten und aktualisiere den Roboter
	var total_actions_cost = RobotState.MAX_ENERGY - planned_remaining_energy
	var return_cost = get_final_return_cost()

	# Wende zuerst den Refund an, dann ziehe die Kosten ab.
	RobotState.current_energy += total_refund
	RobotState.current_energy -= (total_actions_cost + return_cost)
		
	# 4. Füge die gesammelte Beute zum globalen Lager hinzu
	var total_items_collected = 0
	for item_name in collected_loot:
		total_items_collected += collected_loot[item_name]
	RobotState.current_storage += total_items_collected

	# 5. Bereite den nächsten Tag vor
	mission_plan.clear()
		
	# 6. Zeige den Belohnungs-Screen an
	var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
	if screen_manager:
		var reward_screen = screen_manager.get_node("RewardScreen")
		if reward_screen and reward_screen.has_method("show_rewards"):
			reward_screen.show_rewards(collected_loot)
		screen_manager.show_screen("reward")

# Diese Funktion wird von Godot bei jedem Tastendruck aufgerufen
func _unhandled_input(event: InputEvent):
	# Prüfe, ob die Taste "toggle_debug_view" gerade gedrückt wurde
	if event.is_action_pressed("toggle_debug_view"):
		# Schalte die Sichtbarkeit des Panels um
		debug_inspector_panel.visible = not debug_inspector_panel.visible
		# Akzeptiere das Event, damit es nicht weiterverarbeitet wird
		get_viewport().set_input_as_handled()
		
		# Wenn das Panel jetzt sichtbar ist, aktualisiere die Daten
		if debug_inspector_panel.visible:
			update_debug_inspector()

# Diese Funktion füllt das Debug-Panel mit den Daten des aktuell gewählten Raumes
func update_debug_inspector():
	# Wenn kein Raum ausgewählt ist, zeige eine Standardnachricht
	if not current_selected_room:
		debug_visible_label.text = "No room selected."
		debug_hidden_label.text = ""
		return

	var room = current_selected_room
	
	# --- DATEN, DIE DER SPIELER SIEHT (ODER SEHEN KÖNNTE) ---
	var visible_text = "--- PLAYER VISIBLE DATA ---\n"
	visible_text += "Room ID: %s\n" % room.room_id
	visible_text += "Distance: %d\n" % room.distance
	if room.is_scanned:
		visible_text += "Door Strength: %d\n" % room.door_strength
		visible_text += "Loot (Current/Initial):\n"
		visible_text += "  E: %d/%d, S: %d/%d\n" % [room.loot_pool.electronics.current, room.loot_pool.electronics.initial, room.loot_pool.scrap_metal.current, room.loot_pool.scrap_metal.initial]
		visible_text += "  B: %d/%d, F: %d/%d" % [room.loot_pool.blueprints.current, room.loot_pool.blueprints.initial, room.loot_pool.food.current, room.loot_pool.food.initial]
	else:
		visible_text += "Status: UNSCANNED"
		
	debug_visible_label.text = visible_text
	
	# --- DATEN, DIE VERSTECKT SIND (DIE "WAHRHEIT") ---
	var hidden_text = "\n--- HIDDEN DEBUG DATA ---\n"
	hidden_text += "is_scanned: %s\n" % room.is_scanned
	hidden_text += "is_door_open: %s\n" % room.is_door_open # Annahme, du hast diese Variable hinzugefügt
	hidden_text += "Door Strength (real): %d\n" % room.door_strength
	hidden_text += "Loot Pool (real):\n"
	hidden_text += "  E: %s\n" % str(room.loot_pool.electronics)
	hidden_text += "  S: %s\n" % str(room.loot_pool.scrap_metal)
	hidden_text += "  B: %s\n" % str(room.loot_pool.blueprints)
	hidden_text += "  F: %s\n" % str(room.loot_pool.food)
	
	debug_hidden_label.text = hidden_text

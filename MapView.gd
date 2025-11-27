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
# @onready var mission_planner_label = ... # REMOVED to fix crash
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
@onready var to_robot_equip_button = %toRobotEquip
@onready var to_mainframe_button = %toMainframe
@onready var to_crafting_button = %toCrafting

var planned_remaining_energy: int = 0
var initial_planning_energy: int = 0
var mission_plan: Array[Dictionary] = []
var last_position_in_plan: int = 0
# Eine Instanz unseres Generators.
var current_selected_room: RoomData = null
var current_selected_button: Button = null
var repair_button: Button = null
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
	
	# --- VISUAL OVERHAUL SETUP ---
	_apply_retro_theme()
	
	# 1. Fix "Mission Plan" Label Margin
	# The previous attempt crashed because the label reference was wrong.
	# We will solve the margin issue by adding spaces to the text in update_mission_plan_display instead.
	
	# 2. Robot Energy Bar Cleanup
	energy_bar.show_percentage = false # Remove the "100%" text
	energy_bar.custom_minimum_size.y = 40
	energy_bar_label.add_theme_font_size_override("font_size", 24)
	
	# 3. Create Base Energy Bar (Cyan)
	# We want it near the Robot Energy Bar. Let's find the parent container.
	var energy_container = energy_bar.get_parent()
	
	# Check if we already added it (to prevent duplicates on reload if _ready runs again)
	if not energy_container.has_node("BaseEnergyBar"):
		var base_energy_bar = ProgressBar.new()
		base_energy_bar.name = "BaseEnergyBar"
		base_energy_bar.custom_minimum_size.y = 30 # Slightly smaller than main bar
		base_energy_bar.show_percentage = false
		base_energy_bar.modulate = Color(0, 1, 1) # Cyan
		
		var base_energy_label = Label.new()
		base_energy_label.name = "BaseEnergyLabel"
		base_energy_label.text = "Base Energy: 0 / 0"
		base_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		base_energy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		base_energy_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		base_energy_label.add_theme_font_size_override("font_size", 18)
		base_energy_label.add_theme_color_override("font_color", Color(0, 0, 0)) # Black text for contrast
		
		base_energy_bar.add_child(base_energy_label)
		
		# Add it BEFORE the robot energy bar (so it's on top)
		energy_container.add_child(base_energy_bar)
		energy_container.move_child(base_energy_bar, energy_bar.get_index())
	
	# 4. Create Repair Button dynamically
	if not action_buttons_container.has_node("RepairButton"):
		repair_button = Button.new()
		repair_button.text = "REPAIR FACTORY (50E)"
		repair_button.name = "RepairButton"
		repair_button.pressed.connect(_on_repair_pressed)
		action_buttons_container.add_child(repair_button)
		repair_button.hide()
	else:
		repair_button = action_buttons_container.get_node("RepairButton")
	
	show_screen()

func _apply_retro_theme():
	# Enable BBCode for all text labels
	room_info_label.bbcode_enabled = true
	mission_list_label.bbcode_enabled = true
	loot_energy_label.bbcode_enabled = true
	
	# Load textures (assuming they are in the root or graphics folder)
	# Note: In a real scenario, we'd move these to res://graphics/ui/
	# For now, we check if they exist in the root or use placeholders
	pass # We will rely on the text formatting for now, textures need to be assigned in editor or via code if paths are known.
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
# MapView.gd

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
	# FIX: Factories should NOT enter this block, so they fall through to the Factory Logic below.
	elif is_open_or_planned and room_data.type != RoomData.RoomType.FACTORY:
		# --- B.1: VORBERECHNUNGEN ---
		var max_energy_on_site = get_max_available_energy_for_action(room_data.distance)
		var max_investable_energy = min(max_energy_on_site, RobotState.MAX_STORAGE - RobotState.current_storage)

		# --- B.2: INFO-TEXT AUFBAUEN (RETRO STYLE) ---
		var info_text = "[color=#88ccff][b]ROOM %s - ACTION PLANNING[/b][/color]\n" % room_data.room_id
		info_text += "[color=#555555]--------------------[/color]\n"
		info_text += "Energy on site: [color=#ffff00]%d[/color] | Storage: [color=#ffff00]%d[/color]\n" % [max_energy_on_site, (RobotState.MAX_STORAGE - RobotState.current_storage)]
		info_text += "Max investable Energy: [color=#00ff00]%d[/color]\n" % max_investable_energy
		info_text += "[color=#555555]--------------------[/color]\n"
		
		# --- B.3: UI ANZEIGEN UND KONFIGURIEREN (DIE KOMPLETTE LOGIK) ---
		if room_data.is_completely_empty():
			info_text = "ROOM %s - ACTION PLANNING\n" % room_data.room_id
			info_text += "--------------------\n"
			info_text += "[color=#ff0000][b]ROOM IS COMPLETELY EMPTY[/b][/color]"
			
			loot_action_container.hide()
			action_buttons_container.show()
			scan_button.hide(); open_button.hide(); loot_button.show(); scavenge_button.show()
			repair_button.hide() # FIX: Ensure repair button is hidden!
			loot_button.disabled = true
			scavenge_button.disabled = true
			loot_button.text = "LOOT (EMPTY)"
			scavenge_button.text = "SCAVENGE (EMPTY)"
		else:
			# Reset button text
			loot_button.text = "LOOT"
			scavenge_button.text = "SCAVENGE"
			
			var max_e_theo = max_investable_energy / RobotState.ENERGY_PER_ELECTRONIC
			var max_s_theo = max_investable_energy / RobotState.ENERGY_PER_SCRAP
			var max_b_theo = max_investable_energy / RobotState.ENERGY_PER_BLUEPRINT
			var max_f_theo = max_investable_energy / RobotState.ENERGY_PER_FOOD

			if room_data.is_scanned:
				max_e_theo = min(max_e_theo, room_data.loot_pool["electronics"]["current"])
				max_s_theo = min(max_s_theo, room_data.loot_pool["scrap_metal"]["current"])
				max_b_theo = min(max_b_theo, room_data.loot_pool["blueprints"]["current"])
				max_f_theo = min(max_f_theo, room_data.loot_pool["food"]["current"])
				
				info_text += "Remaining Contents (Max extractable):\n"
				info_text += "  Scavenge: [color=#00ffff]%d E[/color], [color=#aaaaaa]%d S[/color]\n" % [max_e_theo, max_s_theo]
				info_text += "  Loot: [color=#ff00ff]%d B[/color], [color=#ffaa00]%d F[/color]" % [max_b_theo, max_f_theo]
			else:
				info_text += "Potential (Theoretical):\n"
				info_text += "  Scavenge: [color=#00ffff]%d E[/color], [color=#aaaaaa]%d S[/color]\n" % [max_e_theo, max_s_theo]
				info_text += "  Loot: [color=#ff00ff]%d B[/color], [color=#ffaa00]%d F[/color]" % [max_b_theo, max_f_theo]

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
				scavenge_button.text = "SCAVENGE (EMPTY)"
				info_text += "\n\n[color=#ff0000]Scavenge resources depleted.[/color]"
			if room_data.is_loot_empty():
				loot_button.disabled = true
				loot_button.text = "LOOT (EMPTY)"
				info_text += "\n\n[color=#ff0000]Loot items depleted.[/color]"

			match room_data.looting_state:
				RoomData.LootingState.LOOTING:
					scavenge_button.disabled = true
					if not room_data.is_scavenge_empty():
						info_text += "\n\nLooting in progress. Scavenging locked."
				RoomData.LootingState.SCAVENGING:
					loot_button.disabled = true
					if not room_data.is_loot_empty():
						info_text += "\n\nScavenging in progress. Looting locked."
			
			# --- WARNINGS FOR LIMITS ---
			if max_investable_energy == 0:
				if RobotState.MAX_STORAGE - RobotState.current_storage <= 0:
					info_text += "\n\n[color=#ff0000][b]INVENTORY FULL! Return to base to unload.[/b][/color]"
				elif max_energy_on_site <= 0:
					info_text += "\n\n[color=#ff0000][b]INSUFFICIENT ENERGY![/b][/color]"
		
		room_info_label.text = info_text
		if debug_inspector_panel.visible:
			update_debug_inspector()
		return

	# ZUSTAND C: STANDARD-VORSCHAU (NOCH NICHTS GEPLANT)
	else:
		var travel_dist = abs(room_data.distance - last_position_in_plan)
		var travel_cost = travel_dist * RobotState.MOVE_COST_PER_UNIT
		
		var info_text = "[color=#88ccff][b]ROOM %s PREVIEW:[/b][/color]\n" % room_data.room_id
		info_text += "[color=#555555]--------------------[/color]\n"
		info_text += "Travel Cost to here: [color=#ff5555]%d Energy[/color]\n" % travel_cost
		
		# --- FACTORY LOGIC ---
		# Only show factory status if SCANNED!
		if room_data.type == RoomData.RoomType.FACTORY and room_data.is_scanned:
			info_text += "Type: [color=#ffaa00]ANCIENT FACTORY[/color]\n"
			if room_data.is_repaired:
				info_text += "Status: [color=#00ff00]OPERATIONAL[/color]\n"
				info_text += "Providing additional base energy."
				action_buttons_container.hide()
			else:
				# Require Door Open!
				if not room_data.is_door_open and not is_action_planned_for_room(room_data.room_id, "OPEN"):
					info_text += "Status: [color=#ff0000]OFFLINE (LOCKED)[/color]\n"
					info_text += "Door must be opened to access controls.\n"
					
					var can_open = false
					var total_open_cost = travel_cost + room_data.door_strength + (room_data.distance * RobotState.MOVE_COST_PER_UNIT)
					if planned_remaining_energy >= total_open_cost:
						can_open = true
						
					action_buttons_container.show()
					scan_button.hide(); open_button.visible = can_open; loot_button.hide(); scavenge_button.hide(); repair_button.hide()
					
				else:
					info_text += "Status: [color=#ff0000]OFFLINE[/color]\n"
					info_text += "Can be repaired to boost Base Energy (+50).\n"
					info_text += "Repair Cost: [color=#ff5555]50 Energy[/color]\n"
					info_text += "Resources: [color=#aaaaaa]50 Scrap[/color], [color=#00ffff]20 Electronics[/color]"
					
					var can_repair = false
					if not is_action_planned_for_room(room_data.room_id, "REPAIR"):
						var total_repair_cost = travel_cost + 50 + (room_data.distance * RobotState.MOVE_COST_PER_UNIT)
						# Check Energy AND Resources
						if planned_remaining_energy >= total_repair_cost:
							if RobotState.scrap >= 50 and RobotState.electronics >= 20:
								can_repair = true
							else:
								info_text += "\n[color=#ff0000]INSUFFICIENT RESOURCES[/color]"
					
					action_buttons_container.show()
					scan_button.hide(); open_button.hide(); loot_button.hide(); scavenge_button.hide()
					repair_button.visible = true # Always visible so we can see the button
					repair_button.disabled = not can_repair # But disabled if not affordable
					repair_button.text = "REPAIR (50E, 50S, 20E)"
		# --- END FACTORY LOGIC ---
		else:
			# Standard logic for non-factory OR unscanned factory
			info_text += "Status: %s\n" % ("[color=#00ff00]SCANNED[/color]" if room_data.is_scanned else "[color=#ff0000]UNSCANNED[/color]")
			
			if room_data.is_scanned:
				info_text += "Contents:\n"
				info_text += "  Scavenge: [color=#00ffff]%d E[/color], [color=#aaaaaa]%d S[/color]\n" % [room_data.loot_pool["electronics"]["current"], room_data.loot_pool["scrap_metal"]["current"]]
				info_text += "  Loot: [color=#ff00ff]%d B[/color], [color=#ffaa00]%d F[/color]\n" % [room_data.loot_pool["blueprints"]["current"], room_data.loot_pool["food"]["current"]]

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

			if can_scan or can_open:
				action_buttons_container.show()
				scan_button.visible = can_scan
				open_button.visible = can_open
				loot_button.hide()
				scavenge_button.hide()
				repair_button.hide()
			else:
				action_buttons_container.hide()

		room_info_label.text = info_text
		
		if debug_inspector_panel.visible:
			update_debug_inspector()

func _on_scan_pressed():
	if not current_selected_room: return
	var travel_cost = abs(current_selected_room.distance - last_position_in_plan) * RobotState.MOVE_COST_PER_UNIT
	var action_cost = RobotState.SCAN_COST
	var total_cost = travel_cost + action_cost
	
	# FIX: Ensure we can return home!
	var new_return_cost = current_selected_room.distance * RobotState.MOVE_COST_PER_UNIT
	
	if planned_remaining_energy >= total_cost + new_return_cost:
		var mission = {
			"type": "SCAN", "room_id": current_selected_room.room_id,
			"cost": total_cost, "target_room": current_selected_room,
			"travel_cost": travel_cost, "action_cost": action_cost
		}
		add_mission_to_plan(mission)
	else:
		print("Cannot plan SCAN: Insufficient energy for action + return trip.")


func _on_open_pressed():
	if not current_selected_room: return
	var travel_cost = abs(current_selected_room.distance - last_position_in_plan) * RobotState.MOVE_COST_PER_UNIT
	var action_cost = current_selected_room.door_strength
	var total_cost = travel_cost + action_cost
	
	# FIX: Ensure we can return home!
	var new_return_cost = current_selected_room.distance * RobotState.MOVE_COST_PER_UNIT
	
	if planned_remaining_energy >= total_cost + new_return_cost:
		var mission = {
			"type": "OPEN", "room_id": current_selected_room.room_id,
			"cost": total_cost, "target_room": current_selected_room,
			"travel_cost": travel_cost, "action_cost": action_cost
		}
		add_mission_to_plan(mission)
	else:
		print("Cannot plan OPEN: Insufficient energy for action + return trip.")

func _on_repair_pressed():
	if not current_selected_room: return
	
	# FIX: Validate resources and state before planning
	if current_selected_room.is_repaired: return
	if RobotState.scrap < 50 or RobotState.electronics < 20: return
	
	var travel_cost = abs(current_selected_room.distance - last_position_in_plan) * RobotState.MOVE_COST_PER_UNIT
	var action_cost = 50 # Fixed cost
	var total_cost = travel_cost + action_cost
	
	# FIX: Ensure we can return home!
	var new_return_cost = current_selected_room.distance * RobotState.MOVE_COST_PER_UNIT
	
	if planned_remaining_energy >= total_cost + new_return_cost:
		var mission = {
			"type": "REPAIR", "room_id": current_selected_room.room_id,
			"cost": total_cost, "target_room": current_selected_room,
			"travel_cost": travel_cost, "action_cost": action_cost
		}
		add_mission_to_plan(mission)
	else:
		print("Cannot plan REPAIR: Insufficient energy for action + return trip.")

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
	# ADDED PADDING SPACE TO FIX MARGIN ISSUE
	var display_text = "[color=#ffffff][b]Mission Plan:[/b][/color]\n"
	display_text += " [color=#555555]--------------------[/color]\n"
	
	# --- 2. MISSIONEN AUFLISTEN MIT ALLEN DETAILS ---
	for mission in mission_plan:
		# Zeile 1: Hauptaktion und Gesamtkosten für diesen Schritt
		display_text += " > [color=#ffff00]%s[/color] Room %s (Total: [color=#ff5555]%d[/color])\n" % [mission.type, mission.room_id, mission.cost]
		
		# --- NEU & WIEDERHERGESTELLT: Die Kostenaufschlüsselung ---
		# Zeige die Details nur an, wenn es auch Kosten gab.
		if mission.cost > 0:
			display_text += "     [color=#aaaaaa]Travel: %d, Action: %d[/color]\n" % [mission.get("travel_cost", 0), mission.get("action_cost", 0)]
		# --------------------------------------------------------

		# Zeile 3 (optional): Potenzielle Beute
		if mission.has("potential_loot"):
			var loot_info = mission.potential_loot
			var loot_string_parts = []
			for key in loot_info:
				if loot_info[key] > 0:
					loot_string_parts.append("%d %s" % [loot_info[key], key])
			if not loot_string_parts.is_empty():
				display_text += "     [color=#00ff00]~Outcome: " + ", ".join(loot_string_parts) + "[/color]\n"

	# --- 3. RÜCKWEG UND ZUSAMMENFASSUNG ---
	var final_return_cost = get_final_return_cost()
	
	if final_return_cost > 0:
		display_text += " [color=#555555]--------------------[/color]\n"
		display_text += " > Return to Base (Cost: [color=#ff5555]%d[/color])\n" % final_return_cost
	
	# FIX: Calculate total cost by summing missions, NOT by comparing to MAX_ENERGY
	# This prevents "ghost costs" when starting with partial energy.
	var total_actions_cost = 0
	for mission in mission_plan:
		total_actions_cost += mission.cost
		
	var total_cost_with_return = total_actions_cost + final_return_cost
	
	display_text += " [color=#555555]--------------------[/color]\n"
	display_text += " Total Planned Cost: [color=#ff5555]%d[/color]" % total_cost_with_return

	# --- 4. FINALES UI-UPDATE ---
	mission_list_label.text = display_text
	remove_last_mission_button.disabled = mission_plan.is_empty()
	to_robot_equip_button.disabled = not mission_plan.is_empty()
	to_mainframe_button.disabled = not mission_plan.is_empty()
	to_crafting_button.disabled = not mission_plan.is_empty()


func _update_energy_bar_display():
	# Hole dir die Kosten für den finalen Rückweg
	var return_cost = get_final_return_cost()
	
	# Die WIRKLICH verbleibende Energie ist die Energie nach den Aktionen MINUS dem Rückweg
	var final_remaining_energy = planned_remaining_energy - return_cost
	
	# Aktualisiere den Balken und das Label mit den korrekten Werten
	energy_bar.max_value = RobotState.MAX_ENERGY
	energy_bar.value = final_remaining_energy
	energy_bar_label.text = "Robot Energy: %d / %d" % [final_remaining_energy, RobotState.MAX_ENERGY]
	
	# --- UPDATE BASE ENERGY BAR ---
	var energy_container = energy_bar.get_parent()
	var base_bar = energy_container.get_node_or_null("BaseEnergyBar")
	if base_bar:
		base_bar.max_value = RobotState.base_max_energy
		base_bar.value = RobotState.base_energy_current
		var base_label = base_bar.get_node_or_null("BaseEnergyLabel")
		if base_label:
			base_label.text = "Base Energy: %d / %d" % [RobotState.base_energy_current, RobotState.base_max_energy]

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
	
	# FIX: Calculate Travel Cost!
	var travel_cost = abs(current_selected_room.distance - last_position_in_plan) * RobotState.MOVE_COST_PER_UNIT
	var total_cost = travel_cost + energy_commitment
	
	# FIX: Ensure we can return home!
	var new_return_cost = current_selected_room.distance * RobotState.MOVE_COST_PER_UNIT
	
	if planned_remaining_energy < total_cost + new_return_cost:
		print("Cannot plan LOOT: Insufficient energy for travel + action + return trip.")
		return
		
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
		"cost": total_cost, # Includes travel now!
		"target_room": current_selected_room,
		"travel_cost": travel_cost,
		"action_cost": energy_commitment,
		"potential_loot": potential_loot_dict
	}
	add_mission_to_plan(mission)

func _on_scavenge_pressed():
	if not current_selected_room: return
	var energy_commitment = int(loot_slider.value)
	
	# FIX: Calculate Travel Cost!
	var travel_cost = abs(current_selected_room.distance - last_position_in_plan) * RobotState.MOVE_COST_PER_UNIT
	var total_cost = travel_cost + energy_commitment
	
	# FIX: Ensure we can return home!
	var new_return_cost = current_selected_room.distance * RobotState.MOVE_COST_PER_UNIT
	
	if planned_remaining_energy < total_cost + new_return_cost:
		print("Cannot plan SCAVENGE: Insufficient energy for travel + action + return trip.")
		return
		
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
		"cost": total_cost, # Includes travel now!
		"target_room": current_selected_room,
		"travel_cost": travel_cost,
		"action_cost": energy_commitment,
		"potential_loot": potential_loot_dict
	}
	add_mission_to_plan(mission)

func _on_loot_slider_changed(value: float):
	var energy_commitment = int(value)
	var preview_text = "Energy to commit: [color=#ffff00]%d[/color]\n" % energy_commitment
	preview_text += "[color=#555555]--------------------[/color]\n"
	preview_text += "Potential Outcome:\n"

	# --- SCAVENGE BERECHNUNG ---
	# 1. Berechne den theoretischen Ertrag rein aus der Energie
	var theoretical_electronics = energy_commitment / RobotState.ENERGY_PER_ELECTRONIC
	var theoretical_scrap = energy_commitment / RobotState.ENERGY_PER_SCRAP

	# 2. Wenn der Raum gescannt ist, limitiere den Ertrag durch den tatsächlichen Inhalt
	if current_selected_room and current_selected_room.is_scanned:
		theoretical_electronics = min(theoretical_electronics, current_selected_room.loot_pool.electronics.current)
		theoretical_scrap = min(theoretical_scrap, current_selected_room.loot_pool.scrap_metal.current)
	
	preview_text += "Scavenge: [color=#00ffff]~%d Electronics[/color], [color=#aaaaaa]~%d Scrap[/color]\n" % [theoretical_electronics, theoretical_scrap]

	# --- LOOT BERECHNUNG ---
	# 1. Berechne den theoretischen Ertrag rein aus der Energie
	var theoretical_blueprints = energy_commitment / RobotState.ENERGY_PER_BLUEPRINT
	var theoretical_food = energy_commitment / RobotState.ENERGY_PER_FOOD
	
	# 2. Wenn der Raum gescannt ist, limitiere den Ertrag
	if current_selected_room and current_selected_room.is_scanned:
		theoretical_blueprints = min(theoretical_blueprints, current_selected_room.loot_pool.blueprints.current)
		theoretical_food = min(theoretical_food, current_selected_room.loot_pool.food.current)
		
	preview_text += "Loot: [color=#ff00ff]~%d Blueprints[/color], [color=#ffaa00]~%d Food[/color]" % [theoretical_blueprints, theoretical_food]

	# Setze den Text im Label
	loot_energy_label.text = preview_text
	
func get_max_available_energy_for_action(target_room_distance: int) -> int:
	# 1. Berechne die Kosten für den Hinweg von der letzten geplanten Position
	var travel_cost = abs(target_room_distance - last_position_in_plan) * RobotState.MOVE_COST_PER_UNIT
	
	# 2. Berechne die Kosten für den direkten Rückweg vom Ziel zum Control Room (Distanz 0)
	var return_cost = target_room_distance * RobotState.MOVE_COST_PER_UNIT
	
	# 3. Berechne, wie viel Energie nach Hin- und Rückweg noch übrig wäre
	var energy_after_travel_and_return = planned_remaining_energy - travel_cost - return_cost
	
	# 4. Gib diesen Wert zurück. Wenn er negativ ist, gib 0 zurück (clamp).
	return max(0, energy_after_travel_and_return)
	
func get_final_return_cost() -> int:
	# Wenn der Plan leer ist, gibt es keine Rückweg-Kosten.
	if mission_plan.is_empty():
		return 0
	
	# Ansonsten berechne die Kosten vom Ziel der letzten Mission.
	var last_mission = mission_plan.back()
	return last_mission.target_room.distance * RobotState.MOVE_COST_PER_UNIT


func show_screen():
	# 1. Mache den Screen sichtbar.
	show()
	draw_map()
	# 2. SYNCHRONISIERE DEN ZUSTAND FÜR EINEN NEUEN TAG
	# Wenn der Missionsplan leer ist, bedeutet das, wir beginnen eine neue Planung.
	if mission_plan.is_empty():
		# Hole den frischesten Energiewert vom RobotState.
		planned_remaining_energy = RobotState.current_energy
		initial_planning_energy = RobotState.current_energy
		
		# KORREKTUR: Setze die Position des Roboters zurück zur Basis!
		last_position_in_plan = 0
	
	# 3. Zeichne die UI basierend auf dem (jetzt korrekten) Zustand neu.
	update_mission_plan_display()
	_update_energy_bar_display()

func is_plan_empty() -> bool:
	return mission_plan.is_empty()

# --- NAVIGATION SAFETY ---
func can_leave_screen() -> bool:
	# We cannot leave if there is an active mission plan
	return is_plan_empty()

func get_leave_warning() -> String:
	return "Cannot leave while a mission is planned. Please clear the plan or execute it first."


func _on_execute_plan_pressed():
	if mission_plan.is_empty():
		# --- END DAY LOGIC ---
		# If plan is empty, this button acts as "End Day" / "Sleep"
		# We trigger the reward screen with empty loot to simulate end of day
		print("--- ENDING DAY (NO MISSIONS) ---")
		var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
		if screen_manager:
			var reward_screen = screen_manager.get_node("RewardScreen")
			if reward_screen and reward_screen.has_method("show_rewards"):
				reward_screen.show_rewards({}) # Empty loot
			screen_manager.show_screen("reward")
		return

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
				
				# Add to collected loot for Reward Screen
				if not collected_loot.has("scanned_rooms"):
					collected_loot["scanned_rooms"] = []
				collected_loot["scanned_rooms"].append(room)
				
				# Trigger Animation
				var block = find_room_block(room.room_id)
				if block and block.has_method("play_scan_animation"):
					block.play_scan_animation()
				
			"OPEN":
				room.is_door_open = true
				print("Door to room %s opened." % room.room_id)
				
			"REPAIR":
				# FIX: Prevent infinite repair and resource cheating
				if room.is_repaired:
					print("Room %s is already repaired. Skipping." % room.room_id)
					continue # Skip this mission
					
				if RobotState.scrap < 50 or RobotState.electronics < 20:
					print("Insufficient resources to repair Room %s. Skipping." % room.room_id)
					continue # Skip this mission

				room.is_repaired = true
				
				# Deduct Resources
				RobotState.scrap -= 50
				RobotState.electronics -= 20
				RobotState.emit_signal("resources_changed")
				
				RobotState.increase_base_energy(50)
				print("Factory in room %s repaired. Base Energy Increased by 50." % room.room_id)
				
			"SCAVENGE":
				# --- ACCIDENTAL DESTRUCTION LOGIC ---
				if room.type == RoomData.RoomType.FACTORY:
					room.type = RoomData.RoomType.STANDARD
					print("WARNING: Ancient Factory in Room %s destroyed by scavenging!" % room.room_id)
				# ------------------------------------

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
				
				# var unused_energy = energy_planned - energy_actually_spent # Unused

				# FIX: The travel cost is NOT refundable! Only the action cost part.
				var travel_cost = mission.get("travel_cost", 0)
				var action_budget = energy_planned - travel_cost
				
				var unused_action_energy = action_budget - energy_actually_spent

				if unused_action_energy > 0:
					collected_loot["energy_refund"] = collected_loot.get("energy_refund", 0) + unused_action_energy
				
			"LOOT":
				# --- ACCIDENTAL DESTRUCTION LOGIC ---
				if room.type == RoomData.RoomType.FACTORY:
					room.type = RoomData.RoomType.STANDARD
					print("WARNING: Ancient Factory in Room %s destroyed by looting!" % room.room_id)
				# ------------------------------------

				var energy_planned = mission.cost
				var energy_actually_spent = 0
				# KORRIGIERT: Verwende RobotState
				var looted_b = min(room.loot_pool.blueprints.current, energy_planned / RobotState.ENERGY_PER_BLUEPRINT)
				var looted_f = min(room.loot_pool.food.current, energy_planned / RobotState.ENERGY_PER_FOOD)
				
				energy_actually_spent += looted_b * RobotState.ENERGY_PER_BLUEPRINT
				energy_actually_spent += looted_b * RobotState.ENERGY_PER_BLUEPRINT
				energy_actually_spent += looted_f * RobotState.ENERGY_PER_FOOD
				
				# collected_loot["blueprints"] = collected_loot.get("blueprints", 0) + looted_b # OLD INT LOGIC
				
				# NEW LOGIC: Generate actual blueprint items
				if looted_b > 0:
					if not collected_loot.has("blueprints"):
						collected_loot["blueprints"] = []
					
					for i in range(looted_b):
						var bp = RobotState.get_random_blueprint()
						if bp:
							collected_loot["blueprints"].append(bp)
				
				collected_loot["food"] = collected_loot.get("food", 0) + looted_f
				
				room.loot_pool.blueprints.current -= looted_b
				room.loot_pool.food.current -= looted_f
				
				# var unused_energy = energy_planned - energy_actually_spent # Unused
				
				# FIX: The travel cost is NOT refundable! Only the action cost part.
				var travel_cost = mission.get("travel_cost", 0)
				var action_budget = energy_planned - travel_cost
				
				var unused_action_energy = action_budget - energy_actually_spent

				if unused_action_energy > 0:
					collected_loot["energy_refund"] = collected_loot.get("energy_refund", 0) + unused_action_energy

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
	var total_actions_cost = initial_planning_energy - planned_remaining_energy
	var return_cost = get_final_return_cost()

	# Wende zuerst den Refund an, dann ziehe die Kosten ab.
	RobotState.current_energy += total_refund
	RobotState.current_energy -= (total_actions_cost + return_cost)
		
	# 4. Füge die gesammelte Beute zum globalen Lager hinzu
	var total_items_collected = 0
	for item_name in collected_loot:
		var val = collected_loot[item_name]
		if val is int or val is float:
			total_items_collected += int(val)
		elif val is Array:
			total_items_collected += val.size()
			
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
			
	# --- DEBUG CHEAT: F8 to test Reward Screen ---
	if event is InputEventKey and event.pressed and event.keycode == KEY_F8:
		print("DEBUG: Triggering Fake Reward Screen")
		var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
		if screen_manager:
			var reward_screen = screen_manager.get_node("RewardScreen")
			if reward_screen:
				# Create a fake legendary item
				var fake_item = load("res://items/mini_fusion_reactor.tres") # Assuming this exists and is legendary
				if not fake_item:
					# Fallback if specific item not found
					fake_item = RobotState.all_items_cache.pick_random()
				
				var fake_loot = {
					"scrap_metal": 123,
					"electronics": 45,
					"food": 12,
					"blueprints": [fake_item]
				}
				reward_screen.show_rewards(fake_loot)
				screen_manager.show_screen("reward")

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

func _on_to_robot_equip_pressed() -> void:
	if is_plan_empty():
		var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
		if screen_manager:
			screen_manager.show_screen("equipment")

func _on_to_mainframe_pressed() -> void:
	if is_plan_empty():
		var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
		if screen_manager:
			screen_manager.show_screen("mainframe")

func _on_to_crafting_pressed() -> void:
	if is_plan_empty():
		var screen_manager = get_tree().get_first_node_in_group("ScreenManager")
		if screen_manager:
			screen_manager.show_screen("crafting")

func find_room_block(room_id: String) -> Node:
	var all_containers = top_row_container.get_children() + bottom_row_container.get_children()
	for placeholder in all_containers:
		# Placeholder is CenterContainer, child is RoomBlock
		if placeholder.get_child_count() > 0:
			var block = placeholder.get_child(0)
			if block.get("room_data") and block.room_data.room_id == room_id:
				return block
	return null

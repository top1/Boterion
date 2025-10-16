# RobotEquipScreen.gd 
extends Control
class_name RobotEquipScreen
signal screen_closed
var current_energy_bonus: int = 0
var current_storage_bonus: int = 0

@onready var head_slot: EquipSlot = $MainLayout/RobotPanel/HeadSlot
@onready var left_arm_slot: EquipSlot = $MainLayout/RobotPanel/LeftArm
@onready var right_arm_slot: EquipSlot = $MainLayout/RobotPanel/RightArm
@onready var body_slot_1: EquipSlot = $MainLayout/RobotPanel/BodySlot
@onready var body_slot_2: EquipSlot = $MainLayout/RobotPanel/BodySlot2
@onready var body_slot_3: EquipSlot = $MainLayout/RobotPanel/BodySlot3
@onready var body_slot_4: EquipSlot = $MainLayout/RobotPanel/BodySlot4

@onready var stats_label: Label = $MainLayout/RobotPanel/StatsPanel/StatsLabel

func _ready():
	# --- This code runs ONCE when the screen loads ---
	# Assign allowed item types via code
	head_slot.allowed_item_types = ["SCANNER"]
	left_arm_slot.allowed_item_types = ["TOOLS"]
	right_arm_slot.allowed_item_types = ["TOOLS"]
	body_slot_1.allowed_item_types = ["BATTERY", "STORAGE"]
	body_slot_2.allowed_item_types = ["BATTERY", "STORAGE"]
	body_slot_3.allowed_item_types = ["BATTERY", "STORAGE"]
	body_slot_4.allowed_item_types = ["BATTERY", "STORAGE"]
	
	# Calculate stats for the first time
	update_robot_stats()

# --- UI CONTROL FUNCTIONS ---

func show_screen():
	show()
	update_robot_stats() # Update stats every time the screen is opened

func _on_confirm_button_pressed() -> void:
	RobotState.update_equipment_bonuses(current_energy_bonus, current_storage_bonus)
	get_parent().get_parent().show_screen("main_menu")

# --- SAFETY NET DROP LOGIC (for the background) ---

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("type") and data["type"] == "inventory_item"

func _drop_data(at_position: Vector2, data: Variant):
	# A drop on the background is a "cancel". Return the item to its source.
	var source_slot = data["source_slot"]
	var item_resource: Item = data["item_resource"]
	
	if source_slot is EquipSlot:
		source_slot.current_equipped_item = item_resource
	else:
		source_slot.item = item_resource
	
	source_slot.update_display()
	# We must also update stats here, in case an equipped item was returned
	update_robot_stats()

# --- STATS CALCULATION ---

func update_robot_stats():
	var total_stats = {
		"energy": 0,
		"storage": 0
	}
	
	var all_equip_slots = [head_slot, left_arm_slot, right_arm_slot, body_slot_1, body_slot_2, body_slot_3, body_slot_4]
	
	for slot in all_equip_slots:
		if slot.current_equipped_item:
			var modifiers = slot.current_equipped_item.stats_modifier
			for stat_name in modifiers:
				var modifier_value = modifiers[stat_name]
				total_stats[stat_name] = total_stats.get(stat_name, 0) + modifier_value
	
	display_stats(total_stats)

func display_stats(stats: Dictionary):
	var stats_text = "ROBOT STATS:\n"
	for stat_name in stats:
		stats_text += "- %s: %s\n" % [stat_name.capitalize(), stats[stat_name]]
	stats_label.text = stats_text
	self.current_energy_bonus = stats.get("energy", 0)
	self.current_storage_bonus = stats.get("storage", 0)

# Robot.gd
extends RefCounted # Use RefCounted for pure data classes

# --- Define the Gear classes inside the Robot script for organization ---
class Gear:
	var name: String
	var description: String
	var build_cost: Dictionary

	func _init(p_name, p_description, p_build_cost):
		self.name = p_name
		self.description = p_description
		self.build_cost = p_build_cost

class Battery extends Gear:
	var capacity: int

	func _init(p_name, p_description, p_build_cost, p_capacity):
		super._init(p_name, p_description, p_build_cost)
		self.capacity = p_capacity

class Storage extends Gear:
	var storage_slots: int

	func _init(p_name, p_description, p_build_cost, p_storage_slots):
		super._init(p_name, p_description, p_build_cost)
		self.storage_slots = p_storage_slots

class Tool extends Gear:
	var efficiency: Dictionary

	func _init(p_name, p_description, p_build_cost, p_efficiency):
		super._init(p_name, p_description, p_build_cost)
		self.efficiency = p_efficiency

# --- The main Robot class ---
var gear_slots = {"battery": null, "storage": null, "tool_primary": null}
var max_battery: int = 0
var current_battery: int = 0
var max_storage: int = 0
var move_cost: int = 5
var position: int = 0

func equip(slot: String, gear_item):
	gear_slots[slot] = gear_item
	_calculate_stats()

func _calculate_stats():
	max_battery = gear_slots.battery.capacity if gear_slots.battery else 0
	max_storage = gear_slots.storage.storage_slots if gear_slots.storage else 0
	current_battery = min(current_battery, max_battery)

func charge(amount: int):
	current_battery = min(max_battery, current_battery + amount)

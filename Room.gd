# Room.gd

class_name Room
extends RefCounted

var room_id: int
var type_name: String
var size: int
var description: String
var door_type: String
var scavenge_table: Dictionary
var loot_table: Dictionary

func _init(p_room_id, p_type_name, p_size, p_game_data):
	self.room_id = p_room_id
	self.type_name = p_type_name
	self.size = p_size
	
	var archetype = p_game_data.ROOM_ARCHETYPES[p_type_name]
	self.description = archetype.description
	self.scavenge_table = archetype.scavenge_table
	self.loot_table = archetype.loot_table
	
	# Determine door type
	self.door_type = "Standard"
	var rand_val = randf() # Godot's way of getting a random float 0-1
	if rand_val < 0.2: self.door_type = "Electronic"
	elif rand_val < 0.3: self.door_type = "Barricaded" # Adjusted for sequential checks

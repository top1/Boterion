# item.gd
class_name Item extends Resource

@export var item_name: String = "New Item"
@export var item_texture: Texture2D # The icon to display
@export var item_type: String = "NONE" # e.g., "TOOL", "BATTERY", "STORAGE", "SCANNER"
@export var stats_modifier: Dictionary = {} # e.g., {"attack": 5, "defense": 2}
@export var blueprint_id: String = ""
@export var crafting_recipe: Dictionary = {} # e.g., {"scrap": 10, "electronics": 5, "energy": 50}

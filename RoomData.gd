# RoomData.gd
class_name RoomData extends Resource

enum RoomType {
	STANDARD,
	TEC,
	HABITAT,
	FACTORY,
}

enum LootingState {NONE, LOOTING, SCAVENGING}
@export var looting_state: LootingState = LootingState.NONE
@export var is_repaired: bool = false
# --- Alte Eigenschaften ---
@export var size: int = 1
@export var type: RoomType = RoomType.STANDARD
@export var room_id: String = ""
@export var distance: int = 0

# --- Neue Eigenschaften ---

# Tür-Eigenschaften
@export var door_strength: int = 0

# Scan-Status
@export var is_scanned: bool = false

# Beute, die im Raum vorhanden ist.
@export var loot_pool: Dictionary = {
	"electronics": {"initial": 0, "current": 0},
	"scrap_metal": {"initial": 0, "current": 0},
	"blueprints": {"initial": 0, "current": 0},
	"food": {"initial": 0, "current": 0}
}
@export var blueprint_items: Array[Resource] = [] # Array of Item resources
@export var is_door_open: bool = false

# KORRIGIERT: Zugriff mit ["key"] statt mit .key
func is_scavenge_empty() -> bool:
	return loot_pool["electronics"]["current"] == 0 and loot_pool["scrap_metal"]["current"] == 0

# KORRIGIERT: Zugriff mit ["key"] statt mit .key
func is_loot_empty() -> bool:
	return loot_pool["blueprints"]["current"] == 0 and loot_pool["food"]["current"] == 0

# KORRIGIERT: Fehlendes 'return' hinzugefügt
func is_completely_empty() -> bool:
	return is_scavenge_empty() and is_loot_empty()

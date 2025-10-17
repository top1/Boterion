# RoomData.gd
class_name RoomData extends Resource

enum RoomType {
	STANDARD,
	TEC,
	HABITAT,
}

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
# Jede Ressource bekommt ein eigenes Dictionary mit dem Anfangs- und aktuellen Wert.
@export var loot_pool: Dictionary = {
	"electronics": {"initial": 0, "current": 0},
	"scrap_metal": {"initial": 0, "current": 0},
	"blueprints": {"initial": 0, "current": 0},
	"food": {"initial": 0, "current": 0}
}
@export var is_door_open: bool = false

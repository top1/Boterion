extends Resource
class_name Artifact

@export var id: String = ""
@export var name: String = "Unknown Artifact"
@export_multiline var description: String = "A mysterious object."
@export var icon: Texture2D
@export var rarity: String = "COMMON" # COMMON, RARE, EPIC, LEGENDARY

enum EffectType {
	NONE,
	REDUCE_MOVE_COST,
	REDUCE_SCAN_COST,
	REDUCE_DOOR_COST,
	INCREASE_LOOT_SCRAP,
	INCREASE_LOOT_ELEC,
	INCREASE_LOOT_FOOD,
	INCREASE_LOOT_BLUEPRINT,
	ENERGY_REGEN,
	STORAGE_CAPACITY
}

@export var effect_type: EffectType = EffectType.NONE
@export var effect_value: float = 0.0

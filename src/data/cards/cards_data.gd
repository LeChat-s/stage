class_name CardData
extends Resource

enum TargetType { ENEMY, SELF, ALL_ENEMIES, ALL_HEROES }

@export var id: String
@export var name: String
@export var dmg: int = 0
@export var shild: int = 0
@export var cost: int = 1
@export var type: String
@export var target_type: TargetType = TargetType.ENEMY
@export var effects: Array[Dictionary] = [] 
@export var description: String

@export var effect_type: String
@export var artwork: Texture2D

func has_effect(effect_id: String) -> bool:
	for effect in effects:
		if effect.get("id", "") == effect_id:
			return true
	return false

func get_effect_data(effect_id: String) -> Dictionary:
	for effect in effects:
		if effect.get("id", "") == effect_id:
			return effect
	return {}

@tool
class_name CardData
extends Resource

enum TargetType { ENEMY, SELF, ALL_ENEMIES, ALL_HEROES }

@export var id: String
@export var name: String
@export var dmg: int = 0
@export var damage_type: GameStateClass.DamageType = GameStateClass.DamageType.PHYSICAL
@export var shild: int = 0
@export var cost: int = 1
@export var type: String
@export var target_type: TargetType = TargetType.ENEMY
@export var effects: Array[Dictionary] = []
@export var description: String

@export_category("Билд")
@export var build_id: StringName = &""
@export var contamination: ContaminationData

@export_category("Визуал")
@export var effect_type: String
# Artwork теперь означает внутреннюю иллюстрацию.
# Старые *_base.png поддерживаются как legacy и автоматически игнорируются
# как иллюстрация: рамка выбирается по type.
@export var artwork: Texture2D

@export_category("Текст карты")
@export_range(6, 32, 1) var title_font_size: int = 11
@export var title_color: Color = Color("#f8eef5")
@export_range(5, 24, 1) var description_font_size: int = 7
@export var description_color: Color = Color("#3b2938")
@export_range(8, 40, 1) var cost_font_size: int = 18
@export var cost_color: Color = Color("#342637")
@export_range(6, 24, 1) var stats_font_size: int = 8
@export var stats_color: Color = Color("#3b2938")

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

@tool
class_name AbilityData
extends Resource

enum TargetType { ENEMY, SELF, ALL_ENEMIES, ALL_HEROES }
enum DamageType { PHYSICAL, MAGIC, PSYCHIC }

@export var id: StringName = &""
@export var display_name: String = "Новая способность"
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_category("Стоимость")
@export_range(0, 99, 1) var energy_cost: int = 0
@export_range(0, 99, 1) var resource_cost: int = 0
@export_range(0, 99, 1) var cooldown: int = 0
@export var consumes_turn: bool = true

@export_category("Базовый эффект")
@export var target_type: TargetType = TargetType.ENEMY
@export var damage: int = 0
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var block: int = 0
@export var effects: Array[Dictionary] = []

@tool
class_name BuildBalanceData
extends Resource

@export_category("Модификаторы")
@export_range(0.25, 3.0, 0.05) var damage_multiplier: float = 1.0
@export_range(0.25, 3.0, 0.05) var block_multiplier: float = 1.0
@export_range(0.25, 2.0, 0.05) var incoming_damage_multiplier: float = 1.0

@export_category("Базовые параметры")
@export_range(-100, 500, 1) var max_hp_bonus: int = 0
@export_range(-5, 10, 1) var energy_bonus: int = 0

@export_multiline var balance_notes: String = ""

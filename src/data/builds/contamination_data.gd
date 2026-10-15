@tool
class_name ContaminationData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "Новый билд"
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_category("Внешность героя")
@export var player_sprite_sheet: Texture2D
@export_range(1, 64, 1) var player_hframes: int = 1
@export_range(1, 64, 1) var player_vframes: int = 1
@export var idle_frames: PackedInt32Array = PackedInt32Array()
@export_range(1.0, 60.0, 0.5) var idle_fps: float = 8.0
@export var attack_frames: PackedInt32Array = PackedInt32Array()
@export_range(1.0, 60.0, 0.5) var attack_fps: float = 12.0
@export var sprite_offset: Vector2 = Vector2(0.0, -65.0)
@export var sprite_scale: Vector2 = Vector2(2.0, 2.0)

@export_category("Баланс")
@export var balance: BuildBalanceData

@export_category("Ресурс билда")
@export var resource_id: StringName = &""
@export var resource_display_name: String = ""
@export var resource_icon: Texture2D
@export_range(0, 999, 1) var resource_start: int = 0
@export_range(0, 999, 1) var resource_max: int = 99

@export_category("Карты")
@export var activation_card_id: String = ""
@export var starting_cards: Array[Resource] = []
@export var exclusive_cards: Array[Resource] = []

@export_category("Способности")
@export var abilities: Array[AbilityData] = []

@export_category("Пассивные способности")
@export var passives: Array[PassiveData] = []

func get_ability(index: int) -> AbilityData:
	if index < 0 or index >= abilities.size():
		return null
	return abilities[index]

func get_passive(passive_id: StringName) -> PassiveData:
	for passive in passives:
		if passive != null and passive.id == passive_id:
			return passive
	return null

func ensure_balance() -> BuildBalanceData:
	if balance == null:
		balance = BuildBalanceData.new()
	return balance

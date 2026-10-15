@tool
class_name PassiveData
extends Resource

enum EffectType {
	MAX_HP_BONUS,
	DAMAGE_BONUS,
	BLOCK_BONUS,
	ENERGY_BONUS,
	GENERAL_RESISTANCE,
	PHYSICAL_RESISTANCE,
	MAGIC_RESISTANCE,
	PSYCHIC_RESISTANCE
}

@export var id: StringName = &""
@export var display_name: String = "Новая пассивка"
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_category("Прокачка")
@export_range(1, 20, 1) var max_level: int = 3
@export_range(0, 20, 1) var starting_level: int = 0

@export_category("Эффект")
@export var effect_type: EffectType = EffectType.DAMAGE_BONUS
@export var value_per_level: float = 0.05

func get_value(level: int) -> float:
	return value_per_level * float(clampi(level, 0, max_level))

func get_value_text(level: int) -> String:
	var value := get_value(level)
	match effect_type:
		EffectType.MAX_HP_BONUS:
			return "+%d HP" % roundi(value)
		EffectType.ENERGY_BONUS:
			return "+%d энергии" % roundi(value)
		EffectType.DAMAGE_BONUS:
			return "+%d%% урона" % roundi(value * 100.0)
		EffectType.BLOCK_BONUS:
			return "+%d%% блока" % roundi(value * 100.0)
		EffectType.GENERAL_RESISTANCE:
			return "%d%% сопротивления" % roundi(value * 100.0)
		EffectType.PHYSICAL_RESISTANCE:
			return "%d%% физ. сопротивления" % roundi(value * 100.0)
		EffectType.MAGIC_RESISTANCE:
			return "%d%% маг. сопротивления" % roundi(value * 100.0)
		EffectType.PSYCHIC_RESISTANCE:
			return "%d%% псих. сопротивления" % roundi(value * 100.0)
	return str(value)

func get_effect_name() -> String:
	match effect_type:
		EffectType.MAX_HP_BONUS: return "Макс. HP"
		EffectType.DAMAGE_BONUS: return "Урон"
		EffectType.BLOCK_BONUS: return "Блок"
		EffectType.ENERGY_BONUS: return "Энергия"
		EffectType.GENERAL_RESISTANCE: return "Общее сопротивление"
		EffectType.PHYSICAL_RESISTANCE: return "Физ. сопротивление"
		EffectType.MAGIC_RESISTANCE: return "Маг. сопротивление"
		EffectType.PSYCHIC_RESISTANCE: return "Псих. сопротивление"
	return "Эффект"

class_name Buff
extends RefCounted

var active: Dictionary = {}
var max_levels: Dictionary = {
	"shield": 3
}

func apply(buff_id: String, duration: int = 1, level: int = 0) -> void:
	var real_id: String = _get_base_id(buff_id)
	var explicit_level: int = _get_level_from_id(buff_id)
	if explicit_level > 0:
		level = explicit_level

	if active.has(real_id):
		var data: Dictionary = active[real_id]
		var old_level: int = int(data.get("level", 1))
		var new_level: int

		if level > 0:
			new_level = mini(level, int(max_levels.get(real_id, level)))
		else:
			new_level = mini(old_level + 1, int(max_levels.get(real_id, old_level + 1)))

		data["level"] = maxi(old_level, new_level)
		data["duration"] = maxi(int(data.get("duration", 0)), duration)

		if real_id == "shield" and int(data["level"]) >= 3 and int(data.get("charges", 0)) <= 0:
			data["charges"] = 1

		active[real_id] = data
		return

	var new_level: int = level if level > 0 else 1
	new_level = mini(new_level, int(max_levels.get(real_id, new_level)))

	active[real_id] = {
		"level": new_level,
		"duration": duration,
		"charges": 1 if real_id == "shield" and new_level >= 3 else 0
	}

func process_damage(amount: int) -> int:
	var result: int = maxi(amount, 0)
	if result <= 0 or not active.has("shield"):
		return result

	var shield: Dictionary = active["shield"]
	var level: int = int(shield.get("level", 1))
	var charges: int = int(shield.get("charges", 0))

	# III уровень полностью блокирует ограниченное число атак.
	if level >= 3 and charges > 0:
		shield["charges"] = charges - 1
		active["shield"] = shield
		return 0

	# I+ уровень снижает входящий урон на 20%.
	if level >= 1:
		result = maxi(0, ceili(float(result) * 0.8))

	return result

func blocks_debuff() -> bool:
	return get_level("shield") >= 2

func set_charges(buff_id: String, amount: int) -> void:
	var real_id: String = _get_base_id(buff_id)
	if not active.has(real_id):
		return
	var data: Dictionary = active[real_id]
	data["charges"] = maxi(amount, 0)
	active[real_id] = data

func tick() -> void:
	var expired: Array[String] = []
	for buff_id in active.keys():
		var data: Dictionary = active[buff_id]
		data["duration"] = int(data.get("duration", 1)) - 1
		if int(data["duration"]) <= 0:
			expired.append(str(buff_id))
		else:
			active[buff_id] = data

	for buff_id in expired:
		active.erase(buff_id)

func has(buff_id: String) -> bool:
	return active.has(_get_base_id(buff_id))

func get_level(buff_id: String) -> int:
	var real_id: String = _get_base_id(buff_id)
	if active.has(real_id):
		return int(active[real_id].get("level", 1))
	return 0

func get_duration(buff_id: String) -> int:
	var real_id: String = _get_base_id(buff_id)
	if active.has(real_id):
		return int(active[real_id].get("duration", 0))
	return 0

func get_charges(buff_id: String) -> int:
	var real_id: String = _get_base_id(buff_id)
	if active.has(real_id):
		return int(active[real_id].get("charges", 0))
	return 0

func remove(buff_id: String) -> void:
	active.erase(_get_base_id(buff_id))

func clear() -> void:
	active.clear()

func _get_base_id(buff_id: String) -> String:
	if buff_id.begins_with("shield_lvl_"):
		return "shield"
	return buff_id

func _get_level_from_id(buff_id: String) -> int:
	if not buff_id.begins_with("shield_lvl_"):
		return 0
	var value: String = buff_id.trim_prefix("shield_lvl_")
	return int(value) if value.is_valid_int() else 0

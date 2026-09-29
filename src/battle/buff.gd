class_name Buff
extends RefCounted

var active: Dictionary = {}
var max_levels: Dictionary = {
	"shield": 3
}

func apply(buff_id: String, duration: int = 1, level: int = 0) -> void:
	var real_id := _get_base_id(buff_id)
	var explicit_level := _get_level_from_id(buff_id)

	if explicit_level > 0:
		level = explicit_level

	if active.has(real_id):
		var data: Dictionary = active[real_id]

		if level > 0:
			data["level"] = min(
				level,
				max_levels.get(real_id, level)
			)
		else:
			data["level"] = min(
				int(data["level"]) + 1,
				max_levels.get(real_id, int(data["level"]) + 1)
			)

		data["duration"] = max(int(data["duration"]), duration)

		if real_id == "shield":
			data["charges"] = 2

		active[real_id] = data
		return

	var new_level := level

	if new_level <= 0:
		new_level = 1

	new_level = min(
		new_level,
		max_levels.get(real_id, new_level)
	)

	active[real_id] = {
		"level": new_level,
		"duration": duration,
		"charges": 2 if real_id == "shield" else 0
	}


func process_damage(amount: int) -> int:
	var result := amount

	if result <= 0:
		return 0

	for buff_id in active.keys():
		var data: Dictionary = active[buff_id]

		match buff_id:
			"shield":
				if int(data["charges"]) > 0:
					data["charges"] = int(data["charges"]) - 1
					active[buff_id] = data
					result = 0

		if result <= 0:
			break

	return result


func tick() -> void:
	var expired: Array[String] = []

	for buff_id in active.keys():
		var data: Dictionary = active[buff_id]
		data["duration"] = int(data["duration"]) - 1

		if int(data["duration"]) <= 0:
			expired.append(buff_id)
		else:
			active[buff_id] = data

	for buff_id in expired:
		active.erase(buff_id)


func has(buff_id: String) -> bool:
	return active.has(_get_base_id(buff_id))


func get_level(buff_id: String) -> int:
	var real_id := _get_base_id(buff_id)

	if active.has(real_id):
		return int(active[real_id]["level"])

	return 0


func get_duration(buff_id: String) -> int:
	var real_id := _get_base_id(buff_id)

	if active.has(real_id):
		return int(active[real_id]["duration"])

	return 0


func get_charges(buff_id: String) -> int:
	var real_id := _get_base_id(buff_id)

	if active.has(real_id):
		return int(active[real_id]["charges"])

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

	var value := buff_id.trim_prefix("shield_lvl_")

	if value.is_valid_int():
		return int(value)

	return 0

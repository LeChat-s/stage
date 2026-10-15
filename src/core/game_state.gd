class_name GameStateClass
extends Node

@export var info_scene: PackedScene = preload("res://src/ui/info.tscn")

const BUILD_DIR := "res://src/data/builds/definitions"

var deck: Array[CardData] = []
var player_hp: int = 50
var player_max_hp: int = 50
var active_contamination: String = "none"
var active_contamination_data: ContaminationData = null

enum DamageType { PHYSICAL, MAGIC, PSYCHIC }

# Общие пассивки и legacy-ключи Magical Girl сохранены для совместимости со старыми сохранениями/журналом.
var passives: Dictionary = {
	"max_hp_boost": 0,
	"damage_res": 0,
	"mg_energy_boost": 1,
	"mg_magic_res": 1
}
var build_passive_levels: Dictionary = {}

const HP_BOOST_PER_LEVEL: int = 10
const DAMAGE_RES_PER_LEVEL: float = 0.05
const MAX_DAMAGE_RES_LEVEL: int = 10
const MG_MAX_LEVEL: int = 3
const MG_MAGIC_RES_PER_LEVEL: float = 0.07

var current_enemies: Array[EnemyData] = []
var defeated_enemies: Array[String] = []
var player_world_position: Vector2 = Vector2.ZERO
var current_enemy_node_name: String = ""
var battle_return_scene_path: String = ""
var info_instance: Control = null

var _build_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_run()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("info"):
		_toggle_info_panel()

func _toggle_info_panel() -> void:
	if not is_instance_valid(info_instance):
		var info_layer = get_tree().current_scene.find_child("InfoLayer", true, false)
		if not info_layer:
			push_error("Не удалось найти узел InfoLayer в текущей сцене!")
			return
		info_instance = info_scene.instantiate() as Control
		info_layer.add_child(info_instance)
		info_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		info_instance.visible = false

	info_instance.visible = not info_instance.visible
	get_tree().paused = info_instance.visible
	get_viewport().set_input_as_handled()

func upgrade_passive(passive_name: String) -> void:
	if passive_name not in passives:
		push_error("Пассивка с именем %s не существует!" % passive_name)
		return
	if passive_name == "damage_res" and int(passives[passive_name]) >= MAX_DAMAGE_RES_LEVEL:
		return
	if passive_name in ["mg_energy_boost", "mg_magic_res"] and int(passives[passive_name]) >= MG_MAX_LEVEL:
		return

	passives[passive_name] = int(passives[passive_name]) + 1
	recalculate_stats()

func recalculate_stats() -> void:
	player_max_hp = 50 + int(passives["max_hp_boost"]) * HP_BOOST_PER_LEVEL
	player_hp = mini(player_hp, player_max_hp)

func normalize_build_id(build_id: String) -> String:
	match build_id:
		"inf_magical_girl", "con_magical_girl":
			return "magical_girl"
		"con_doctor":
			return "doctor"
	return build_id

func get_build_data(build_id: String) -> ContaminationData:
	build_id = normalize_build_id(build_id)
	if build_id.is_empty() or build_id == "none" or build_id == "standart":
		return null
	if _build_cache.has(build_id):
		var cached = _build_cache[build_id]
		if cached is ContaminationData:
			return cached as ContaminationData

	var direct_path := "%s/%s.tres" % [BUILD_DIR, build_id]
	if ResourceLoader.exists(direct_path):
		var direct := load(direct_path) as ContaminationData
		if direct != null:
			_build_cache[build_id] = direct
			return direct

	var dir := DirAccess.open(BUILD_DIR)
	if dir == null:
		return null
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.get_extension() == "tres":
			var build := load("%s/%s" % [BUILD_DIR, file_name]) as ContaminationData
			if build != null:
				_build_cache[String(build.id)] = build
				if String(build.id) == build_id:
					dir.list_dir_end()
					return build
		file_name = dir.get_next()
	dir.list_dir_end()
	return null

func get_all_builds() -> Array[ContaminationData]:
	var result: Array[ContaminationData] = []
	var dir := DirAccess.open(BUILD_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.get_extension() == "tres":
			var build := load("%s/%s" % [BUILD_DIR, file_name]) as ContaminationData
			if build != null:
				_build_cache[String(build.id)] = build
				result.append(build)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

func get_build_passive_level(build_id: String, passive_id: StringName) -> int:
	build_id = normalize_build_id(build_id)
	var key := "%s/%s" % [build_id, String(passive_id)]
	if build_passive_levels.has(key):
		return int(build_passive_levels[key])

	# Миграция старых уровней Magical Girl без потери прогресса.
	if build_id == "magical_girl":
		if passive_id == &"energy_flow":
			return int(passives.get("mg_energy_boost", 1))
		if passive_id == &"astral_barrier":
			return int(passives.get("mg_magic_res", 1))

	var build := get_build_data(build_id)
	if build == null:
		return 0
	var passive := build.get_passive(passive_id)
	if passive == null:
		return 0
	return clampi(passive.starting_level, 0, passive.max_level)

func upgrade_build_passive(build_id: String, passive_id: StringName) -> bool:
	build_id = normalize_build_id(build_id)
	var build := get_build_data(build_id)
	if build == null:
		return false
	var passive := build.get_passive(passive_id)
	if passive == null:
		return false

	var level := get_build_passive_level(build_id, passive_id)
	if level >= passive.max_level:
		return false
	level += 1
	build_passive_levels["%s/%s" % [build_id, String(passive_id)]] = level

	if build_id == "magical_girl":
		if passive_id == &"energy_flow":
			passives["mg_energy_boost"] = level
		elif passive_id == &"astral_barrier":
			passives["mg_magic_res"] = level
	return true

func get_build_passive_bonus(effect_type: int, build: ContaminationData = null) -> float:
	if build == null:
		build = active_contamination_data
	if build == null:
		return 0.0
	var result: float = 0.0
	for passive in build.passives:
		if passive == null or int(passive.effect_type) != effect_type:
			continue
		var level := get_build_passive_level(String(build.id), passive.id)
		result += passive.get_value(level)
	return result

func calculate_incoming_damage(base_damage: int, type: int = 0) -> int:
	var general_resistance: float = float(passives["damage_res"]) * DAMAGE_RES_PER_LEVEL
	var specific_resistance: float = 0.0
	var build_multiplier: float = 1.0

	if active_contamination_data != null:
		var balance := active_contamination_data.ensure_balance()
		build_multiplier = balance.incoming_damage_multiplier
		general_resistance += get_build_passive_bonus(PassiveData.EffectType.GENERAL_RESISTANCE)
		match type:
			DamageType.PHYSICAL:
				specific_resistance += get_build_passive_bonus(PassiveData.EffectType.PHYSICAL_RESISTANCE)
			DamageType.MAGIC:
				specific_resistance += get_build_passive_bonus(PassiveData.EffectType.MAGIC_RESISTANCE)
			DamageType.PSYCHIC:
				specific_resistance += get_build_passive_bonus(PassiveData.EffectType.PSYCHIC_RESISTANCE)
	elif active_contamination == "magical_girl" and type == int(DamageType.MAGIC):
		specific_resistance += float(passives["mg_magic_res"]) * MG_MAGIC_RES_PER_LEVEL

	general_resistance = clampf(general_resistance, 0.0, 0.85)
	specific_resistance = clampf(specific_resistance, 0.0, 0.85)
	var final_modifier: float = maxf(0.0, (1.0 - general_resistance) * (1.0 - specific_resistance) * build_multiplier)
	return maxi(0, roundi(float(base_damage) * final_modifier))

func get_bonus_energy() -> int:
	if active_contamination_data != null:
		var balance := active_contamination_data.ensure_balance()
		var passive_bonus := get_build_passive_bonus(PassiveData.EffectType.ENERGY_BONUS)
		return balance.energy_bonus + roundi(passive_bonus)
	if active_contamination == "magical_girl":
		return int(passives["mg_energy_boost"])
	return 0

func get_active_damage_multiplier() -> float:
	if active_contamination_data == null:
		return 1.0
	var balance := active_contamination_data.ensure_balance()
	return maxf(0.0, balance.damage_multiplier * (1.0 + get_build_passive_bonus(PassiveData.EffectType.DAMAGE_BONUS)))

func get_active_block_multiplier() -> float:
	if active_contamination_data == null:
		return 1.0
	var balance := active_contamination_data.ensure_balance()
	return maxf(0.0, balance.block_multiplier * (1.0 + get_build_passive_bonus(PassiveData.EffectType.BLOCK_BONUS)))

func get_active_max_hp_bonus() -> int:
	if active_contamination_data == null:
		return 0
	var balance := active_contamination_data.ensure_balance()
	return balance.max_hp_bonus + roundi(get_build_passive_bonus(PassiveData.EffectType.MAX_HP_BONUS))

func reset_run() -> void:
	deck = _get_base_deck()
	active_contamination = "none"
	active_contamination_data = null
	recalculate_stats()
	player_hp = player_max_hp
	defeated_enemies.clear()
	current_enemies.clear()
	current_enemy_node_name = ""
	battle_return_scene_path = ""

func mark_enemy_detected(enemy_id: String) -> void:
	if not enemy_id.is_empty() and enemy_id not in defeated_enemies:
		defeated_enemies.append(enemy_id)

func is_enemy_defeated(enemy_id: String) -> bool:
	return enemy_id in defeated_enemies

func _get_base_deck() -> Array[CardData]:
	var base: Array[CardData] = []

	# Magical Girl остаётся стартовым карточным пакетом до выбора заражения.
	_append_card_if_exists(base, "res://src/data/cards/atk_magical_blast.tres")
	_append_card_if_exists(base, "res://src/data/cards/atk_magical_rain.tres")
	_append_card_if_exists(base, "res://src/data/cards/def_magical_shield.tres")
	_append_card_if_exists(base, "res://src/data/cards/def_magical_barrier.tres")
	_append_card_if_exists(base, "res://src/data/cards/status_magical_charge.tres")

	# Две базовые формы всегда доступны, даже если ресурс билда временно не загрузился.
	_append_card_if_exists(base, "res://src/data/cards/con_magical_girl.tres")
	_append_card_if_exists(base, "res://src/data/cards/con_doctor.tres")

	# Карты активации пользовательских билдов добавляются автоматически.
	for build in get_all_builds():
		if build == null or build.activation_card_id.is_empty():
			continue
		_append_card_if_exists(base, "res://src/data/cards/%s.tres" % build.activation_card_id)

	return base

func _append_card_if_exists(target: Array[CardData], path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var card := load(path) as CardData
	if card == null:
		return
	for existing in target:
		if existing != null and existing.id == card.id:
			return
	target.append(card)

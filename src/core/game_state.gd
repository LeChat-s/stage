class_name GameStateClass
extends Node

@export var info_scene: PackedScene = preload("res://src/ui/info.tscn")

var deck: Array[CardData] = []
var player_hp: int = 50
var player_max_hp: int = 50
var active_contamination: String = "none" 
enum DamageType { PHYSICAL, MAGIC, PSYCHIC }

var passives: Dictionary = {
	"max_hp_boost": 0, 
	"damage_res": 0, 
	"magical_girl_passive": 1 
}

const HP_BOOST_PER_LEVEL: int = 10
const DAMAGE_RES_PER_LEVEL: float = 0.05
const MAX_DAMAGE_RES_LEVEL: int = 10 
const MG_MAX_LEVEL: int = 3
const MG_MAGIC_RES_PER_LEVEL: float = 0.07

var current_enemies: Array[EnemyData] = []
var defeated_enemies: Array[String] = []
var player_world_position: Vector2 = Vector2.ZERO
var current_enemy_node_name: String = ""
var info_instance: Control = null

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
	info_instance.visible = !info_instance.visible
	
	get_tree().paused = info_instance.visible
	get_viewport().set_input_as_handled()

func upgrade_passive(passive_name: String) -> void:
	if passive_name in passives:
		if passive_name == "damage_res" and passives[passive_name] >= MAX_DAMAGE_RES_LEVEL:
			print("Достигнут максимальный уровень общего сопротивления урону!")
			return
		if passive_name == "magical_girl_passive" and passives[passive_name] >= MG_MAX_LEVEL:
			print("Достигнут максимальный уровень пассивки Девочки-Волшебницы!")
			return
			
		passives[passive_name] += 1
		recalculate_stats()
		print("Пассивка ", passive_name, " улучшена до уровня: ", passives[passive_name])
	else:
		push_error("Пассивка с именем " + passive_name + " не существует!")

func recalculate_stats() -> void:
	player_max_hp = 50 + (passives["max_hp_boost"] * HP_BOOST_PER_LEVEL)
	if player_hp > player_max_hp:
		player_hp = player_max_hp

func calculate_incoming_damage(base_damage: int, type: int = 0) -> int:
	var total_general_res: float = passives["damage_res"] * DAMAGE_RES_PER_LEVEL
	var specific_res: float = 0.0
	
	if active_contamination == "magical_girl" and type == int(DamageType.MAGIC):
		var mg_lvl = passives["magical_girl_passive"]
		specific_res = mg_lvl * MG_MAGIC_RES_PER_LEVEL # 0.07, 0.14 или 0.21
		print("[ЗАРАЖЕНИЕ] Сработало сопротивление магии формы Девочки-Волшебницы: ", specific_res * 100, "%")
	var final_modifier: float = (1.0 - total_general_res) * (1.0 - specific_res)
	final_modifier = maxf(0.0, final_modifier) 
	
	return roundi(base_damage * final_modifier)
func get_bonus_energy() -> int:
	if active_contamination == "magical_girl":
		return passives["magical_girl_passive"]
	return 0
	
func reset_run() -> void:
	deck = _get_base_deck()
	active_contamination = "none"
	recalculate_stats()
	player_hp = player_max_hp
	defeated_enemies.clear()
	current_enemies.clear()

func mark_enemy_detected(enemy_id: String) -> void:
	if enemy_id not in defeated_enemies:
		defeated_enemies.append(enemy_id)

func is_enemy_defeated(enemy_id: String) -> bool:
	return enemy_id in defeated_enemies

func _get_base_deck() -> Array[CardData]:
	var base: Array[CardData] = []
	base.append(load("res://src/data/cards/con_magical_girl.tres"))
	base.append(load("res://src/data/cards/con_doctor.tres"))
	base.append(load("res://src/data/cards/atk_magical_blast.tres"))
	base.append(load("res://src/data/cards/atk_magical_rain.tres"))
	base.append(load("res://src/data/cards/def_magical_shield.tres"))
	base.append(load("res://src/data/cards/def_magical_barrier.tres"))
	base.append(load("res://src/data/cards/status_magical_charge.tres"))
	return base

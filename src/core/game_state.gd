extends Node


var deck: Array[CardData] = []
var player_hp: int = 50
var player_max_hp: int = 50
var current_enemy: EnemyData
var defeated_enemies: Array[String] = []
var player_world_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	reset_run()

func reset_run() -> void:
	deck = _get_base_deck()
	player_hp = player_max_hp
	defeated_enemies.clear()

func mark_enemy_detected(enemy_id: String) -> void:
	if enemy_id not in defeated_enemies:
		defeated_enemies.append(enemy_id)

func is_enemy_defeated(enemy_id: String) -> bool:
	return enemy_id in defeated_enemies

func _get_base_deck() -> Array[CardData]:
	var base: Array[CardData] = []

	base.append(load("res://src/data/cards/inf_magical_girl.tres"))
	base.append(load("res://src/data/cards/atk_magical_blast.tres"))
	base.append(load("res://src/data/cards/atk_magical_rain.tres"))
	base.append(load("res://src/data/cards/def_magical_shield.tres"))
	base.append(load("res://src/data/cards/def_magical_barrier.tres"))
	base.append(load("res://src/data/cards/status_magical_charge.tres"))
	
	return base

class_name GameStateClass
extends Node

@export var info_scene: PackedScene = preload("res://src/ui/info.tscn")

var deck: Array[CardData] = []
var player_hp: int = 50
var player_max_hp: int = 50

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

func reset_run() -> void:
	deck = _get_base_deck()
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
	base.append(load("res://src/data/cards/inf_magical_girl.tres"))
	base.append(load("res://src/data/cards/atk_magical_blast.tres"))
	base.append(load("res://src/data/cards/atk_magical_rain.tres"))
	base.append(load("res://src/data/cards/def_magical_shield.tres"))
	base.append(load("res://src/data/cards/def_magical_barrier.tres"))
	base.append(load("res://src/data/cards/status_magical_charge.tres"))
	return base

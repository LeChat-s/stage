class_name TestLvl
extends Node2D

@onready var player: Player = $Player

func _ready() -> void:
	_connect_enemies()
	if GameState.player_world_position != Vector2.ZERO:
		player.global_position = GameState.player_world_position
	player.position_changed.connect(_on_player_position_changed)

func _on_player_position_changed(position: Vector2) -> void:
	GameState.player_world_position = position

func _connect_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy is Enemy:
			enemy.player_detected.connect(_on_player_detected)

func _on_player_detected(enemy_data: EnemyData) -> void:
	GameState.current_enemy = enemy_data
	call_deferred("_change_to_battle")

func _change_to_battle() -> void:
	get_tree().change_scene_to_file("res://src/battle/battle.tscn")

class_name Enemy
extends Area2D

signal player_detected(enemy_data: EnemyData)

@export var enemy_data: EnemyData

func _ready() -> void:
	_check_if_defeated()

func _check_if_defeated() -> void:
	if GameState.is_enemy_defeated(name):
		print("Враг с уникальным именем ", name, " удален")
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_detected.emit(enemy_data)
		GameState.current_enemy_node_name = name
		print(name)

class_name Enemy
extends Area2D

signal player_detected(enemy_group: EnemyGroup)
@export var enemy_group: EnemyGroup

func _ready() -> void:
	_check_if_defeated()

func _check_if_defeated() -> void:
	if GameState.is_enemy_defeated(name):
		print("Враг с уникальным именем ", name, " удален")
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if enemy_group and not enemy_group.enemies.is_empty():
			GameState.current_enemies = enemy_group.enemies.duplicate()
			GameState.current_enemy_node_name = name
			player_detected.emit(enemy_group)
			
			print("Игрок столкнулся с группой врагов на узле: ", name)
		else:
			push_error("Ошибка: У узла " + name + " не задан EnemyGroup или в нем нет врагов!")

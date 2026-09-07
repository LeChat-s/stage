class_name EnemyCatalog extends Resource

@export var database: Dictionary[int, EnemyData] = {}

func get_enemy_data(id: int) -> EnemyData:
	if database.has(id):
		return database[id]
	print("Ошибка: В EnemyCatalog не найден враг с ID: ", id)
	return null

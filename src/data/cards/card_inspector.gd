extends PanelContainer

@onready var title_label: Label = $VBoxContainer/header/TitleLabel
@onready var grid: GridContainer = $VBoxContainer/ScrollContainer/Grid

func _ready() -> void:
	hide()
	$VBoxContainer/header/CloseButton.pressed.connect(hide)

func open(window_title: String, cards_list: Array) -> void:
	print("--- Открытие инспектора ---")
	print("Заголовок: ", window_title)
	print("Всего элементов в массиве: ", cards_list.size())
	
	title_label.text = window_title
	
	for child in grid.get_children():
		child.free() 
	
	var index = 0
	for card_data in cards_list:
		print("Элемент [", index, "]: тип = ", typeof(card_data), " | объект = ", card_data)
		
		var card_pic = TextureRect.new()
		
		card_pic.custom_minimum_size = Vector2(100, 140)
		card_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_pic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		if card_data is CardData:
			print("  -> Это CardData! ID: '", card_data.id, "', Название: '", card_data.name, "'")
			if card_data.artwork:
				print("  -> Текстура (artwork) успешно найдена: ", card_data.artwork.resource_path)
				card_pic.texture = card_data.artwork
			else:
				print("  -> Внимание: Текстура (artwork) РАВНА NULL!")
				card_pic.texture = preload("res://icon.svg")
		else:
			print("  -> Внимание: Элемент НЕ является классом CardData! Отрисовка заглушки.")
			card_pic.texture = preload("res://icon.svg") 
			
		grid.add_child(card_pic)
		index += 1
		
	print("---------------------------")
	show()

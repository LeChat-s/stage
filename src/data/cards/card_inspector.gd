extends PanelContainer

@onready var title_label: Label = $VBoxContainer/header/TitleLabel
@onready var grid: GridContainer = $VBoxContainer/ScrollContainer/Grid

func _ready() -> void:
	hide()
	$VBoxContainer/header/CloseButton.pressed.connect(hide)

func open(window_title: String, cards_list: Array) -> void:
	title_label.text = window_title
	
	for child in grid.get_children():
		child.queue_free()
	
	for card_data in cards_list:
		var card_pic = TextureRect.new()
		card_pic.custom_minimum_size = Vector2(100, 140)
		card_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if card_data and "texture" in card_data:
			card_pic.texture = card_data.texture
		else:
			card_pic.texture = preload("res://icon.svg") 
			
		grid.add_child(card_pic)
	show()

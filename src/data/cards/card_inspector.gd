extends PanelContainer

const CardFaceScript = preload("res://src/data/cards/card_face.gd")

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
		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(106.0, 150.0)
		wrapper.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		if card_data is CardData:
			var face := CardFaceScript.new() as CardFace
			face.size = CardFace.CARD_SIZE
			face.scale = Vector2(0.5, 0.5)
			face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			face.set_card(card_data)
			wrapper.add_child(face)
		else:
			var label := Label.new()
			label.text = "?"
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			wrapper.add_child(label)

		grid.add_child(wrapper)

	show()

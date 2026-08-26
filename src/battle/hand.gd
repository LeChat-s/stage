class_name Hand
extends Control

signal card_selected(card_data: CardData)

var card_scene: PackedScene = preload("res://src/data/cards/card_ui.tscn")
@export var hand_width: float = 500.0
 
func clear_hand() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

func add_card(card_data: CardData) -> void:
	var card = card_scene.instantiate()
	card.setup(card_data)
	card.card_played.connect(_on_card_played)
	add_child(card)
	_reposition_card()

func _reposition_card() -> void:
	var card_count = get_child_count()
	if card_count == 0:
		return
	
	var max_spacing: float = 90.0
	
	var spacing = hand_width / max(1, card_count - 1)
	if card_count == 1:
		spacing = 0
	
	if spacing > max_spacing:
		spacing = max_spacing
		
	var actual_width = spacing * (card_count - 1)

	for i in range(card_count):
		var card = get_child(i)
		if card is Control:
			card.pivot_offset = card.size / 2.0
		
		var target_x = (i * spacing) - (actual_width / 2.0) if card_count > 1 else 0.0
		
		var center_offset = (i - (card_count - 1) / 2.0)
		var target_y = abs(center_offset) * 12.0 
		card.rotation_degrees = center_offset * 6.0
		var card_center_offset = card.size / 2.0 if card is Control else Vector2.ZERO
		card.original_position = global_position + Vector2(target_x, target_y) - card_center_offset
		if card is CardUI:
			card.original_rotation = card.rotation_degrees
			
func _on_card_played(card_data: CardData) -> void:
	card_selected.emit(card_data)

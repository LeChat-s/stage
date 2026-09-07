class_name Info
extends Control

@onready var hp_label: Label = $Paper/Stats/VBoxContainer/HPLabel
@onready var stats_panel: Control = $Paper/Stats
@onready var deck_panel: Control = $Paper/Deck
@onready var cards_info_panel: Control = $Paper/CardsInfo

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	update_hp_display()
	show_tab(stats_panel)
func _on_visibility_changed() -> void:
	if visible:
		update_hp_display()

func update_hp_display() -> void:
	if not hp_label:
		return
	hp_label.text = "Физическое состояние — %d" % GameState.player_hp

func _find_player_by_class(node: Node) -> PlayerInBattle:
	if node is PlayerInBattle:
		return node
	for child in node.get_children():
		var result = _find_player_by_class(child)
		if result:
			return result
	return null

func show_tab(active_panel: Control) -> void:
	if not stats_panel or not deck_panel or not cards_info_panel:
		return
	stats_panel.hide()
	deck_panel.hide()
	cards_info_panel.hide()
	if active_panel:
		active_panel.show()

func _on_stats_pressed() -> void:
	print("Переключение на: статы")
	show_tab(stats_panel)
	update_hp_display()

func _on_deck_pressed() -> void:
	print("Переключение на: колода")
	show_tab(deck_panel)
	
func _on_card_info_pressed() -> void:
	print("Переключение на: инфа по картам")
	show_tab(cards_info_panel)

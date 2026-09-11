class_name Info
extends Control

@onready var hp_label: Label = $Paper/Stats/VBoxContainer/HPLabel
@onready var max_hp_label: Label = $Paper/Stats/VBoxContainer/MaxHPLabel
@onready var damage_res_label: Label = $Paper/Stats/VBoxContainer/DamageResLabel
@onready var upgrade_hp_button: Button = $Paper/Stats/VBoxContainer/MaxHPLabel/UpgradeHPButton
@onready var upgrade_res_button: Button = $Paper/Stats/VBoxContainer/DamageResLabel/UpgradeResButton
@onready var stats_panel: Control = $Paper/Stats
@onready var deck_panel: Control = $Paper/Deck
@onready var cards_info_panel: Control = $Paper/CardsInfo

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if upgrade_hp_button:
		upgrade_hp_button.pressed.connect(_on_upgrade_hp_pressed)
	if upgrade_res_button:
		upgrade_res_button.pressed.connect(_on_upgrade_res_pressed)
		
	update_stats_display()
	show_tab(stats_panel)

func _on_visibility_changed() -> void:
	if visible:
		update_stats_display()
func update_stats_display() -> void:
	# 1. Текущее здоровье
	if hp_label:
		hp_label.text = "Физическое состояние — %d / %d" % [GameState.player_hp, GameState.player_max_hp]
	if max_hp_label:
		var hp_lvl = GameState.passives.get("max_hp_boost", 0)
		var hp_bonus = hp_lvl * GameState.HP_BOOST_PER_LEVEL
		max_hp_label.text = "Увеличение здоровья: Ур. %d (+%d к макс. HP)" % [hp_lvl, hp_bonus]
	var res_lvl = GameState.passives.get("damage_res", 0)
	if damage_res_label:
		var res_percent = roundi(res_lvl * GameState.DAMAGE_RES_PER_LEVEL * 100)
		damage_res_label.text = "Сопротивление урону: Ур. %d (Снижение на %d%%)" % [res_lvl, res_percent]
	if upgrade_res_button:
		upgrade_res_button.disabled = (res_lvl >= GameState.MAX_DAMAGE_RES_LEVEL)

func _on_upgrade_hp_pressed() -> void:
	GameState.upgrade_passive("max_hp_boost")
	GameState.player_hp += GameState.HP_BOOST_PER_LEVEL
	update_stats_display()

func _on_upgrade_res_pressed() -> void:
	GameState.upgrade_passive("damage_res")
	update_stats_display()

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
	update_stats_display()

func _on_deck_pressed() -> void:
	print("Переключение на: колода")
	show_tab(deck_panel)
	
func _on_card_info_pressed() -> void:
	print("Переключение на: инфа по картам")
	show_tab(cards_info_panel)

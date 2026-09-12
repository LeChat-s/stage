class_name Info
extends Control

@onready var hp_label: Label = $Paper/Stats/StatsContainer/HPLabel
@onready var description_label: Label = $Paper/Stats/DescriptionLabel
@onready var contamination_container: VBoxContainer = $Paper/Stats/ContaminationContainer
@onready var pas_panel: Control = $Paper/Stats/Pas
@onready var max_hp_label: Label = $Paper/Stats/Pas/VBoxContainer/MaxHPLabel
@onready var damage_res_label: Label = $Paper/Stats/Pas/VBoxContainer/DamageResLabel
@onready var upgrade_hp_button: Button = $Paper/Stats/Pas/VBoxContainer/MaxHPLabel/UpgradeHPButton
@onready var upgrade_res_button: Button = $Paper/Stats/Pas/VBoxContainer/DamageResLabel/UpgradeResButton
@onready var stats_panel: Control = $Paper/Stats
@onready var deck_panel: Control = $Paper/Deck
@onready var cards_info_panel: Control = $Paper/CardsInfo

var selected_contamination: String = "none"

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if upgrade_hp_button:
		upgrade_hp_button.pressed.connect(_on_upgrade_hp_pressed)
	if upgrade_res_button:
		upgrade_res_button.pressed.connect(_on_upgrade_res_pressed)
	_setup_contamination_buttons()
	if pas_panel:
		pas_panel.hide()
		
	update_stats_display()
	show_tab(stats_panel)

func _on_visibility_changed() -> void:
	if visible:
		update_stats_display()

func _setup_contamination_buttons() -> void:
	if not contamination_container:
		return
		
	for child in contamination_container.get_children():
		if child is Button or child is TextureButton:
			if "general" in child.name.to_lower() or "standart" in child.name.to_lower():
				child.pressed.connect(_on_contamination_selected.bind("standart"))
			elif "magical" in child.name.to_lower() or "girl" in child.name.to_lower():
				child.pressed.connect(_on_contamination_selected.bind("magical_girl"))
			elif "doctor" in child.name.to_lower():
				child.pressed.connect(_on_contamination_selected.bind("doctor"))
	
func _on_contamination_selected(type_name: String) -> void:
	selected_contamination = type_name
	if pas_panel:
		pas_panel.show()
	update_stats_display()

func update_stats_display() -> void:
	if hp_label:
		hp_label.text = "%d / %d" % [GameState.player_hp, GameState.player_max_hp]
	if description_label:
		description_label.text = "Сюжетные маркеры стабильны. Заражение адаптируется под структуру ДНК."
	if not pas_panel or not pas_panel.visible:
		return
		
	match selected_contamination:
		"standart":
			max_hp_label.visible = true
			damage_res_label.visible = true
			
			var hp_lvl = GameState.passives.get("max_hp_boost", 0)
			var hp_bonus = hp_lvl * GameState.HP_BOOST_PER_LEVEL
			max_hp_label.text = "Увеличение здоровья: Ур. %d (+%d к макс. HP)" % [hp_lvl, hp_bonus]
			if upgrade_hp_button:
				upgrade_hp_button.visible = true
				upgrade_hp_button.disabled = false
				upgrade_hp_button.text = "+"
			
			var res_lvl = GameState.passives.get("damage_res", 0)
			var res_percent = roundi(res_lvl * GameState.DAMAGE_RES_PER_LEVEL * 100)
			damage_res_label.text = "Сопротивление урону: Ур. %d (Снижение на %d%%)" % [res_lvl, res_percent]
			if upgrade_res_button:
				upgrade_res_button.visible = true
				upgrade_res_button.disabled = (res_lvl >= GameState.MAX_DAMAGE_RES_LEVEL)
				upgrade_res_button.text = "МАКС" if upgrade_res_button.disabled else "Улучшить"
				
		"magical_girl":
			max_hp_label.visible = true
			damage_res_label.visible = true
			
			var energy_lvl = GameState.passives.get("mg_energy_boost", 1)
			max_hp_label.text = "Поток магии: Ур. %d (Бонус энергии: +%d)" % [energy_lvl, energy_lvl]
			if upgrade_hp_button:
				upgrade_hp_button.visible = true
				upgrade_hp_button.disabled = (energy_lvl >= GameState.MG_MAX_LEVEL)
				upgrade_hp_button.text = "МАКС" if upgrade_hp_button.disabled else "+"
			
			var magic_res_lvl = GameState.passives.get("mg_magic_res", 1)
			var mg_res_percent = roundi(magic_res_lvl * GameState.MG_MAGIC_RES_PER_LEVEL * 100)
			damage_res_label.text = "Астральный барьер: Ур. %d (Защита от магии: %d%%)" % [magic_res_lvl, mg_res_percent]
			if upgrade_res_button:
				upgrade_res_button.visible = true
				upgrade_res_button.disabled = (magic_res_lvl >= GameState.MG_MAX_LEVEL)
				upgrade_res_button.text = "МАКС" if upgrade_res_button.disabled else "Улучшить"
				
		"doctor":
			damage_res_label.visible = false
			max_hp_label.visible = true
			max_hp_label.text = "Форма Доктора: Еще не разблокирована в этой версии."
			if upgrade_hp_button:
				upgrade_hp_button.visible = false
			if upgrade_res_button:
				upgrade_res_button.visible = false

func _on_upgrade_hp_pressed() -> void:
	match selected_contamination:
		"standart":
			GameState.upgrade_passive("max_hp_boost")
			GameState.player_hp += GameState.HP_BOOST_PER_LEVEL
		"magical_girl":
			GameState.upgrade_passive("mg_energy_boost")
			
	update_stats_display()

func _on_upgrade_res_pressed() -> void:
	match selected_contamination:
		"standart":
			GameState.upgrade_passive("damage_res")
		"magical_girl":
			GameState.upgrade_passive("mg_magic_res")
			
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

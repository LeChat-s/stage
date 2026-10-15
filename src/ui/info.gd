class_name Info
extends Control

@onready var hp_label: Label = $Paper/Stats/StatsContainer/HPLabel
@onready var description_label: Label = $Paper/Stats/DescriptionLabel
@onready var contamination_container: VBoxContainer = $Paper/Stats/ContaminationContainer
@onready var pas_panel: Control = $Paper/Stats/Pas
@onready var passive_vbox: VBoxContainer = $Paper/Stats/Pas/VBoxContainer
@onready var max_hp_label: Label = $Paper/Stats/Pas/VBoxContainer/MaxHPLabel
@onready var damage_res_label: Label = $Paper/Stats/Pas/VBoxContainer/DamageResLabel
@onready var upgrade_hp_button: Button = $Paper/Stats/Pas/VBoxContainer/MaxHPLabel/UpgradeHPButton
@onready var upgrade_res_button: Button = $Paper/Stats/Pas/VBoxContainer/DamageResLabel/UpgradeResButton
@onready var stats_panel: Control = $Paper/Stats
@onready var deck_panel: Control = $Paper/Deck
@onready var cards_info_panel: Control = $Paper/CardsInfo

var selected_contamination: String = "none"
var dynamic_passive_container: VBoxContainer
var _registered_build_buttons: Dictionary = {}

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	if upgrade_hp_button:
		upgrade_hp_button.pressed.connect(_on_upgrade_hp_pressed)
	if upgrade_res_button:
		upgrade_res_button.pressed.connect(_on_upgrade_res_pressed)
	_setup_contamination_buttons()
	_create_dynamic_passive_container()
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
		if not (child is Button or child is TextureButton):
			continue
		var type_name := ""
		var lower_name := child.name.to_lower()
		if "general" in lower_name or "standart" in lower_name:
			type_name = "standart"
		elif "magical" in lower_name or "girl" in lower_name:
			type_name = "magical_girl"
		elif "doctor" in lower_name:
			type_name = "doctor"
		if type_name.is_empty():
			continue
		_registered_build_buttons[type_name] = true
		child.pressed.connect(_on_contamination_selected.bind(type_name))

	# Новые билды из конструктора автоматически появляются в журнале.
	for build in GameState.get_all_builds():
		var build_id := String(build.id)
		if build_id.is_empty() or _registered_build_buttons.has(build_id):
			continue
		var button := Button.new()
		button.name = "Build_%s" % build_id
		button.text = build.display_name
		button.tooltip_text = build.description
		button.pressed.connect(_on_contamination_selected.bind(build_id))
		contamination_container.add_child(button)
		_registered_build_buttons[build_id] = true

func _create_dynamic_passive_container() -> void:
	if passive_vbox == null:
		return
	dynamic_passive_container = VBoxContainer.new()
	dynamic_passive_container.name = "BuildPassives"
	dynamic_passive_container.visible = false
	passive_vbox.add_child(dynamic_passive_container)

func _on_contamination_selected(type_name: String) -> void:
	selected_contamination = GameState.normalize_build_id(type_name)
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

	_clear_dynamic_passives()

	if selected_contamination == "standart":
		_show_standard_passives()
		return

	var build := GameState.get_build_data(selected_contamination)
	if build != null:
		_show_build_passives(build)
		return

	max_hp_label.visible = true
	damage_res_label.visible = false
	var build_path := "%s/%s.tres" % [GameState.BUILD_DIR, selected_contamination]
	max_hp_label.text = "Не удалось загрузить ресурс билда: %s" % build_path if ResourceLoader.exists(build_path) else "Билд ещё не создан в конструкторе."
	if upgrade_hp_button:
		upgrade_hp_button.visible = false
	if upgrade_res_button:
		upgrade_res_button.visible = false

func _show_standard_passives() -> void:
	max_hp_label.visible = true
	damage_res_label.visible = true
	if dynamic_passive_container:
		dynamic_passive_container.visible = false

	var hp_lvl: int = int(GameState.passives.get("max_hp_boost", 0))
	var hp_bonus: int = hp_lvl * GameState.HP_BOOST_PER_LEVEL
	max_hp_label.text = "Увеличение здоровья: Ур. %d (+%d к макс. HP)" % [hp_lvl, hp_bonus]
	if upgrade_hp_button:
		upgrade_hp_button.visible = true
		upgrade_hp_button.disabled = false
		upgrade_hp_button.text = "+"

	var res_lvl: int = int(GameState.passives.get("damage_res", 0))
	var res_percent: int = roundi(float(res_lvl) * GameState.DAMAGE_RES_PER_LEVEL * 100.0)
	damage_res_label.text = "Сопротивление урону: Ур. %d (Снижение на %d%%)" % [res_lvl, res_percent]
	if upgrade_res_button:
		upgrade_res_button.visible = true
		upgrade_res_button.disabled = res_lvl >= GameState.MAX_DAMAGE_RES_LEVEL
		upgrade_res_button.text = "МАКС" if upgrade_res_button.disabled else "Улучшить"

func _show_build_passives(build: ContaminationData) -> void:
	max_hp_label.visible = false
	damage_res_label.visible = false
	if upgrade_hp_button:
		upgrade_hp_button.visible = false
	if upgrade_res_button:
		upgrade_res_button.visible = false
	if dynamic_passive_container == null:
		return
	dynamic_passive_container.visible = true

	if build.passives.is_empty():
		var empty_label := Label.new()
		empty_label.text = "У этого билда пока нет пассивных способностей."
		dynamic_passive_container.add_child(empty_label)
		return

	for passive in build.passives:
		if passive == null:
			continue
		var level := GameState.get_build_passive_level(String(build.id), passive.id)
		var row := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s: Ур. %d/%d — %s" % [passive.display_name, level, passive.max_level, passive.get_value_text(level)]
		label.tooltip_text = passive.description
		row.add_child(label)

		var button := Button.new()
		button.text = "МАКС" if level >= passive.max_level else "+"
		button.disabled = level >= passive.max_level
		button.pressed.connect(_on_build_passive_upgrade.bind(String(build.id), passive.id))
		row.add_child(button)
		dynamic_passive_container.add_child(row)

func _clear_dynamic_passives() -> void:
	if dynamic_passive_container == null:
		return
	for child in dynamic_passive_container.get_children():
		dynamic_passive_container.remove_child(child)
		child.queue_free()

func _on_build_passive_upgrade(build_id: String, passive_id: StringName) -> void:
	GameState.upgrade_build_passive(build_id, passive_id)
	update_stats_display()

func _on_upgrade_hp_pressed() -> void:
	if selected_contamination == "standart":
		GameState.upgrade_passive("max_hp_boost")
		GameState.player_hp += GameState.HP_BOOST_PER_LEVEL
	update_stats_display()

func _on_upgrade_res_pressed() -> void:
	if selected_contamination == "standart":
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
	show_tab(stats_panel)
	update_stats_display()

func _on_deck_pressed() -> void:
	show_tab(deck_panel)

func _on_card_info_pressed() -> void:
	show_tab(cards_info_panel)

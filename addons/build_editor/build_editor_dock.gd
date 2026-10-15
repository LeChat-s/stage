@tool
extends VBoxContainer

const BUILD_DIR := "res://src/data/builds/definitions"
const CARD_DIR := "res://src/data/cards"
const CONTAMINATION_DATA_PATH := "res://src/data/builds/contamination_data.gd"
const ABILITY_DATA_PATH := "res://src/data/builds/ability_data.gd"
const BALANCE_DATA_PATH := "res://src/data/builds/build_balance_data.gd"
const PASSIVE_DATA_PATH := "res://src/data/builds/passive_data.gd"
const CARD_DATA_PATH := "res://src/data/cards/cards_data.gd"
const PreviewScript = preload("res://addons/build_editor/build_sprite_preview.gd")
const PowerCalculator = preload("res://addons/build_editor/build_power_calculator.gd")

var editor_interface: EditorInterface
var build_list: ItemList
var summary: RichTextLabel
var inspector_button: Button
var infection_button: Button
var card_button: Button
var create_dialog: ConfirmationDialog
var id_edit: LineEdit
var name_edit: LineEdit
var selected_path: String = ""

var sprite_preview: Control
var sprite_picker: EditorResourcePicker
var hframes_spin: SpinBox
var vframes_spin: SpinBox
var idle_frames_edit: LineEdit
var attack_frames_edit: LineEdit
var idle_fps_spin: SpinBox
var attack_fps_spin: SpinBox
var scale_x_spin: SpinBox
var scale_y_spin: SpinBox
var offset_x_spin: SpinBox
var offset_y_spin: SpinBox

var damage_multiplier_spin: SpinBox
var block_multiplier_spin: SpinBox
var incoming_multiplier_spin: SpinBox
var hp_bonus_spin: SpinBox
var energy_bonus_spin: SpinBox
var resource_id_edit: LineEdit
var resource_name_edit: LineEdit
var resource_icon_picker: EditorResourcePicker
var resource_start_spin: SpinBox
var resource_max_spin: SpinBox
var power_label: RichTextLabel

var passive_tree: Tree
var passive_open_button: Button
var passive_delete_button: Button

var _updating_ui: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(980.0, 460.0)
	_ensure_directories()
	_build_ui()
	_refresh_builds()

func _build_ui() -> void:
	var header := HBoxContainer.new()
	add_child(header)

	var title := Label.new()
	title.text = "Конструктор билдов"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var new_button := Button.new()
	new_button.text = "Новый билд"
	new_button.pressed.connect(_show_create_dialog)
	header.add_child(new_button)

	var refresh_button := Button.new()
	refresh_button.text = "Обновить"
	refresh_button.pressed.connect(_refresh_builds)
	header.add_child(refresh_button)

	inspector_button = Button.new()
	inspector_button.text = "Инспектор"
	inspector_button.disabled = true
	inspector_button.pressed.connect(_open_selected)
	header.add_child(inspector_button)

	infection_button = Button.new()
	infection_button.text = "Карта заражения"
	infection_button.disabled = true
	infection_button.pressed.connect(_create_infection_card)
	header.add_child(infection_button)

	card_button = Button.new()
	card_button.text = "+ Карта"
	card_button.disabled = true
	card_button.pressed.connect(_create_build_card)
	header.add_child(card_button)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	build_list = ItemList.new()
	build_list.custom_minimum_size = Vector2(220.0, 0.0)
	build_list.item_selected.connect(_on_build_selected)
	build_list.item_activated.connect(_on_build_activated)
	split.add_child(build_list)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(tabs)

	_build_overview_tab(tabs)
	_build_appearance_tab(tabs)
	_build_balance_tab(tabs)
	_build_passives_tab(tabs)
	_create_new_build_dialog()

func _build_overview_tab(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "Обзор"
	tabs.add_child(page)

	summary = RichTextLabel.new()
	summary.bbcode_enabled = true
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(summary)

	var hint := Label.new()
	hint.text = "Карты и способности можно детально редактировать в Inspector. Остальные основные параметры доступны во вкладках конструктора."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(hint)

func _build_appearance_tab(tabs: TabContainer) -> void:
	var page := HSplitContainer.new()
	page.name = "Внешность"
	tabs.add_child(page)

	sprite_preview = PreviewScript.new()
	sprite_preview.custom_minimum_size = Vector2(340.0, 300.0)
	page.add_child(sprite_preview)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	var texture_label := Label.new()
	texture_label.text = "Sprite sheet"
	form.add_child(texture_label)
	sprite_picker = EditorResourcePicker.new()
	sprite_picker.base_type = "Texture2D"
	sprite_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(sprite_picker)

	var frame_grid := GridContainer.new()
	frame_grid.columns = 2
	form.add_child(frame_grid)
	hframes_spin = _add_spin_row(frame_grid, "Колонки (HFrames)", 1.0, 64.0, 1.0)
	vframes_spin = _add_spin_row(frame_grid, "Строки (VFrames)", 1.0, 64.0, 1.0)
	idle_fps_spin = _add_spin_row(frame_grid, "Idle FPS", 1.0, 60.0, 0.5)
	attack_fps_spin = _add_spin_row(frame_grid, "Attack FPS", 1.0, 60.0, 0.5)

	var idle_label := Label.new()
	idle_label.text = "Idle кадры (например 0,1,2,3,4)"
	form.add_child(idle_label)
	idle_frames_edit = LineEdit.new()
	form.add_child(idle_frames_edit)

	var attack_label := Label.new()
	attack_label.text = "Attack кадры"
	form.add_child(attack_label)
	attack_frames_edit = LineEdit.new()
	form.add_child(attack_frames_edit)

	var transform_grid := GridContainer.new()
	transform_grid.columns = 2
	form.add_child(transform_grid)
	scale_x_spin = _add_spin_row(transform_grid, "Scale X", 0.1, 10.0, 0.1)
	scale_y_spin = _add_spin_row(transform_grid, "Scale Y", 0.1, 10.0, 0.1)
	offset_x_spin = _add_spin_row(transform_grid, "Offset X", -1000.0, 1000.0, 1.0)
	offset_y_spin = _add_spin_row(transform_grid, "Offset Y", -1000.0, 1000.0, 1.0)

	var save_button := Button.new()
	save_button.text = "Применить внешний вид"
	save_button.pressed.connect(_save_appearance)
	form.add_child(save_button)

	var help := Label.new()
	help.text = "Предпросмотр проигрывает Idle. В бою этот sprite sheet полностью заменяет стандартный вид героя для выбранного заражения."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(help)

func _build_balance_tab(tabs: TabContainer) -> void:
	var page := HBoxContainer.new()
	page.name = "Баланс"
	tabs.add_child(page)

	var controls := VBoxContainer.new()
	controls.custom_minimum_size = Vector2(370.0, 0.0)
	page.add_child(controls)

	var title := Label.new()
	title.text = "Множители билда"
	controls.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	controls.add_child(grid)
	damage_multiplier_spin = _add_spin_row(grid, "Урон ×", 0.25, 3.0, 0.05)
	block_multiplier_spin = _add_spin_row(grid, "Блок ×", 0.25, 3.0, 0.05)
	incoming_multiplier_spin = _add_spin_row(grid, "Получаемый урон ×", 0.25, 2.0, 0.05)
	hp_bonus_spin = _add_spin_row(grid, "Бонус max HP", -100.0, 500.0, 1.0)
	energy_bonus_spin = _add_spin_row(grid, "Бонус энергии", -5.0, 10.0, 1.0)

	var resource_title := Label.new()
	resource_title.text = "Уникальный ресурс"
	controls.add_child(resource_title)

	var resource_grid := GridContainer.new()
	resource_grid.columns = 2
	controls.add_child(resource_grid)
	var id_label := Label.new()
	id_label.text = "ID ресурса"
	resource_grid.add_child(id_label)
	resource_id_edit = LineEdit.new()
	resource_grid.add_child(resource_id_edit)
	var name_label := Label.new()
	name_label.text = "Название"
	resource_grid.add_child(name_label)
	resource_name_edit = LineEdit.new()
	resource_grid.add_child(resource_name_edit)
	resource_start_spin = _add_spin_row(resource_grid, "Старт", 0.0, 999.0, 1.0)
	resource_max_spin = _add_spin_row(resource_grid, "Максимум", 0.0, 999.0, 1.0)
	var icon_label := Label.new()
	icon_label.text = "Иконка"
	resource_grid.add_child(icon_label)
	resource_icon_picker = EditorResourcePicker.new()
	resource_icon_picker.base_type = "Texture2D"
	resource_grid.add_child(resource_icon_picker)

	var save_button := Button.new()
	save_button.text = "Сохранить баланс"
	save_button.pressed.connect(_save_balance)
	controls.add_child(save_button)

	var recalc_button := Button.new()
	recalc_button.text = "Пересчитать силу"
	recalc_button.pressed.connect(_update_power_score)
	controls.add_child(recalc_button)

	power_label = RichTextLabel.new()
	power_label.bbcode_enabled = true
	power_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(power_label)

func _build_passives_tab(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "Пассивки"
	tabs.add_child(page)

	var toolbar := HBoxContainer.new()
	page.add_child(toolbar)

	var add_button := Button.new()
	add_button.text = "+ Пассивка"
	add_button.pressed.connect(_add_passive)
	toolbar.add_child(add_button)

	passive_open_button = Button.new()
	passive_open_button.text = "Редактировать"
	passive_open_button.disabled = true
	passive_open_button.pressed.connect(_open_passive)
	toolbar.add_child(passive_open_button)

	passive_delete_button = Button.new()
	passive_delete_button.text = "Удалить"
	passive_delete_button.disabled = true
	passive_delete_button.pressed.connect(_delete_passive)
	toolbar.add_child(passive_delete_button)

	var hint := Label.new()
	hint.text = "Параметры пассивки задаются здесь как Resource, а игрок прокачивает её в журнале."
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toolbar.add_child(hint)

	passive_tree = Tree.new()
	passive_tree.columns = 4
	passive_tree.set_column_title(0, "Название")
	passive_tree.set_column_title(1, "Эффект")
	passive_tree.set_column_title(2, "На уровень")
	passive_tree.set_column_title(3, "Уровни")
	passive_tree.column_titles_visible = true
	passive_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	passive_tree.item_selected.connect(_on_passive_selected)
	passive_tree.item_activated.connect(_open_passive)
	page.add_child(passive_tree)

func _add_spin_row(parent: GridContainer, label_text: String, minimum: float, maximum: float, step: float) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spin)
	return spin

func _create_new_build_dialog() -> void:
	create_dialog = ConfirmationDialog.new()
	create_dialog.title = "Новый билд"
	create_dialog.ok_button_text = "Создать"
	create_dialog.confirmed.connect(_create_build)
	add_child(create_dialog)

	var form := VBoxContainer.new()
	form.custom_minimum_size = Vector2(420.0, 120.0)
	create_dialog.add_child(form)

	var id_label := Label.new()
	id_label.text = "ID (латиница, например plague_doctor)"
	form.add_child(id_label)
	id_edit = LineEdit.new()
	id_edit.placeholder_text = "new_build"
	form.add_child(id_edit)

	var name_label := Label.new()
	name_label.text = "Название"
	form.add_child(name_label)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Новый билд"
	form.add_child(name_edit)

func _show_create_dialog() -> void:
	id_edit.text = ""
	name_edit.text = ""
	create_dialog.popup_centered(Vector2i(460, 220))
	id_edit.grab_focus()

func _create_build() -> void:
	var build_id: String = _sanitize_id(id_edit.text)
	if build_id.is_empty():
		push_warning("Build Editor: ID билда пустой.")
		return

	var path := "%s/%s.tres" % [BUILD_DIR, build_id]
	if ResourceLoader.exists(path):
		push_warning("Build Editor: ресурс уже существует: %s" % path)
		return

	var build = _new_script_resource(CONTAMINATION_DATA_PATH)
	build.id = StringName(build_id)
	build.display_name = name_edit.text.strip_edges() if not name_edit.text.strip_edges().is_empty() else build_id.capitalize()
	build.activation_card_id = "con_%s" % build_id
	build.balance = _new_script_resource(BALANCE_DATA_PATH)

	var attack = _new_script_resource(ABILITY_DATA_PATH)
	attack.id = StringName("%s_attack" % build_id)
	attack.display_name = "Атакующая способность"

	var defense = _new_script_resource(ABILITY_DATA_PATH)
	defense.id = StringName("%s_defense" % build_id)
	defense.display_name = "Защитная способность"
	defense.target_type = 1

	var utility = _new_script_resource(ABILITY_DATA_PATH)
	utility.id = StringName("%s_utility" % build_id)
	utility.display_name = "Утилити-способность"
	utility.target_type = 1
	utility.consumes_turn = false

	build.abilities.clear()
	build.abilities.append(attack)
	build.abilities.append(defense)
	build.abilities.append(utility)
	var error: Error = ResourceSaver.save(build, path)
	if error != OK:
		push_error("Build Editor: не удалось сохранить билд: %s" % error_string(error))
		return

	_scan_filesystem()
	_refresh_builds()
	_select_path(path)

func _create_infection_card() -> void:
	var build = _get_selected_build()
	if build == null:
		return

	var card_id := "con_%s" % String(build.id)
	var path := "%s/%s.tres" % [CARD_DIR, card_id]
	if ResourceLoader.exists(path):
		var existing = load(path)
		if existing:
			existing.contamination = build
			ResourceSaver.save(existing, path)
			build.activation_card_id = existing.id
			ResourceSaver.save(build, build.resource_path)
			editor_interface.edit_resource(existing)
			return

	var card = _new_script_resource(CARD_DATA_PATH)
	card.id = card_id
	card.name = "Заражение: %s" % build.display_name
	card.type = "infection"
	card.build_id = build.id
	card.cost = 3
	card.target_type = 1
	card.description = build.description
	card.contamination = build

	var error: Error = ResourceSaver.save(card, path)
	if error != OK:
		push_error("Build Editor: не удалось сохранить карту заражения: %s" % error_string(error))
		return

	build.activation_card_id = card.id
	ResourceSaver.save(build, build.resource_path)
	_scan_filesystem()
	editor_interface.edit_resource(card)
	_update_summary(build)

func _create_build_card() -> void:
	var build = _get_selected_build()
	if build == null:
		return

	var base_id := "%s_card" % String(build.id)
	var index: int = 1
	var path := "%s/%s_%d.tres" % [CARD_DIR, base_id, index]
	while ResourceLoader.exists(path):
		index += 1
		path = "%s/%s_%d.tres" % [CARD_DIR, base_id, index]

	var card = _new_script_resource(CARD_DATA_PATH)
	card.id = "%s_%d" % [base_id, index]
	card.name = "Новая карта: %s" % build.display_name
	card.type = "skill"
	card.build_id = build.id
	card.target_type = 0
	card.description = "Описание карты"

	var error: Error = ResourceSaver.save(card, path)
	if error != OK:
		push_error("Build Editor: не удалось сохранить карту: %s" % error_string(error))
		return

	var saved_card = load(path)
	build.exclusive_cards.append(saved_card if saved_card != null else card)
	ResourceSaver.save(build, build.resource_path)
	_scan_filesystem()
	editor_interface.edit_resource(card)
	_update_all_for_build(build)

func _refresh_builds() -> void:
	if build_list == null:
		return
	build_list.clear()
	selected_path = ""
	_set_build_buttons_enabled(false)

	var dir := DirAccess.open(BUILD_DIR)
	if dir == null:
		summary.text = "[color=yellow]Папка билдов не найдена.[/color]"
		return

	var paths: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.get_extension() == "tres":
			paths.append("%s/%s" % [BUILD_DIR, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort()

	for path in paths:
		var build = load(path)
		if build == null:
			continue
		var display_name: String = str(build.get("display_name"))
		var build_id: String = str(build.get("id"))
		var label: String = display_name if not display_name.is_empty() else build_id
		build_list.add_item(label)
		build_list.set_item_metadata(build_list.item_count - 1, path)

	if build_list.item_count == 0:
		summary.text = "[center]Билдов пока нет. Нажмите [b]Новый билд[/b].[/center]"
	else:
		build_list.select(0)
		_on_build_selected(0)

func _on_build_selected(index: int) -> void:
	selected_path = str(build_list.get_item_metadata(index))
	var build = _get_selected_build()
	_set_build_buttons_enabled(build != null)
	_update_all_for_build(build)

func _on_build_activated(index: int) -> void:
	_on_build_selected(index)
	_open_selected()

func _set_build_buttons_enabled(enabled: bool) -> void:
	inspector_button.disabled = not enabled
	infection_button.disabled = not enabled
	card_button.disabled = not enabled

func _open_selected() -> void:
	var build = _get_selected_build()
	if build != null and editor_interface != null:
		editor_interface.edit_resource(build)

func _get_selected_build():
	if selected_path.is_empty():
		return null
	return load(selected_path)

func _update_all_for_build(build) -> void:
	_update_summary(build)
	_load_appearance(build)
	_load_balance(build)
	_refresh_passives(build)
	_update_power_score()

func _update_summary(build) -> void:
	if build == null:
		summary.text = ""
		return

	var warnings: Array[String] = []
	if build.id == &"": warnings.append("Не задан ID")
	if build.abilities.size() != 3: warnings.append("Рекомендуется ровно 3 способности")
	if build.player_sprite_sheet == null: warnings.append("Не задан внешний вид героя")
	if build.passives.is_empty(): warnings.append("Нет пассивных способностей")

	var metrics: Dictionary = PowerCalculator.calculate(build)
	var text := "[font_size=22][b]%s[/b][/font_size]\n" % build.display_name
	text += "[color=gray]%s[/color]\n\n" % build.resource_path
	text += "[b]ID:[/b] %s\n" % String(build.id)
	text += "[b]Ресурс:[/b] %s (%s) — %d/%d\n" % [build.resource_display_name, String(build.resource_id), build.resource_start, build.resource_max]
	text += "[b]Карта активации:[/b] %s\n" % build.activation_card_id
	text += "[b]Карт:[/b] %d | [b]Пассивок:[/b] %d\n" % [build.exclusive_cards.size(), build.passives.size()]
	text += "[b]Расчётная сила:[/b] %.0f\n\n" % float(metrics.get("power", 0.0))
	text += "[b]Способности[/b]\n"
	for i in range(build.abilities.size()):
		var ability = build.abilities[i]
		if ability == null:
			text += "• %d. [color=red]<пусто>[/color]\n" % (i + 1)
		else:
			var resource_part: String = "" if ability.resource_cost <= 0 else ", ресурс %d" % ability.resource_cost
			text += "• %d. %s — %d энергии%s, КД %d\n" % [i + 1, ability.display_name, ability.energy_cost, resource_part, ability.cooldown]

	if warnings.is_empty():
		text += "\n[color=green]Проверка: OK[/color]"
	else:
		text += "\n[color=yellow][b]Замечания[/b][/color]\n"
		for warning in warnings:
			text += "• %s\n" % warning
	summary.text = text

func _load_appearance(build) -> void:
	_updating_ui = true
	sprite_preview.set_build(build)
	if build == null:
		sprite_picker.edited_resource = null
		_updating_ui = false
		return
	sprite_picker.edited_resource = build.player_sprite_sheet
	hframes_spin.value = build.player_hframes
	vframes_spin.value = build.player_vframes
	idle_frames_edit.text = _frames_to_text(build.idle_frames)
	attack_frames_edit.text = _frames_to_text(build.attack_frames)
	idle_fps_spin.value = build.idle_fps
	attack_fps_spin.value = build.attack_fps
	scale_x_spin.value = build.sprite_scale.x
	scale_y_spin.value = build.sprite_scale.y
	offset_x_spin.value = build.sprite_offset.x
	offset_y_spin.value = build.sprite_offset.y
	_updating_ui = false

func _save_appearance() -> void:
	var build = _get_selected_build()
	if build == null:
		return
	build.player_sprite_sheet = sprite_picker.edited_resource as Texture2D
	build.player_hframes = maxi(1, roundi(hframes_spin.value))
	build.player_vframes = maxi(1, roundi(vframes_spin.value))
	build.idle_frames = _parse_frames(idle_frames_edit.text, build.player_hframes * build.player_vframes)
	build.attack_frames = _parse_frames(attack_frames_edit.text, build.player_hframes * build.player_vframes)
	build.idle_fps = float(idle_fps_spin.value)
	build.attack_fps = float(attack_fps_spin.value)
	build.sprite_scale = Vector2(float(scale_x_spin.value), float(scale_y_spin.value))
	build.sprite_offset = Vector2(float(offset_x_spin.value), float(offset_y_spin.value))
	_save_build(build)
	sprite_preview.set_build(build)
	_update_summary(build)

func _load_balance(build) -> void:
	_updating_ui = true
	if build == null:
		_updating_ui = false
		return
	var balance = build.ensure_balance()
	damage_multiplier_spin.value = balance.damage_multiplier
	block_multiplier_spin.value = balance.block_multiplier
	incoming_multiplier_spin.value = balance.incoming_damage_multiplier
	hp_bonus_spin.value = balance.max_hp_bonus
	energy_bonus_spin.value = balance.energy_bonus
	resource_id_edit.text = String(build.resource_id)
	resource_name_edit.text = build.resource_display_name
	resource_start_spin.value = build.resource_start
	resource_max_spin.value = build.resource_max
	resource_icon_picker.edited_resource = build.resource_icon
	_updating_ui = false

func _save_balance() -> void:
	var build = _get_selected_build()
	if build == null:
		return
	var balance = build.ensure_balance()
	balance.damage_multiplier = float(damage_multiplier_spin.value)
	balance.block_multiplier = float(block_multiplier_spin.value)
	balance.incoming_damage_multiplier = float(incoming_multiplier_spin.value)
	balance.max_hp_bonus = roundi(hp_bonus_spin.value)
	balance.energy_bonus = roundi(energy_bonus_spin.value)
	build.resource_id = StringName(resource_id_edit.text.strip_edges())
	build.resource_display_name = resource_name_edit.text.strip_edges()
	build.resource_start = roundi(resource_start_spin.value)
	build.resource_max = maxi(roundi(resource_max_spin.value), build.resource_start)
	build.resource_icon = resource_icon_picker.edited_resource as Texture2D
	_save_build(build)
	_update_power_score()
	_update_summary(build)

func _update_power_score() -> void:
	if power_label == null:
		return
	var build = _get_selected_build()
	if build == null:
		power_label.text = ""
		return
	var result: Dictionary = PowerCalculator.calculate(build)
	var power: float = float(result.get("power", 0.0))
	var color := "green"
	if power > 125.0:
		color = "orange"
	if power > 165.0:
		color = "red"
	power_label.text = (
		"[font_size=22][b]Индекс силы: [color=%s]%.0f[/color][/b][/font_size]\n\n" % [color, power]
		+ "[b]Урон:[/b] %.0f\n" % float(result.get("offense", 0.0))
		+ "[b]Выживаемость:[/b] %.0f\n" % float(result.get("defense", 0.0))
		+ "[b]Утилити:[/b] %.0f\n\n" % float(result.get("utility", 0.0))
		+ "[color=gray]100 — ориентир среднего законченного билда. Индекс сравнивает ресурсы между собой и не заменяет плейтест.[/color]"
	)

func _refresh_passives(build) -> void:
	passive_tree.clear()
	passive_open_button.disabled = true
	passive_delete_button.disabled = true
	var root := passive_tree.create_item()
	if build == null:
		return
	for i in range(build.passives.size()):
		var passive = build.passives[i]
		if passive == null:
			continue
		var item := passive_tree.create_item(root)
		item.set_text(0, passive.display_name)
		item.set_text(1, passive.get_effect_name())
		item.set_text(2, passive.get_value_text(1))
		item.set_text(3, "%d (старт %d)" % [passive.max_level, passive.starting_level])
		item.set_metadata(0, i)

func _on_passive_selected() -> void:
	var selected := passive_tree.get_selected()
	var enabled: bool = selected != null
	passive_open_button.disabled = not enabled
	passive_delete_button.disabled = not enabled

func _add_passive() -> void:
	var build = _get_selected_build()
	if build == null:
		return
	var passive = _new_script_resource(PASSIVE_DATA_PATH)
	passive.id = StringName("passive_%d" % (build.passives.size() + 1))
	passive.display_name = "Новая пассивка"
	build.passives.append(passive)
	_save_build(build)
	_refresh_passives(build)
	_update_power_score()
	if editor_interface:
		editor_interface.edit_resource(passive)

func _get_selected_passive_index() -> int:
	var selected := passive_tree.get_selected()
	if selected == null:
		return -1
	return int(selected.get_metadata(0))

func _open_passive() -> void:
	var build = _get_selected_build()
	var index := _get_selected_passive_index()
	if build == null or index < 0 or index >= build.passives.size():
		return
	var passive = build.passives[index]
	if passive != null and editor_interface:
		editor_interface.edit_resource(passive)

func _delete_passive() -> void:
	var build = _get_selected_build()
	var index := _get_selected_passive_index()
	if build == null or index < 0 or index >= build.passives.size():
		return
	build.passives.remove_at(index)
	_save_build(build)
	_refresh_passives(build)
	_update_power_score()
	_update_summary(build)

func _save_build(build) -> void:
	if build == null or build.resource_path.is_empty():
		return
	var error := ResourceSaver.save(build, build.resource_path)
	if error != OK:
		push_error("Build Editor: ошибка сохранения: %s" % error_string(error))
	_scan_filesystem()

func _frames_to_text(frames: PackedInt32Array) -> String:
	var parts: PackedStringArray = []
	for frame in frames:
		parts.append(str(frame))
	return ",".join(parts)

func _parse_frames(value: String, total_frames: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for part in value.split(",", false):
		var clean := part.strip_edges()
		if not clean.is_valid_int():
			continue
		var frame := int(clean)
		if frame >= 0 and frame < maxi(total_frames, 1):
			result.append(frame)
	return result

func _select_path(path: String) -> void:
	for i in range(build_list.item_count):
		if str(build_list.get_item_metadata(i)) == path:
			build_list.select(i)
			_on_build_selected(i)
			return

func _new_script_resource(script_path: String):
	var script := load(script_path) as Script
	if script == null or not script.can_instantiate():
		push_error("Build Editor: не удалось создать ресурс из %s" % script_path)
		return null
	return script.new()

func _ensure_directories() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BUILD_DIR))

func _scan_filesystem() -> void:
	if editor_interface != null:
		editor_interface.get_resource_filesystem().scan()

func _sanitize_id(value: String) -> String:
	var result := value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var regex := RegEx.new()
	regex.compile("[^a-z0-9_]+")
	result = regex.sub(result, "", true)
	while "__" in result:
		result = result.replace("__", "_")
	return result.trim_prefix("_").trim_suffix("_")

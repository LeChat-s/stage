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
const CardEditorScript = preload("res://addons/build_editor/build_card_editor.gd")

var editor_interface: EditorInterface
var build_list: ItemList
var build_search: LineEdit
var summary: RichTextLabel
var status_label: Label
var tabs: TabContainer
var inspector_button: Button
var infection_button: Button
var card_button: Button
var create_dialog: ConfirmationDialog
var id_edit: LineEdit
var name_edit: LineEdit
var selected_path: String = ""
var build_entries: Array[Dictionary] = []

var sprite_preview: Control
var sprite_picker: EditorResourcePicker
var hframes_spin: EditorSpinSlider
var vframes_spin: EditorSpinSlider
var idle_frames_edit: LineEdit
var attack_frames_edit: LineEdit
var idle_fps_spin: EditorSpinSlider
var attack_fps_spin: EditorSpinSlider
var scale_x_spin: EditorSpinSlider
var scale_y_spin: EditorSpinSlider
var offset_x_spin: EditorSpinSlider
var offset_y_spin: EditorSpinSlider
var preview_idle_button: Button
var preview_attack_button: Button
var preview_pause_button: Button

var damage_multiplier_spin: EditorSpinSlider
var block_multiplier_spin: EditorSpinSlider
var incoming_multiplier_spin: EditorSpinSlider
var hp_bonus_spin: EditorSpinSlider
var energy_bonus_spin: EditorSpinSlider
var resource_id_edit: LineEdit
var resource_name_edit: LineEdit
var resource_icon_picker: EditorResourcePicker
var resource_start_spin: EditorSpinSlider
var resource_max_spin: EditorSpinSlider
var power_label: RichTextLabel
var offense_bar: ProgressBar
var defense_bar: ProgressBar
var utility_bar: ProgressBar

var card_editor: Control

var passive_tree: Tree
var passive_open_button: Button
var passive_delete_button: Button
var _updating_ui: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(720.0, 430.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_ensure_directories()
	_build_ui()
	_refresh_builds()

func _build_ui() -> void:
	_build_header()
	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 220
	add_child(split)
	split.add_child(_build_sidebar())

	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.use_hidden_tabs_for_min_size = false
	tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	split.add_child(tabs)
	_build_overview_tab(tabs)
	_build_appearance_tab(tabs)
	_build_balance_tab(tabs)
	_build_cards_tab(tabs)
	_build_passives_tab(tabs)
	_apply_tab_icons()

	status_label = Label.new()
	status_label.text = "Готово"
	status_label.clip_text = true
	status_label.add_theme_font_size_override("font_size", 11)
	add_child(status_label)
	_create_new_build_dialog()

func _build_header() -> void:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	add_child(toolbar)
	var title := Label.new()
	title.text = "Конструктор билдов"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	toolbar.add_child(title)

	var new_button := _make_tool_button("Новый", &"Add", "Создать новый билд")
	new_button.pressed.connect(_show_create_dialog)
	toolbar.add_child(new_button)
	var refresh_button := _make_tool_button("", &"Reload", "Обновить список")
	refresh_button.pressed.connect(_refresh_builds)
	toolbar.add_child(refresh_button)

	inspector_button = _make_tool_button("Инспектор", &"Edit", "Открыть ресурс билда в Inspector")
	inspector_button.disabled = true
	inspector_button.pressed.connect(_open_selected)
	toolbar.add_child(inspector_button)
	infection_button = _make_tool_button("Заражение", &"ResourcePreloader", "Создать или открыть карту заражения")
	infection_button.disabled = true
	infection_button.pressed.connect(_create_infection_card)
	toolbar.add_child(infection_button)
	card_button = _make_tool_button("+ Карта", &"Add", "Создать карту текущего билда")
	card_button.disabled = true
	card_button.pressed.connect(_create_build_card)
	toolbar.add_child(card_button)

func _build_sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190.0, 0.0)
	var margin := MarginContainer.new()
	_add_margins(margin, 6)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	var caption := Label.new()
	caption.text = "БИЛДЫ"
	caption.add_theme_font_size_override("font_size", 11)
	box.add_child(caption)
	build_search = LineEdit.new()
	build_search.placeholder_text = "Фильтр…"
	build_search.clear_button_enabled = true
	build_search.text_changed.connect(_on_build_search_changed)
	box.add_child(build_search)
	build_list = ItemList.new()
	build_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_list.select_mode = ItemList.SELECT_SINGLE
	build_list.item_selected.connect(_on_build_selected)
	build_list.item_activated.connect(_on_build_activated)
	box.add_child(build_list)
	var hint := Label.new()
	hint.text = "Двойной клик — Inspector"
	hint.add_theme_font_size_override("font_size", 10)
	box.add_child(hint)
	return panel

func _build_overview_tab(parent_tabs: TabContainer) -> void:
	var page := MarginContainer.new()
	page.name = "Обзор"
	_add_margins(page, 8)
	parent_tabs.add_child(page)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	page.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var title := Label.new()
	title.text = "Сводка билда"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	top.add_child(title)
	var open_button := _make_tool_button("Открыть ресурс", &"Edit", "Открыть билд в Inspector")
	open_button.pressed.connect(_open_selected)
	top.add_child(open_button)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(panel)
	var margin := MarginContainer.new()
	_add_margins(margin, 10)
	panel.add_child(margin)
	summary = RichTextLabel.new()
	summary.bbcode_enabled = true
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary.scroll_active = true
	margin.add_child(summary)
	var hint := Label.new()
	hint.text = "Карты и способности детально редактируются в Inspector. Основные параметры собраны во вкладках конструктора."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

func _build_appearance_tab(parent_tabs: TabContainer) -> void:
	var page := HSplitContainer.new()
	page.name = "Внешность"
	page.split_offset = 350
	parent_tabs.add_child(page)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(300.0, 0.0)
	page.add_child(preview_panel)
	var preview_margin := MarginContainer.new()
	_add_margins(preview_margin, 8)
	preview_panel.add_child(preview_margin)
	var preview_box := VBoxContainer.new()
	preview_box.add_theme_constant_override("separation", 6)
	preview_margin.add_child(preview_box)
	var preview_title := HBoxContainer.new()
	preview_box.add_child(preview_title)
	var label := Label.new()
	label.text = "Предпросмотр"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	preview_title.add_child(label)
	preview_idle_button = Button.new()
	preview_idle_button.text = "Idle"
	preview_idle_button.toggle_mode = true
	preview_idle_button.button_pressed = true
	preview_idle_button.pressed.connect(_preview_idle)
	preview_title.add_child(preview_idle_button)
	preview_attack_button = Button.new()
	preview_attack_button.text = "Attack"
	preview_attack_button.toggle_mode = true
	preview_attack_button.pressed.connect(_preview_attack)
	preview_title.add_child(preview_attack_button)
	preview_pause_button = _make_tool_button("", &"Pause", "Пауза / продолжить")
	preview_pause_button.toggle_mode = true
	preview_pause_button.toggled.connect(_preview_pause_toggled)
	preview_title.add_child(preview_pause_button)

	sprite_preview = PreviewScript.new()
	sprite_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite_preview.custom_minimum_size = Vector2(300.0, 280.0)
	preview_box.add_child(sprite_preview)
	var pixel_note := Label.new()
	pixel_note.text = "Pixel Perfect · NEAREST · целочисленный zoom"
	pixel_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pixel_note.add_theme_font_size_override("font_size", 10)
	preview_box.add_child(pixel_note)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 6)
	scroll.add_child(form)

	var sprite_section := _make_fold(form, "Sprite sheet", false)
	sprite_picker = EditorResourcePicker.new()
	sprite_picker.base_type = "Texture2D"
	sprite_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_picker.resource_changed.connect(_on_sprite_resource_changed)
	sprite_section.add_child(sprite_picker)

	var frames_section := _make_fold(form, "Разметка и анимации", false)
	hframes_spin = _add_editor_slider(frames_section, "Колонки", 1.0, 64.0, 1.0, true)
	vframes_spin = _add_editor_slider(frames_section, "Строки", 1.0, 64.0, 1.0, true)
	idle_fps_spin = _add_editor_slider(frames_section, "Idle FPS", 1.0, 60.0, 0.5, false, "fps")
	attack_fps_spin = _add_editor_slider(frames_section, "Attack FPS", 1.0, 60.0, 0.5, false, "fps")
	var idle_label := Label.new()
	idle_label.text = "Idle кадры"
	frames_section.add_child(idle_label)
	idle_frames_edit = LineEdit.new()
	idle_frames_edit.placeholder_text = "0,1,2,3,4"
	frames_section.add_child(idle_frames_edit)
	var attack_label := Label.new()
	attack_label.text = "Attack кадры"
	frames_section.add_child(attack_label)
	attack_frames_edit = LineEdit.new()
	attack_frames_edit.placeholder_text = "5,6,7,8"
	frames_section.add_child(attack_frames_edit)

	var transform_section := _make_fold(form, "Трансформация в бою", true)
	scale_x_spin = _add_editor_slider(transform_section, "Scale X", 0.1, 10.0, 0.1)
	scale_y_spin = _add_editor_slider(transform_section, "Scale Y", 0.1, 10.0, 0.1)
	offset_x_spin = _add_editor_slider(transform_section, "Offset X", -1000.0, 1000.0, 1.0, true, "px")
	offset_y_spin = _add_editor_slider(transform_section, "Offset Y", -1000.0, 1000.0, 1.0, true, "px")

	var apply_row := HBoxContainer.new()
	form.add_child(apply_row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_row.add_child(spacer)
	var save_button := _make_tool_button("Применить внешний вид", &"Save", "Сохранить параметры внешности")
	save_button.pressed.connect(_save_appearance)
	apply_row.add_child(save_button)

func _build_balance_tab(parent_tabs: TabContainer) -> void:
	var page := HSplitContainer.new()
	page.name = "Баланс"
	page.split_offset = 400
	parent_tabs.add_child(page)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 6)
	scroll.add_child(controls)

	var multiplier_section := _make_fold(controls, "Множители", false)
	damage_multiplier_spin = _add_editor_slider(multiplier_section, "Урон", 0.25, 3.0, 0.05, false, "×")
	block_multiplier_spin = _add_editor_slider(multiplier_section, "Блок", 0.25, 3.0, 0.05, false, "×")
	incoming_multiplier_spin = _add_editor_slider(multiplier_section, "Получаемый урон", 0.25, 2.0, 0.05, false, "×")
	var base_section := _make_fold(controls, "Базовые параметры", false)
	hp_bonus_spin = _add_editor_slider(base_section, "Бонус max HP", -100.0, 500.0, 1.0, true, "HP")
	energy_bonus_spin = _add_editor_slider(base_section, "Бонус энергии", -5.0, 10.0, 1.0, true)
	var resource_section := _make_fold(controls, "Уникальный ресурс", false)
	resource_id_edit = _add_line_row(resource_section, "ID ресурса", "charge")
	resource_name_edit = _add_line_row(resource_section, "Название", "Заряд")
	resource_start_spin = _add_editor_slider(resource_section, "Старт", 0.0, 999.0, 1.0, true)
	resource_max_spin = _add_editor_slider(resource_section, "Максимум", 0.0, 999.0, 1.0, true)
	var icon_label := Label.new()
	icon_label.text = "Иконка ресурса"
	resource_section.add_child(icon_label)
	resource_icon_picker = EditorResourcePicker.new()
	resource_icon_picker.base_type = "Texture2D"
	resource_icon_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_section.add_child(resource_icon_picker)
	var apply_row := HBoxContainer.new()
	controls.add_child(apply_row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_row.add_child(spacer)
	var save_button := _make_tool_button("Сохранить баланс", &"Save", "Сохранить баланс билда")
	save_button.pressed.connect(_save_balance)
	apply_row.add_child(save_button)

	var power_panel := PanelContainer.new()
	power_panel.custom_minimum_size = Vector2(280.0, 0.0)
	page.add_child(power_panel)
	var power_margin := MarginContainer.new()
	_add_margins(power_margin, 12)
	power_panel.add_child(power_margin)
	var power_box := VBoxContainer.new()
	power_box.add_theme_constant_override("separation", 8)
	power_margin.add_child(power_box)
	var power_title := Label.new()
	power_title.text = "Оценка силы"
	power_title.add_theme_font_size_override("font_size", 18)
	power_box.add_child(power_title)
	power_label = RichTextLabel.new()
	power_label.bbcode_enabled = true
	power_label.fit_content = true
	power_label.custom_minimum_size.y = 105.0
	power_box.add_child(power_label)
	offense_bar = _add_metric_bar(power_box, "Урон")
	defense_bar = _add_metric_bar(power_box, "Выживаемость")
	utility_bar = _add_metric_bar(power_box, "Утилити")
	var recalc_button := _make_tool_button("Пересчитать", &"Reload", "Пересчитать индекс силы")
	recalc_button.pressed.connect(_update_power_score)
	power_box.add_child(recalc_button)
	var note := Label.new()
	note.text = "100 — ориентир среднего законченного билда. Индекс полезен для сравнения, но не заменяет плейтест."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	power_box.add_child(note)

func _build_cards_tab(parent_tabs: TabContainer) -> void:
	card_editor = CardEditorScript.new()
	card_editor.name = "Карты"
	card_editor.set("editor_interface", editor_interface)
	parent_tabs.add_child(card_editor)

func _build_passives_tab(parent_tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "Пассивки"
	page.add_theme_constant_override("separation", 6)
	parent_tabs.add_child(page)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	page.add_child(toolbar)
	var add_button := _make_tool_button("Добавить", &"Add", "Добавить пассивку")
	add_button.pressed.connect(_add_passive)
	toolbar.add_child(add_button)
	passive_open_button = _make_tool_button("Открыть", &"Edit", "Открыть пассивку в Inspector")
	passive_open_button.disabled = true
	passive_open_button.pressed.connect(_open_passive)
	toolbar.add_child(passive_open_button)
	passive_delete_button = _make_tool_button("Удалить", &"Remove", "Удалить пассивку из билда")
	passive_delete_button.disabled = true
	passive_delete_button.pressed.connect(_delete_passive)
	toolbar.add_child(passive_delete_button)
	var hint := Label.new()
	hint.text = "Прокачка уровней происходит в журнале"
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
	passive_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	passive_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	passive_tree.set_column_expand(0, true)
	passive_tree.set_column_expand(1, true)
	passive_tree.set_column_expand(2, false)
	passive_tree.set_column_expand(3, false)
	passive_tree.set_column_custom_minimum_width(2, 95)
	passive_tree.set_column_custom_minimum_width(3, 110)
	passive_tree.item_selected.connect(_on_passive_selected)
	passive_tree.item_activated.connect(_open_passive)
	page.add_child(passive_tree)

func _apply_tab_icons() -> void:
	var icon_names: Array[StringName] = [&"Info", &"Sprite2D", &"Curve", &"FileThumbnail", &"AnimationTrackList"]
	for i in range(mini(tabs.get_tab_count(), icon_names.size())):
		var icon: Texture2D = _editor_icon(icon_names[i])
		if icon != null:
			tabs.set_tab_icon(i, icon)
			tabs.set_tab_icon_max_width(i, 16)

func _make_fold(parent: Control, title_text: String, start_folded: bool) -> VBoxContainer:
	var fold := FoldableContainer.new()
	fold.title = title_text
	fold.folded = start_folded
	fold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(fold)
	var margin := MarginContainer.new()
	_add_margins(margin, 8)
	fold.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)
	return box

func _add_editor_slider(parent: Control, label_text: String, minimum: float, maximum: float, step_value: float, integer: bool = false, suffix_text: String = "") -> EditorSpinSlider:
	var slider := EditorSpinSlider.new()
	slider.label = label_text
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_value
	slider.editing_integer = integer
	slider.suffix = suffix_text
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(slider)
	return slider

func _add_line_row(parent: Control, label_text: String, placeholder: String) -> LineEdit:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(edit)
	return edit

func _add_metric_bar(parent: Control, title_text: String) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = title_text
	label.custom_minimum_size.x = 110.0
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 200.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	return bar

func _make_tool_button(text_value: String, icon_name: StringName, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.tooltip_text = tooltip
	button.flat = true
	var icon: Texture2D = _editor_icon(icon_name)
	if icon != null:
		button.icon = icon
	return button

func _editor_icon(icon_name: StringName) -> Texture2D:
	if has_theme_icon(icon_name, &"EditorIcons"):
		return get_theme_icon(icon_name, &"EditorIcons")
	return null

func _add_margins(container: MarginContainer, amount: int) -> void:
	container.add_theme_constant_override("margin_left", amount)
	container.add_theme_constant_override("margin_top", amount)
	container.add_theme_constant_override("margin_right", amount)
	container.add_theme_constant_override("margin_bottom", amount)

func _create_new_build_dialog() -> void:
	create_dialog = ConfirmationDialog.new()
	create_dialog.title = "Новый билд"
	create_dialog.ok_button_text = "Создать"
	create_dialog.confirmed.connect(_create_build)
	add_child(create_dialog)
	var form := VBoxContainer.new()
	form.custom_minimum_size = Vector2(420.0, 120.0)
	form.add_theme_constant_override("separation", 6)
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
	var path: String = "%s/%s.tres" % [BUILD_DIR, build_id]
	if ResourceLoader.exists(path):
		push_warning("Build Editor: ресурс уже существует: %s" % path)
		return
	var build = _new_script_resource(CONTAMINATION_DATA_PATH)
	if build == null:
		return
	build.id = StringName(build_id)
	build.display_name = name_edit.text.strip_edges() if not name_edit.text.strip_edges().is_empty() else build_id.capitalize()
	build.activation_card_id = "con_%s" % build_id
	build.balance = _new_script_resource(BALANCE_DATA_PATH)
	var attack = _new_script_resource(ABILITY_DATA_PATH)
	var defense = _new_script_resource(ABILITY_DATA_PATH)
	var utility = _new_script_resource(ABILITY_DATA_PATH)
	if attack == null or defense == null or utility == null:
		return
	attack.id = StringName("%s_attack" % build_id)
	attack.display_name = "Атакующая способность"
	defense.id = StringName("%s_defense" % build_id)
	defense.display_name = "Защитная способность"
	defense.target_type = 1
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
	_set_status("Создан билд: %s" % build.display_name)

func _create_infection_card() -> void:
	var build = _get_selected_build()
	if build == null:
		return
	var card_id: String = "con_%s" % String(build.id)
	var path: String = "%s/%s.tres" % [CARD_DIR, card_id]
	if ResourceLoader.exists(path):
		var existing = load(path)
		if existing != null:
			existing.build_id = build.id
			existing.contamination = build
			ResourceSaver.save(existing, path)
			build.activation_card_id = existing.id
			ResourceSaver.save(build, build.resource_path)
			if card_editor != null:
				card_editor.set_build(build)
				card_editor.select_card_path(path)
				tabs.current_tab = 3
			_set_status("Открыта карта заражения")
			return
	var card = _new_script_resource(CARD_DATA_PATH)
	if card == null:
		return
	card.id = card_id
	card.name = "Заражение: %s" % build.display_name
	card.type = "infection"
	card.build_id = build.id
	card.cost = 3
	card.target_type = 1
	card.description = build.description
	card.contamination = build
	if ResourceLoader.exists("res://assets/card/contamination_base.png"):
		card.artwork = load("res://assets/card/contamination_base.png") as Texture2D
	var error: Error = ResourceSaver.save(card, path)
	if error != OK:
		push_error("Build Editor: не удалось сохранить карту заражения: %s" % error_string(error))
		return
	build.activation_card_id = card.id
	ResourceSaver.save(build, build.resource_path)
	_scan_filesystem()
	if card_editor != null:
		card_editor.set_build(build)
		card_editor.select_card_path(path)
		tabs.current_tab = 3
	_update_summary(build)
	_set_status("Создана карта заражения")

func _create_build_card() -> void:
	var build = _get_selected_build()
	if build == null:
		return
	var base_id: String = "%s_card" % String(build.id)
	var index: int = 1
	var path: String = "%s/%s_%d.tres" % [CARD_DIR, base_id, index]
	while ResourceLoader.exists(path):
		index += 1
		path = "%s/%s_%d.tres" % [CARD_DIR, base_id, index]
	var card = _new_script_resource(CARD_DATA_PATH)
	if card == null:
		return
	card.id = "%s_%d" % [base_id, index]
	card.name = "Новая карта: %s" % build.display_name
	card.type = "event"
	card.build_id = build.id
	card.target_type = 0
	card.description = "Описание карты"
	if ResourceLoader.exists("res://assets/card/event_base.png"):
		card.artwork = load("res://assets/card/event_base.png") as Texture2D
	var error: Error = ResourceSaver.save(card, path)
	if error != OK:
		push_error("Build Editor: не удалось сохранить карту: %s" % error_string(error))
		return
	var saved_card = load(path)
	build.exclusive_cards.append(saved_card if saved_card != null else card)
	ResourceSaver.save(build, build.resource_path)
	_scan_filesystem()
	_update_all_for_build(build)
	if card_editor != null:
		card_editor.select_card_path(path)
		tabs.current_tab = 3
	_set_status("Создана карта: %s" % card.name)

func _refresh_builds() -> void:
	if build_list == null:
		return
	build_entries.clear()
	selected_path = ""
	_set_build_buttons_enabled(false)
	var dir := DirAccess.open(BUILD_DIR)
	if dir == null:
		build_list.clear()
		if summary != null:
			summary.text = "[color=yellow]Папка билдов не найдена.[/color]"
		return
	var paths: Array[String] = []
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
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
		var metrics: Dictionary = PowerCalculator.calculate(build)
		var power: float = float(metrics.get("power", 0.0))
		var icon: Texture2D = build.get("icon") as Texture2D
		build_entries.append({"path": path, "label": label, "id": build_id, "power": power, "icon": icon})
	_apply_build_filter()

func _apply_build_filter() -> void:
	build_list.clear()
	var query: String = build_search.text.strip_edges().to_lower() if build_search != null else ""
	for entry in build_entries:
		var label: String = str(entry.get("label", ""))
		var build_id: String = str(entry.get("id", ""))
		if not query.is_empty() and query not in label.to_lower() and query not in build_id.to_lower():
			continue
		var power: float = float(entry.get("power", 0.0))
		var item_text: String = "%s   %.0f" % [label, power]
		var icon: Texture2D = entry.get("icon") as Texture2D
		build_list.add_item(item_text, icon)
		build_list.set_item_metadata(build_list.item_count - 1, str(entry.get("path", "")))
		build_list.set_item_tooltip(build_list.item_count - 1, "%s\nID: %s\nСила: %.0f" % [label, build_id, power])
	if build_list.item_count == 0:
		selected_path = ""
		_set_build_buttons_enabled(false)
		_update_all_for_build(null)
		_set_status("Билды не найдены")
		return
	build_list.select(0)
	_on_build_selected(0)

func _on_build_search_changed(_value: String) -> void:
	_apply_build_filter()

func _on_build_selected(index: int) -> void:
	selected_path = str(build_list.get_item_metadata(index))
	var build = _get_selected_build()
	_set_build_buttons_enabled(build != null)
	_update_all_for_build(build)
	if build != null:
		_set_status(build.resource_path)

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
	if card_editor != null:
		card_editor.set_build(build)
	_refresh_passives(build)
	_update_power_score()

func _update_summary(build) -> void:
	if summary == null:
		return
	if build == null:
		summary.text = "[center][color=gray]Выберите билд слева[/color][/center]"
		return
	var warnings: Array[String] = []
	if build.id == &"": warnings.append("Не задан ID")
	if build.abilities.size() != 3: warnings.append("Рекомендуется ровно 3 способности")
	if build.player_sprite_sheet == null: warnings.append("Не задан внешний вид героя")
	if build.passives.is_empty(): warnings.append("Нет пассивных способностей")
	var metrics: Dictionary = PowerCalculator.calculate(build)
	var text: String = "[font_size=24][b]%s[/b][/font_size]\n" % build.display_name
	text += "[color=gray]%s[/color]\n\n" % build.resource_path
	text += "[table=2]"
	text += "[cell][b]ID[/b][/cell][cell]%s[/cell]" % String(build.id)
	text += "[cell][b]Ресурс[/b][/cell][cell]%s (%s) · %d/%d[/cell]" % [build.resource_display_name, String(build.resource_id), build.resource_start, build.resource_max]
	text += "[cell][b]Карта активации[/b][/cell][cell]%s[/cell]" % build.activation_card_id
	text += "[cell][b]Контент[/b][/cell][cell]%d карт · %d пассивок[/cell]" % [build.exclusive_cards.size(), build.passives.size()]
	text += "[cell][b]Индекс силы[/b][/cell][cell]%.0f[/cell]" % float(metrics.get("power", 0.0))
	text += "[/table]\n\n[b]Способности[/b]\n"
	for i in range(build.abilities.size()):
		var ability = build.abilities[i]
		if ability == null:
			text += "  %d. [color=red]<пусто>[/color]\n" % (i + 1)
		else:
			var resource_part: String = "" if ability.resource_cost <= 0 else ", ресурс %d" % ability.resource_cost
			text += "  %d. %s — %d энергии%s, КД %d\n" % [i + 1, ability.display_name, ability.energy_cost, resource_part, ability.cooldown]
	if warnings.is_empty():
		text += "\n[color=green]● Конфигурация выглядит корректно[/color]"
	else:
		text += "\n[color=yellow][b]Замечания[/b][/color]\n"
		for warning in warnings:
			text += "  • %s\n" % warning
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

func _on_sprite_resource_changed(resource: Resource) -> void:
	if not _updating_ui:
		sprite_preview.set_texture_override(resource as Texture2D)

func _preview_idle() -> void:
	preview_idle_button.button_pressed = true
	preview_attack_button.button_pressed = false
	sprite_preview.set_animation_mode(0)

func _preview_attack() -> void:
	preview_idle_button.button_pressed = false
	preview_attack_button.button_pressed = true
	sprite_preview.set_animation_mode(1)

func _preview_pause_toggled(value: bool) -> void:
	sprite_preview.set_paused(value)
	var icon_name: StringName = &"Play" if value else &"Pause"
	var icon: Texture2D = _editor_icon(icon_name)
	if icon != null:
		preview_pause_button.icon = icon

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
	_set_status("Внешний вид сохранён")

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
	_refresh_builds_preserve_selection()
	_set_status("Баланс сохранён")

func _update_power_score() -> void:
	if power_label == null:
		return
	var build = _get_selected_build()
	if build == null:
		power_label.text = ""
		offense_bar.value = 0.0
		defense_bar.value = 0.0
		utility_bar.value = 0.0
		return
	var result: Dictionary = PowerCalculator.calculate(build)
	var power: float = float(result.get("power", 0.0))
	var offense: float = float(result.get("offense", 0.0))
	var defense: float = float(result.get("defense", 0.0))
	var utility: float = float(result.get("utility", 0.0))
	var color: String = "green"
	if power > 125.0: color = "orange"
	if power > 165.0: color = "red"
	power_label.text = "[font_size=26][b][color=%s]%.0f[/color][/b][/font_size]\nРасчётный индекс силы" % [color, power]
	offense_bar.value = clampf(offense, 0.0, offense_bar.max_value)
	defense_bar.value = clampf(defense, 0.0, defense_bar.max_value)
	utility_bar.value = clampf(utility, 0.0, utility_bar.max_value)

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
	if passive == null:
		return
	passive.id = StringName("passive_%d" % (build.passives.size() + 1))
	passive.display_name = "Новая пассивка"
	build.passives.append(passive)
	_save_build(build)
	_refresh_passives(build)
	_update_power_score()
	if editor_interface != null:
		editor_interface.edit_resource(passive)
	_set_status("Добавлена пассивка")

func _get_selected_passive_index() -> int:
	var selected := passive_tree.get_selected()
	if selected == null:
		return -1
	return int(selected.get_metadata(0))

func _open_passive() -> void:
	var build = _get_selected_build()
	var index: int = _get_selected_passive_index()
	if build == null or index < 0 or index >= build.passives.size():
		return
	var passive = build.passives[index]
	if passive != null and editor_interface != null:
		editor_interface.edit_resource(passive)

func _delete_passive() -> void:
	var build = _get_selected_build()
	var index: int = _get_selected_passive_index()
	if build == null or index < 0 or index >= build.passives.size():
		return
	build.passives.remove_at(index)
	_save_build(build)
	_refresh_passives(build)
	_update_power_score()
	_update_summary(build)
	_set_status("Пассивка удалена")

func _save_build(build) -> void:
	if build == null or build.resource_path.is_empty():
		return
	var error: Error = ResourceSaver.save(build, build.resource_path)
	if error != OK:
		push_error("Build Editor: ошибка сохранения: %s" % error_string(error))
		return
	_scan_filesystem()

func _refresh_builds_preserve_selection() -> void:
	var path: String = selected_path
	_refresh_builds()
	if not path.is_empty():
		_select_path(path)

func _frames_to_text(frames: PackedInt32Array) -> String:
	var parts: PackedStringArray = []
	for frame in frames:
		parts.append(str(frame))
	return ",".join(parts)

func _parse_frames(value: String, total_frames: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for part in value.split(",", false):
		var clean: String = part.strip_edges()
		if not clean.is_valid_int():
			continue
		var frame: int = int(clean)
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
	var script: Script = load(script_path) as Script
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
	var result: String = value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var regex := RegEx.new()
	regex.compile("[^a-z0-9_]+")
	result = regex.sub(result, "", true)
	while "__" in result:
		result = result.replace("__", "_")
	return result.trim_prefix("_").trim_suffix("_")

func _set_status(value: String) -> void:
	if status_label != null:
		status_label.text = value

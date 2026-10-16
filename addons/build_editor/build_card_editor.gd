@tool
extends VBoxContainer

const CARD_DIR := "res://src/data/cards"
const CARD_DATA_PATH := "res://src/data/cards/cards_data.gd"
const PreviewScript = preload("res://addons/build_editor/build_card_preview.gd")
const CardFaceScript = preload("res://src/data/cards/card_face.gd")

const TYPE_ITEMS := [
	{"id": "attack", "label": "Атака", "template": "res://assets/card/attack_base.png"},
	{"id": "defense", "label": "Защита", "template": "res://assets/card/defend_base.png"},
	{"id": "event", "label": "Событие", "template": "res://assets/card/event_base.png"},
	{"id": "status", "label": "Статус", "template": "res://assets/card/status_effect_base.png"},
	{"id": "infection", "label": "Заражение", "template": "res://assets/card/contamination_base.png"},
]

var editor_interface: EditorInterface
var build = null
var selected_card = null
var selected_card_path: String = ""
var _loading: bool = false

var card_list: ItemList
var card_search: LineEdit
var preview: Control
var form_scroll: ScrollContainer

var id_edit: LineEdit
var name_edit: LineEdit
var type_option: OptionButton
var cost_spin: EditorSpinSlider
var damage_spin: EditorSpinSlider
var shield_spin: EditorSpinSlider
var damage_type_option: OptionButton
var target_option: OptionButton
var effect_type_edit: LineEdit
var description_edit: TextEdit
var artwork_picker: EditorResourcePicker
var starting_check: CheckBox

var title_size_spin: EditorSpinSlider
var title_color_picker: ColorPickerButton
var description_size_spin: EditorSpinSlider
var description_color_picker: ColorPickerButton
var cost_size_spin: EditorSpinSlider
var cost_color_picker: ColorPickerButton
var stats_size_spin: EditorSpinSlider
var stats_color_picker: ColorPickerButton

var effects_edit: TextEdit
var effects_error: Label
var save_button: Button
var open_button: Button

var add_menu: MenuButton

# Адаптивная компоновка без SplitContainer и перетаскиваемых разделителей.
var body: BoxContainer
var sidebar_panel: Control
var sidebar_box: BoxContainer
var preview_stack: VBoxContainer
var list_column: VBoxContainer
var workspace_box: VBoxContainer
var preview_open_button: Button
var form_grid: GridContainer
var workspace_title: Label
var workspace_meta: Label
var _layout_bucket: int = -1

# Детальный preview поверх редактора.
var detail_popup: PopupPanel
var detail_title: Label
var detail_face: CardFace
var detail_holder: Control
var detail_zoom_option: OptionButton

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_build_ui()
	_build_detail_popup()
	resized.connect(_update_responsive_layout)
	call_deferred("_update_responsive_layout")

func set_build(value) -> void:
	build = value
	selected_card = null
	selected_card_path = ""
	_refresh_cards()

func select_card_path(path: String) -> void:
	for i in range(card_list.item_count):
		if str(card_list.get_item_metadata(i)) == path:
			card_list.select(i)
			_on_card_selected(i)
			return

func _build_ui() -> void:
	body = BoxContainer.new()
	body.vertical = false
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	add_child(body)

	sidebar_panel = _build_card_sidebar()
	body.add_child(sidebar_panel)

	workspace_box = VBoxContainer.new()
	workspace_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace_box.add_theme_constant_override("separation", 8)
	body.add_child(workspace_box)

	# Компактный заголовок рабочей области: имя карты + основные действия.
	var workspace_header := PanelContainer.new()
	workspace_box.add_child(workspace_header)

	var header_margin := MarginContainer.new()
	_add_margins(header_margin, 8)
	workspace_header.add_child(header_margin)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	header_margin.add_child(header_row)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header_row.add_child(title_box)

	workspace_title = Label.new()
	workspace_title.text = "Выберите карту"
	workspace_title.add_theme_font_size_override("font_size", 16)
	title_box.add_child(workspace_title)

	workspace_meta = Label.new()
	workspace_meta.text = "Параметры карты"
	workspace_meta.add_theme_font_size_override("font_size", 10)
	if has_theme_color(&"font_disabled_color", &"Editor"):
		workspace_meta.add_theme_color_override(
			"font_color",
			get_theme_color(&"font_disabled_color", &"Editor")
		)
	title_box.add_child(workspace_meta)

	open_button = Button.new()
	open_button.text = "Inspector"
	open_button.flat = true
	open_button.disabled = true
	open_button.tooltip_text = "Открыть ресурс карты в Inspector"
	open_button.pressed.connect(_open_in_inspector)
	header_row.add_child(open_button)

	save_button = Button.new()
	save_button.text = "Сохранить"
	save_button.disabled = true
	save_button.tooltip_text = "Сохранить изменения карты"
	save_button.pressed.connect(_save_card)
	header_row.add_child(save_button)

	form_scroll = ScrollContainer.new()
	form_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	form_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	workspace_box.add_child(form_scroll)

	var form_root := VBoxContainer.new()
	form_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_root.add_theme_constant_override("separation", 10)
	form_scroll.add_child(form_root)

	form_grid = GridContainer.new()
	form_grid.columns = 2
	form_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_grid.add_theme_constant_override("h_separation", 10)
	form_grid.add_theme_constant_override("v_separation", 10)
	form_root.add_child(form_grid)

	_build_identity_form(form_grid)
	_build_combat_form(form_grid)
	_build_visual_form(form_grid)
	_build_text_style_form(form_grid)

	# Effects оставляем на всю ширину, чтобы JSON не зажимался в узкую колонку.
	_build_effects_form(form_root)

	type_option.item_selected.connect(_on_option_changed)
	damage_type_option.item_selected.connect(_on_option_changed)
	target_option.item_selected.connect(_on_option_changed)
	description_edit.text_changed.connect(_on_description_changed)
	artwork_picker.resource_changed.connect(_on_artwork_changed)


func _update_responsive_layout() -> void:
	if body == null or sidebar_panel == null or sidebar_box == null:
		return

	var bucket: int
	if size.x < 760.0:
		bucket = 0
	elif size.x < 1120.0:
		bucket = 1
	else:
		bucket = 2

	if bucket == _layout_bucket:
		return
	_layout_bucket = bucket

	match bucket:
		0:
			# Узкий dock: компактный rail превращается в верхнюю горизонтальную панель.
			body.vertical = true
			sidebar_panel.custom_minimum_size = Vector2(0.0, 205.0)
			sidebar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sidebar_panel.size_flags_vertical = Control.SIZE_FILL
			sidebar_box.vertical = false
			preview_stack.custom_minimum_size = Vector2(126.0, 0.0)
			list_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			form_grid.columns = 1

		1:
			# Обычный нижний dock: небольшой rail слева, форма справа.
			body.vertical = false
			sidebar_panel.custom_minimum_size = Vector2(205.0, 0.0)
			sidebar_panel.size_flags_horizontal = Control.SIZE_FILL
			sidebar_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			sidebar_box.vertical = true
			preview_stack.custom_minimum_size = Vector2(0.0, 192.0)
			form_grid.columns = 1

		_:
			# Широкое / floating окно.
			body.vertical = false
			sidebar_panel.custom_minimum_size = Vector2(220.0, 0.0)
			sidebar_panel.size_flags_horizontal = Control.SIZE_FILL
			sidebar_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
			sidebar_box.vertical = true
			preview_stack.custom_minimum_size = Vector2(0.0, 192.0)
			form_grid.columns = 2


func _build_detail_popup() -> void:
	detail_popup = PopupPanel.new()
	detail_popup.name = "CardDetailPopup"
	add_child(detail_popup)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	detail_popup.add_child(root)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	root.add_child(toolbar)

	detail_title = Label.new()
	detail_title.text = "Карта"
	detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_title.add_theme_font_size_override("font_size", 15)
	toolbar.add_child(detail_title)

	var zoom_label := Label.new()
	zoom_label.text = "Масштаб"
	toolbar.add_child(zoom_label)

	detail_zoom_option = OptionButton.new()
	for zoom in [1, 2, 3]:
		detail_zoom_option.add_item("%d×" % zoom)
		detail_zoom_option.set_item_metadata(detail_zoom_option.item_count - 1, zoom)
	detail_zoom_option.select(1)
	detail_zoom_option.item_selected.connect(_on_detail_zoom_changed)
	toolbar.add_child(detail_zoom_option)

	var close_button := Button.new()
	close_button.text = "Закрыть"
	close_button.pressed.connect(detail_popup.hide)
	toolbar.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440.0, 560.0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	detail_holder = Control.new()
	center.add_child(detail_holder)

	detail_face = CardFaceScript.new() as CardFace
	detail_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_holder.add_child(detail_face)

	_set_detail_zoom(2)


func _open_detail_preview() -> void:
	if selected_card == null or detail_popup == null:
		return

	detail_title.text = str(selected_card.get("name"))
	detail_face.set_card(selected_card)
	detail_face.set_draft(_make_preview_draft())

	var viewport_size: Vector2 = get_viewport_rect().size
	var width: int = mini(720, maxi(460, int(viewport_size.x * 0.82)))
	var height: int = mini(820, maxi(620, int(viewport_size.y * 0.86)))
	detail_popup.popup_centered(Vector2i(width, height))


func _on_detail_zoom_changed(index: int) -> void:
	if detail_zoom_option == null:
		return
	var zoom: int = int(detail_zoom_option.get_item_metadata(index))
	_set_detail_zoom(zoom)


func _set_detail_zoom(zoom: int) -> void:
	if detail_holder == null or detail_face == null:
		return

	var safe_zoom: int = clampi(zoom, 1, 3)
	var rendered: Vector2 = Vector2(212.0, 300.0) * float(safe_zoom)
	detail_holder.custom_minimum_size = rendered + Vector2(16.0, 16.0)
	detail_holder.size = detail_holder.custom_minimum_size
	detail_face.scale = Vector2.ONE * float(safe_zoom)
	detail_face.position = Vector2(8.0, 8.0)


func _build_card_sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(205.0, 0.0)

	var margin := MarginContainer.new()
	_add_margins(margin, 7)
	panel.add_child(margin)

	sidebar_box = BoxContainer.new()
	sidebar_box.vertical = true
	sidebar_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_box.add_theme_constant_override("separation", 8)
	margin.add_child(sidebar_box)

	# Preview занимает только реальный размер карты в руке: 106×150.
	preview_stack = VBoxContainer.new()
	preview_stack.custom_minimum_size = Vector2(0.0, 192.0)
	preview_stack.add_theme_constant_override("separation", 4)
	sidebar_box.add_child(preview_stack)

	var preview_header := HBoxContainer.new()
	preview_stack.add_child(preview_header)

	var preview_label := Label.new()
	preview_label.text = "КАРТА"
	preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_label.add_theme_font_size_override("font_size", 10)
	preview_header.add_child(preview_label)

	preview_open_button = Button.new()
	preview_open_button.text = "↗"
	preview_open_button.flat = true
	preview_open_button.disabled = true
	preview_open_button.tooltip_text = "Открыть крупный просмотр"
	preview_open_button.pressed.connect(_open_detail_preview)
	preview_header.add_child(preview_open_button)

	var preview_center := CenterContainer.new()
	preview_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_stack.add_child(preview_center)

	preview = PreviewScript.new()
	preview.custom_minimum_size = Vector2(114.0, 158.0)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview_center.add_child(preview)

	list_column = VBoxContainer.new()
	list_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_column.add_theme_constant_override("separation", 5)
	sidebar_box.add_child(list_column)

	var toolbar := HBoxContainer.new()
	list_column.add_child(toolbar)

	var title := Label.new()
	title.text = "КАРТЫ БИЛДА"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 10)
	toolbar.add_child(title)

	add_menu = MenuButton.new()
	add_menu.text = "+"
	add_menu.flat = true
	add_menu.tooltip_text = "Добавить карту"
	toolbar.add_child(add_menu)
	var popup := add_menu.get_popup()
	for i in range(TYPE_ITEMS.size()):
		popup.add_item(str(TYPE_ITEMS[i]["label"]), i)
	popup.id_pressed.connect(_create_card_of_type)

	var refresh := Button.new()
	refresh.text = "↻"
	refresh.flat = true
	refresh.tooltip_text = "Обновить список"
	refresh.pressed.connect(_refresh_cards)
	toolbar.add_child(refresh)

	card_search = LineEdit.new()
	card_search.placeholder_text = "Поиск карты…"
	card_search.clear_button_enabled = true
	card_search.text_changed.connect(_on_search_changed)
	list_column.add_child(card_search)

	card_list = ItemList.new()
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_list.allow_reselect = true
	card_list.item_selected.connect(_on_card_selected)
	card_list.item_activated.connect(_on_card_activated)
	list_column.add_child(card_list)

	return panel


func _build_identity_form(parent: Control) -> void:
	var section := _make_section(parent, "Основное", "Имя, тип и описание карты")

	id_edit = _add_line(section, "ID", "atk_example")
	name_edit = _add_line(section, "Название", "Новая карта")

	var type_row := _make_field_row(section, "Тип")
	type_option = OptionButton.new()
	type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in TYPE_ITEMS:
		type_option.add_item(str(item["label"]))
		type_option.set_item_metadata(type_option.item_count - 1, str(item["id"]))
	type_row.add_child(type_option)

	starting_check = CheckBox.new()
	starting_check.text = "Стартовая карта билда"
	starting_check.tooltip_text = "Добавить карту в starting_cards текущего билда"
	section.add_child(starting_check)

	var desc_label := Label.new()
	desc_label.text = "Описание"
	desc_label.add_theme_font_size_override("font_size", 10)
	section.add_child(desc_label)

	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 82.0
	description_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description_edit.placeholder_text = "Коротко опиши действие карты…"
	section.add_child(description_edit)


func _build_combat_form(parent: Control) -> void:
	var section := _make_section(parent, "Бой", "Стоимость, урон, блок и выбор цели")

	cost_spin = _add_slider(section, "Стоимость", 0.0, 20.0, 1.0, true)
	damage_spin = _add_slider(section, "Урон", 0.0, 999.0, 1.0, true)
	shield_spin = _add_slider(section, "Блок", 0.0, 999.0, 1.0, true)

	var damage_row := _make_field_row(section, "Урон")
	damage_type_option = OptionButton.new()
	damage_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in [
		{"label": "Физический", "value": 0},
		{"label": "Магический", "value": 1},
		{"label": "Психический", "value": 2},
	]:
		damage_type_option.add_item(str(entry["label"]))
		damage_type_option.set_item_metadata(damage_type_option.item_count - 1, int(entry["value"]))
	damage_row.add_child(damage_type_option)

	var target_row := _make_field_row(section, "Цель")
	target_option = OptionButton.new()
	target_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in [
		{"label": "Враг", "value": 0},
		{"label": "На себя", "value": 1},
		{"label": "Все враги", "value": 2},
		{"label": "Все союзники", "value": 3},
	]:
		target_option.add_item(str(entry["label"]))
		target_option.set_item_metadata(target_option.item_count - 1, int(entry["value"]))
	target_row.add_child(target_option)

	effect_type_edit = _add_line(section, "Анимация", "attack_battle")


func _build_visual_form(parent: Control) -> void:
	var section := _make_section(parent, "Иллюстрация", "Artwork внутри рамки карты")

	var artwork_label := Label.new()
	artwork_label.text = "Artwork / внутренняя иллюстрация"
	section.add_child(artwork_label)

	artwork_picker = EditorResourcePicker.new()
	artwork_picker.base_type = "Texture2D"
	artwork_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(artwork_picker)

	var hint := Label.new()
	hint.text = "Рамка карты больше не хранится в Artwork: она автоматически выбирается по типу. Старые *_base.png поддерживаются как legacy."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	section.add_child(hint)


func _build_text_style_form(parent: Control) -> void:
	var section := _make_section(parent, "Текст", "Размер и цвет отдельных элементов")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(grid)

	for heading in ["Элемент", "Размер", "Цвет"]:
		var label := Label.new()
		label.text = heading
		label.add_theme_font_size_override("font_size", 10)
		grid.add_child(label)

	title_size_spin = _add_text_style_row(grid, "Название", 6, 32, 11)
	title_color_picker = grid.get_child(grid.get_child_count() - 1) as ColorPickerButton

	description_size_spin = _add_text_style_row(grid, "Описание", 5, 24, 7)
	description_color_picker = grid.get_child(grid.get_child_count() - 1) as ColorPickerButton

	cost_size_spin = _add_text_style_row(grid, "Стоимость", 8, 40, 18)
	cost_color_picker = grid.get_child(grid.get_child_count() - 1) as ColorPickerButton

	stats_size_spin = _add_text_style_row(grid, "УРН / БЛК", 6, 24, 8)
	stats_color_picker = grid.get_child(grid.get_child_count() - 1) as ColorPickerButton

	var reset_button := Button.new()
	reset_button.text = "Сбросить стиль текста"
	reset_button.pressed.connect(_reset_text_style)
	section.add_child(reset_button)


func _add_text_style_row(
	parent: GridContainer,
	label_text: String,
	minimum: int,
	maximum: int,
	default_value: int
) -> EditorSpinSlider:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)

	var slider := EditorSpinSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 1
	slider.editing_integer = true
	slider.value = default_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_value_changed)
	parent.add_child(slider)

	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(54.0, 24.0)
	picker.color_changed.connect(_on_text_color_changed)
	parent.add_child(picker)

	return slider


func _reset_text_style() -> void:
	title_size_spin.value = 11
	title_color_picker.color = Color("#f8eef5")
	description_size_spin.value = 7
	description_color_picker.color = Color("#3b2938")
	cost_size_spin.value = 18
	cost_color_picker.color = Color("#342637")
	stats_size_spin.value = 8
	stats_color_picker.color = Color("#3b2938")
	_refresh_preview()


func _build_effects_form(parent: Control) -> void:
	var section := _make_section(parent, "Эффекты", "Расширенные игровые эффекты карты")
	var hint := Label.new()
	hint.text = "Расширенный режим. Эффекты сохраняются напрямую в CardData.effects."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	section.add_child(hint)

	effects_edit = TextEdit.new()
	effects_edit.custom_minimum_size.y = 120.0
	effects_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	effects_edit.placeholder_text = "[\n  {\"id\": \"apply_status\", \"status\": \"poison\", \"stacks\": 2}\n]"
	section.add_child(effects_edit)

	effects_error = Label.new()
	effects_error.visible = false
	effects_error.modulate = Color("#ef6b73")
	effects_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(effects_error)

	var presets := HBoxContainer.new()
	section.add_child(presets)
	var preset_label := Label.new()
	preset_label.text = "Быстро добавить:"
	presets.add_child(preset_label)
	for effect_id in ["draw_card", "clean_debuffs", "gain_build_resource", "apply_status", "trigger_status"]:
		var button := Button.new()
		button.text = effect_id
		button.pressed.connect(_append_effect_preset.bind(effect_id))
		presets.add_child(button)

func _wire_preview_signals() -> void:
	pass

func _refresh_cards() -> void:
	card_list.clear()
	selected_card = null
	selected_card_path = ""
	preview.set_card(null)
	_set_form_enabled(false)

	if build == null:
		return

	var paths: Array[String] = _collect_card_paths()
	var query: String = card_search.text.strip_edges().to_lower()

	for path in paths:
		var card = load(path)
		if card == null:
			continue
		var card_name: String = str(card.get("name"))
		var card_id: String = str(card.get("id"))
		if not query.is_empty() and query not in card_name.to_lower() and query not in card_id.to_lower():
			continue
		var cost: int = int(card.get("cost"))
		var item_text: String = "%s   [%d]" % [card_name if not card_name.is_empty() else card_id, cost]
		card_list.add_item(item_text)
		card_list.set_item_metadata(card_list.item_count - 1, path)
		card_list.set_item_tooltip(card_list.item_count - 1, "%s\n%s" % [card_id, path])

	if card_list.item_count > 0:
		card_list.select(0)
		_on_card_selected(0)

func _collect_card_paths() -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}

	for resource in build.starting_cards:
		_append_resource_path(resource, result, seen)
	for resource in build.exclusive_cards:
		_append_resource_path(resource, result, seen)

	var activation_id: String = str(build.activation_card_id)
	var dir := DirAccess.open(CARD_DIR)
	if dir == null:
		return result

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.get_extension() == "tres":
			var path: String = "%s/%s" % [CARD_DIR, file_name]
			if not seen.has(path):
				var card = load(path)
				if card != null:
					var owner: String = str(card.get("build_id"))
					var card_id: String = str(card.get("id"))
					if owner == str(build.id) or card_id == activation_id:
						result.append(path)
						seen[path] = true
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

func _append_resource_path(resource: Resource, result: Array[String], seen: Dictionary) -> void:
	if resource == null:
		return
	var path: String = resource.resource_path
	if path.is_empty() or seen.has(path):
		return
	result.append(path)
	seen[path] = true

func _on_search_changed(_value: String) -> void:
	_refresh_cards()

func _on_card_selected(index: int) -> void:
	selected_card_path = str(card_list.get_item_metadata(index))
	selected_card = load(selected_card_path)
	_load_card_to_form(selected_card)

func _on_card_activated(index: int) -> void:
	_on_card_selected(index)
	_open_in_inspector()

func _load_card_to_form(card) -> void:
	_loading = true
	_set_form_enabled(card != null)
	preview.set_card(card)

	if workspace_title != null:
		workspace_title.text = "Выберите карту" if card == null else str(card.get("name"))
	if workspace_meta != null:
		if card == null:
			workspace_meta.text = "Параметры карты"
		else:
			workspace_meta.text = "%s  ·  %s" % [
				str(card.get("type")).capitalize(),
				str(card.get("id"))
			]
	if detail_face != null:
		detail_face.set_card(card)
	if detail_popup != null and detail_popup.visible and card != null:
		detail_title.text = str(card.get("name"))

	if card == null:
		_loading = false
		return

	id_edit.text = str(card.get("id"))
	name_edit.text = str(card.get("name"))
	_select_type(str(card.get("type")), str(card.get("id")))
	cost_spin.value = int(card.get("cost"))
	damage_spin.value = int(card.get("dmg"))
	shield_spin.value = int(card.get("shild"))
	_select_option_by_metadata(damage_type_option, int(card.get("damage_type")))
	_select_option_by_metadata(target_option, int(card.get("target_type")))
	effect_type_edit.text = str(card.get("effect_type"))
	description_edit.text = str(card.get("description"))
	var artwork: Texture2D = card.get("artwork") as Texture2D
	if artwork != null and artwork.resource_path.ends_with("_base.png"):
		artwork = null
	artwork_picker.edited_resource = artwork

	title_size_spin.value = int(card.get("title_font_size"))
	title_color_picker.color = card.get("title_color")
	description_size_spin.value = int(card.get("description_font_size"))
	description_color_picker.color = card.get("description_color")
	cost_size_spin.value = int(card.get("cost_font_size"))
	cost_color_picker.color = card.get("cost_color")
	stats_size_spin.value = int(card.get("stats_font_size"))
	stats_color_picker.color = card.get("stats_color")

	starting_check.button_pressed = _build_array_has_card(build.starting_cards, selected_card_path)
	effects_edit.text = JSON.stringify(card.get("effects"), "  ")
	effects_error.visible = false
	_loading = false
	_refresh_preview()

func _set_form_enabled(enabled: bool) -> void:
	if save_button != null:
		save_button.disabled = not enabled
	if open_button != null:
		open_button.disabled = not enabled
	if preview_open_button != null:
		preview_open_button.disabled = not enabled
	if form_scroll != null:
		form_scroll.modulate = Color.WHITE if enabled else Color(1.0, 1.0, 1.0, 0.45)

func _make_preview_draft() -> Dictionary:
	return {
		"id": id_edit.text,
		"name": name_edit.text,
		"type": _selected_type_id(),
		"cost": roundi(cost_spin.value),
		"dmg": roundi(damage_spin.value),
		"shild": roundi(shield_spin.value),
		"description": description_edit.text,
		"artwork": artwork_picker.edited_resource,
		"title_font_size": roundi(title_size_spin.value),
		"title_color": title_color_picker.color,
		"description_font_size": roundi(description_size_spin.value),
		"description_color": description_color_picker.color,
		"cost_font_size": roundi(cost_size_spin.value),
		"cost_color": cost_color_picker.color,
		"stats_font_size": roundi(stats_size_spin.value),
		"stats_color": stats_color_picker.color,
	}


func _refresh_preview() -> void:
	if _loading or selected_card == null:
		return

	var draft: Dictionary = _make_preview_draft()
	preview.set_draft(draft)

	if workspace_title != null:
		workspace_title.text = name_edit.text if not name_edit.text.is_empty() else "Без названия"
	if workspace_meta != null:
		workspace_meta.text = "%s  ·  %s" % [
			_selected_type_id().capitalize(),
			id_edit.text
		]

	if detail_popup != null and detail_popup.visible and detail_face != null:
		detail_face.set_draft(draft)
		detail_title.text = name_edit.text

func _save_card() -> void:
	if selected_card == null or build == null:
		return

	var card_id: String = _sanitize_id(id_edit.text)
	if card_id.is_empty():
		_show_effect_error("ID карты не может быть пустым.")
		return

	var effects_result: Dictionary = _parse_effects_json()
	if not bool(effects_result.get("ok", false)):
		return

	selected_card.id = card_id
	selected_card.name = name_edit.text.strip_edges()
	selected_card.type = _selected_type_id()
	selected_card.cost = roundi(cost_spin.value)
	selected_card.dmg = roundi(damage_spin.value)
	selected_card.shild = roundi(shield_spin.value)
	selected_card.damage_type = int(damage_type_option.get_selected_metadata())
	selected_card.target_type = int(target_option.get_selected_metadata())
	selected_card.effect_type = effect_type_edit.text.strip_edges()
	selected_card.description = description_edit.text
	selected_card.artwork = artwork_picker.edited_resource as Texture2D
	selected_card.title_font_size = roundi(title_size_spin.value)
	selected_card.title_color = title_color_picker.color
	selected_card.description_font_size = roundi(description_size_spin.value)
	selected_card.description_color = description_color_picker.color
	selected_card.cost_font_size = roundi(cost_size_spin.value)
	selected_card.cost_color = cost_color_picker.color
	selected_card.stats_font_size = roundi(stats_size_spin.value)
	selected_card.stats_color = stats_color_picker.color
	selected_card.build_id = build.id
	if _selected_type_id() == "infection":
		selected_card.contamination = build

	selected_card.effects.clear()
	var parsed_effects: Array = effects_result.get("effects", [])
	for effect in parsed_effects:
		if effect is Dictionary:
			selected_card.effects.append(effect)

	var current_path: String = selected_card.resource_path
	var error: Error = ResourceSaver.save(selected_card, current_path)
	if error != OK:
		_show_effect_error("Ошибка сохранения карты: %s" % error_string(error))
		return

	_sync_build_membership(selected_card)
	ResourceSaver.save(build, build.resource_path)
	_refresh_cards()
	select_card_path(current_path)
	if editor_interface != null:
		editor_interface.get_resource_filesystem().scan()

func _sync_build_membership(card) -> void:
	var is_infection: bool = _normalize_type(str(card.type), str(card.id)) == "infection"

	if is_infection:
		build.activation_card_id = card.id
	else:
		_ensure_resource_in_array(build.exclusive_cards, card)

	if starting_check.button_pressed:
		_ensure_resource_in_array(build.starting_cards, card)
	else:
		_remove_resource_from_array(build.starting_cards, card.resource_path)

func _create_card_of_type(type_index: int) -> void:
	if build == null or type_index < 0 or type_index >= TYPE_ITEMS.size():
		return

	var type_id: String = str(TYPE_ITEMS[type_index]["id"])
	var prefix: String = str({
		"attack": "atk",
		"defense": "def",
		"event": "evt",
		"status": "status",
		"infection": "con",
	}.get(type_id, "card"))

	var base_id: String = "%s_%s_card" % [prefix, str(build.id)]
	var index: int = 1
	var card_id: String = "%s_%d" % [base_id, index]
	var path: String = "%s/%s.tres" % [CARD_DIR, card_id]
	while ResourceLoader.exists(path):
		index += 1
		card_id = "%s_%d" % [base_id, index]
		path = "%s/%s.tres" % [CARD_DIR, card_id]

	var script := load(CARD_DATA_PATH) as Script
	if script == null or not script.can_instantiate():
		return
	var card = script.new()
	card.id = card_id
	card.name = str(TYPE_ITEMS[type_index]["label"]) + ": " + str(build.display_name)
	card.type = type_id
	card.build_id = build.id
	card.cost = 1
	card.target_type = 0
	if type_id in ["defense", "status", "infection"]:
		card.target_type = 1
	# Рамка выбирается CardFace по type. Artwork остаётся свободным
	# для внутренней иллюстрации.
	card.artwork = null
	if type_id == "infection":
		card.contamination = build

	var error: Error = ResourceSaver.save(card, path)
	if error != OK:
		return

	var saved = load(path)
	if type_id == "infection":
		build.activation_card_id = card_id
	else:
		var resource_to_add: Resource = saved as Resource
		if resource_to_add == null:
			resource_to_add = card as Resource
		_ensure_resource_in_array(build.exclusive_cards, resource_to_add)
	ResourceSaver.save(build, build.resource_path)

	if editor_interface != null:
		editor_interface.get_resource_filesystem().scan()
	_refresh_cards()
	select_card_path(path)

func _open_in_inspector() -> void:
	if selected_card != null and editor_interface != null:
		editor_interface.edit_resource(selected_card)

func _append_effect_preset(effect_id: String) -> void:
	var result: Dictionary = _parse_effects_json(false)
	var effects: Array = []
	if bool(result.get("ok", false)):
		effects = result.get("effects", [])
	var effect: Dictionary = {"id": effect_id}

	match effect_id:
		"draw_card":
			effect["amount"] = 1
		"gain_build_resource":
			effect["amount"] = 1
		"apply_status":
			effect["status"] = "poison"
			effect["duration"] = 2
			effect["stacks"] = 1
		"trigger_status":
			effect["status"] = "poison"

	effects.append(effect)
	effects_edit.text = JSON.stringify(effects, "  ")
	effects_error.visible = false

func _parse_effects_json(show_error: bool = true) -> Dictionary:
	var source: String = effects_edit.text.strip_edges()
	if source.is_empty():
		return {"ok": true, "effects": []}

	var parsed = JSON.parse_string(source)
	if not (parsed is Array):
		if show_error:
			_show_effect_error("Effects должен быть JSON-массивом: [ {...}, {...} ]")
		return {"ok": false, "effects": []}

	for effect in parsed:
		if not (effect is Dictionary):
			if show_error:
				_show_effect_error("Каждый элемент effects должен быть объектом/Dictionary.")
			return {"ok": false, "effects": []}
		if not effect.has("id"):
			if show_error:
				_show_effect_error("У каждого эффекта должен быть ключ id.")
			return {"ok": false, "effects": []}

	effects_error.visible = false
	return {"ok": true, "effects": parsed}

func _show_effect_error(value: String) -> void:
	effects_error.text = value
	effects_error.visible = true

func _template_path_for_type(type_id: String) -> String:
	for item in TYPE_ITEMS:
		if str(item["id"]) == type_id:
			return str(item["template"])
	return "res://assets/card/event_base.png"

func _select_type(value: String, card_id: String) -> void:
	var normalized: String = _normalize_type(value, card_id)
	for i in range(type_option.item_count):
		if str(type_option.get_item_metadata(i)) == normalized:
			type_option.select(i)
			return
	type_option.select(2)

func _selected_type_id() -> String:
	return str(type_option.get_selected_metadata())

func _normalize_type(value: String, card_id: String = "") -> String:
	var clean: String = value.to_lower().strip_edges()
	if clean in ["attack", "atk"]:
		return "attack"
	if clean in ["defense", "defend", "def"]:
		return "defense"
	if clean in ["infection", "contamination"]:
		return "infection"
	if clean in ["status", "status_effect", "effect"]:
		return "status"
	if clean in ["event", "evt", "skill"]:
		return "event"
	if card_id.begins_with("atk_"):
		return "attack"
	if card_id.begins_with("def_"):
		return "defense"
	if card_id.begins_with("con_"):
		return "infection"
	if card_id.begins_with("status_"):
		return "status"
	return "event"

func _select_option_by_metadata(option: OptionButton, value: int) -> void:
	for i in range(option.item_count):
		if int(option.get_item_metadata(i)) == value:
			option.select(i)
			return

func _build_array_has_card(array: Array, path: String) -> bool:
	for resource in array:
		if resource != null and resource.resource_path == path:
			return true
	return false

func _ensure_resource_in_array(array: Array, resource: Resource) -> void:
	if resource == null:
		return
	if not _build_array_has_card(array, resource.resource_path):
		array.append(resource)

func _remove_resource_from_array(array: Array, path: String) -> void:
	for i in range(array.size() - 1, -1, -1):
		var resource = array[i]
		if resource != null and resource.resource_path == path:
			array.remove_at(i)

func _make_section(
	parent: Control,
	title_text: String,
	subtitle: String = ""
) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	# Небольшая нативная карточка поверх темы редактора.
	var style := StyleBoxFlat.new()
	var bg := Color("#24272f")
	var border := Color("#393e49")
	if has_theme_color(&"dark_color_2", &"Editor"):
		bg = get_theme_color(&"dark_color_2", &"Editor")
	if has_theme_color(&"dark_color_1", &"Editor"):
		border = get_theme_color(&"dark_color_1", &"Editor")
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	_add_margins(margin, 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 13)
	if has_theme_color(&"accent_color", &"Editor"):
		title.add_theme_color_override(
			"font_color",
			get_theme_color(&"accent_color", &"Editor")
		)
	box.add_child(title)

	if not subtitle.is_empty():
		var hint := Label.new()
		hint.text = subtitle
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_font_size_override("font_size", 9)
		if has_theme_color(&"font_disabled_color", &"Editor"):
			hint.add_theme_color_override(
				"font_color",
				get_theme_color(&"font_disabled_color", &"Editor")
			)
		box.add_child(hint)

	var separator := HSeparator.new()
	box.add_child(separator)

	return box


func _make_field_row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 92.0
	label.add_theme_font_size_override("font_size", 10)
	row.add_child(label)

	return row


func _add_line(parent: Control, label_text: String, placeholder: String) -> LineEdit:
	var row := _make_field_row(parent, label_text)

	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(_on_text_changed)
	row.add_child(edit)
	return edit


func _add_slider(
	parent: Control,
	label_text: String,
	minimum: float,
	maximum: float,
	step_value: float,
	integer: bool
) -> EditorSpinSlider:
	var slider := EditorSpinSlider.new()
	slider.label = label_text
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_value
	slider.editing_integer = integer
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_value_changed)
	parent.add_child(slider)
	return slider


func _add_margins(container: MarginContainer, amount: int) -> void:
	container.add_theme_constant_override("margin_left", amount)
	container.add_theme_constant_override("margin_top", amount)
	container.add_theme_constant_override("margin_right", amount)
	container.add_theme_constant_override("margin_bottom", amount)


func _on_text_changed(_value: String) -> void:
	_refresh_preview()

func _on_value_changed(_value: float) -> void:
	_refresh_preview()

func _on_option_changed(_index: int) -> void:
	_refresh_preview()

func _on_description_changed() -> void:
	_refresh_preview()

func _on_artwork_changed(_resource: Resource) -> void:
	_refresh_preview()

func _on_text_color_changed(_color: Color) -> void:
	_refresh_preview()

func _sanitize_id(value: String) -> String:
	var result: String = value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var regex := RegEx.new()
	regex.compile("[^a-z0-9_]+")
	result = regex.sub(result, "", true)
	while "__" in result:
		result = result.replace("__", "_")
	return result.trim_prefix("_").trim_suffix("_")

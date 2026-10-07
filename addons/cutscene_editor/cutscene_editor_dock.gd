@tool
extends VBoxContainer


const TimelineScript = preload(
	"res://addons/cutscene_editor/cutscene_timeline.gd"
)
const PreviewScript = preload(
	"res://addons/cutscene_editor/cutscene_preview.gd"
)

const TIME_STEP: float = 0.1
const MIN_ACTION_DURATION: float = 0.1
const DEFAULT_PREVIEW_SIZE: Vector2i = Vector2i(960, 620)
const DEFAULT_EDITOR_SIZE: Vector2i = Vector2i(1180, 560)
const INVALID_WINDOW_POSITION: Vector2i = Vector2i(-100000, -100000)

var plugin: EditorPlugin = null
var editor_interface: EditorInterface = null
var undo_redo: EditorUndoRedoManager = null

var current_cutscene: CutsceneData = null
var is_playing: bool = false
var updating_ui: bool = false
var refresh_queued: bool = false
var is_detached: bool = false

var workspace: VBoxContainer
var detached_placeholder: HBoxContainer
var main_split: HSplitContainer
var title_label: Label
var duration_spin: SpinBox
var current_time_spin: SpinBox
var play_button: Button
var stop_button: Button
var preview_button: Button
var detach_button: Button
var action_tree: Tree
var action_tree_items: Array[TreeItem] = []
var action_start_spin: SpinBox
var action_duration_spin: SpinBox
var action_end_spin: SpinBox
var inspector_button: Button
var add_button: MenuButton
var delete_button: Button
var save_button: Button
var zoom_slider: HSlider
var zoom_value_label: Label
var timeline: Control
var timeline_scroll: ScrollContainer

var preview_window: Window
var preview: Control
var editor_window: Window
var editor_window_host: MarginContainer

var layout_config: ConfigFile = ConfigFile.new()
var saved_split_offset: int = 0
var saved_zoom: float = 1.0
var saved_detached: bool = false
var saved_editor_position: Vector2i = INVALID_WINDOW_POSITION
var saved_editor_size: Vector2i = DEFAULT_EDITOR_SIZE
var saved_preview_position: Vector2i = INVALID_WINDOW_POSITION
var saved_preview_size: Vector2i = DEFAULT_PREVIEW_SIZE
var saved_preview_visible: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(760.0, 320.0)
	_load_layout_settings()
	_build_placeholder()
	_build_ui()
	_create_editor_window()
	_create_preview_window()
	_rebuild_action_menu()
	set_process(true)
	call_deferred("_apply_saved_layout")


func _process(delta: float) -> void:
	if not is_playing or current_cutscene == null or timeline == null:
		return

	var end_time: float = timeline.get_timeline_duration()
	var next_time: float = timeline.get_current_time() + delta

	if next_time >= end_time:
		timeline.set_current_time(end_time, true, false)
		_set_playing(false)
		return

	timeline.set_current_time(next_time, true, false)


func shutdown() -> void:
	_store_editor_window_geometry()
	_store_preview_window_geometry()
	_save_layout_settings()


func is_editor_detached() -> bool:
	return is_detached


func show_editor_window() -> void:
	if not is_detached or editor_window == null:
		return

	if not editor_window.visible:
		editor_window.show()

	editor_window.move_to_foreground()


func _build_placeholder() -> void:
	detached_placeholder = HBoxContainer.new()
	detached_placeholder.visible = false
	detached_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(detached_placeholder)

	var label: Label = Label.new()
	label.text = "Редактор катсцен открыт в отдельном окне."
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detached_placeholder.add_child(label)

	var return_button: Button = Button.new()
	return_button.text = "Вернуть в нижнюю панель"
	return_button.pressed.connect(_attach_editor)
	detached_placeholder.add_child(return_button)


func _build_ui() -> void:
	workspace = VBoxContainer.new()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override(&"separation", 4)
	add_child(workspace)
	move_child(workspace, 0)

	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 30.0)
	header.add_theme_constant_override(&"separation", 4)
	workspace.add_child(header)

	title_label = Label.new()
	title_label.text = "Редактор катсцен"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	play_button = Button.new()
	play_button.text = "▶"
	play_button.tooltip_text = "Воспроизвести / поставить на паузу"
	play_button.pressed.connect(_on_play_pressed)
	header.add_child(play_button)

	stop_button = Button.new()
	stop_button.text = "■"
	stop_button.tooltip_text = "Остановить и перейти в начало"
	stop_button.pressed.connect(_on_stop_pressed)
	header.add_child(stop_button)

	preview_button = Button.new()
	preview_button.text = "Предпросмотр"
	preview_button.tooltip_text = "Открыть игровое изображение катсцены в отдельном окне"
	preview_button.pressed.connect(_on_preview_pressed)
	header.add_child(preview_button)

	detach_button = Button.new()
	detach_button.text = "Открепить"
	detach_button.tooltip_text = "Перенести весь редактор катсцен в отдельное окно"
	detach_button.pressed.connect(_on_detach_pressed)
	header.add_child(detach_button)

	save_button = Button.new()
	save_button.text = "Сохранить"
	save_button.pressed.connect(save_cutscene)
	header.add_child(save_button)

	var controls: HFlowContainer = HFlowContainer.new()
	controls.add_theme_constant_override(&"h_separation", 4)
	controls.add_theme_constant_override(&"v_separation", 2)
	workspace.add_child(controls)

	current_time_spin = _create_time_spin("Время ", 0.0)
	current_time_spin.custom_minimum_size = Vector2(126.0, 0.0)
	current_time_spin.value_changed.connect(_on_current_time_value_changed)
	controls.add_child(current_time_spin)

	duration_spin = _create_time_spin("Длина ", 0.0)
	duration_spin.custom_minimum_size = Vector2(130.0, 0.0)
	duration_spin.value_changed.connect(_on_duration_value_changed)
	controls.add_child(duration_spin)

	var zoom_text: Label = Label.new()
	zoom_text.text = "Масштаб"
	controls.add_child(zoom_text)

	zoom_slider = HSlider.new()
	zoom_slider.min_value = 0.25
	zoom_slider.max_value = 4.0
	zoom_slider.step = 0.05
	zoom_slider.custom_minimum_size = Vector2(140.0, 0.0)
	zoom_slider.tooltip_text = "Масштаб таймлайна. Также работает Ctrl + колесо мыши над таймлайном."
	zoom_slider.value_changed.connect(_on_zoom_slider_value_changed)
	controls.add_child(zoom_slider)

	zoom_value_label = Label.new()
	zoom_value_label.custom_minimum_size = Vector2(46.0, 0.0)
	controls.add_child(zoom_value_label)

	add_button = MenuButton.new()
	add_button.text = "+ Действие"
	controls.add_child(add_button)

	delete_button = Button.new()
	delete_button.text = "Удалить"
	delete_button.disabled = true
	delete_button.pressed.connect(_delete_selected_action)
	controls.add_child(delete_button)

	main_split = HSplitContainer.new()
	main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.drag_ended.connect(_on_main_split_drag_ended)
	workspace.add_child(main_split)

	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(245.0, 0.0)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.34
	main_split.add_child(left_panel)

	var left_margin: MarginContainer = MarginContainer.new()
	left_margin.add_theme_constant_override(&"margin_left", 6)
	left_margin.add_theme_constant_override(&"margin_right", 6)
	left_margin.add_theme_constant_override(&"margin_top", 5)
	left_margin.add_theme_constant_override(&"margin_bottom", 5)
	left_panel.add_child(left_margin)

	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 4)
	left_margin.add_child(left)

	var actions_header: HBoxContainer = HBoxContainer.new()
	left.add_child(actions_header)

	var actions_label: Label = Label.new()
	actions_label.text = "Действия"
	actions_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_header.add_child(actions_label)

	var rename_hint: Label = Label.new()
	rename_hint.text = "имя редактируется в списке"
	rename_hint.modulate = Color(1.0, 1.0, 1.0, 0.55)
	rename_hint.add_theme_font_size_override(&"font_size", 10)
	actions_header.add_child(rename_hint)

	action_tree = Tree.new()
	action_tree.columns = 2
	action_tree.hide_root = true
	action_tree.column_titles_visible = true
	action_tree.select_mode = Tree.SELECT_ROW
	action_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_tree.set_column_title(0, "Имя")
	action_tree.set_column_title(1, "Тип")
	action_tree.set_column_expand(0, true)
	action_tree.set_column_expand(1, false)
	action_tree.set_column_custom_minimum_width(1, 102)
	action_tree.set_column_clip_content(0, true)
	action_tree.item_selected.connect(_on_action_tree_selected)
	action_tree.item_edited.connect(_on_action_tree_item_edited)
	left.add_child(action_tree)

	var timing: HFlowContainer = HFlowContainer.new()
	timing.add_theme_constant_override(&"h_separation", 4)
	timing.add_theme_constant_override(&"v_separation", 2)
	left.add_child(timing)

	_add_timing_control(timing, "Старт", "start")
	_add_timing_control(timing, "Длина", "duration")
	_add_timing_control(timing, "Конец", "end")

	inspector_button = Button.new()
	inspector_button.text = "Инспектор"
	inspector_button.tooltip_text = "Открыть все свойства выбранного действия в Inspector"
	inspector_button.disabled = true
	inspector_button.pressed.connect(_on_inspector_pressed)
	timing.add_child(inspector_button)

	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	main_split.add_child(right_panel)

	var right_margin: MarginContainer = MarginContainer.new()
	right_margin.add_theme_constant_override(&"margin_left", 6)
	right_margin.add_theme_constant_override(&"margin_right", 6)
	right_margin.add_theme_constant_override(&"margin_top", 5)
	right_margin.add_theme_constant_override(&"margin_bottom", 5)
	right_panel.add_child(right_margin)

	var right: VBoxContainer = VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 3)
	right_margin.add_child(right)

	var timeline_header: HBoxContainer = HBoxContainer.new()
	right.add_child(timeline_header)

	var timeline_label: Label = Label.new()
	timeline_label.text = "Таймлайн"
	timeline_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_header.add_child(timeline_label)

	var timeline_hint: Label = Label.new()
	timeline_hint.text = "Ctrl + колесо — масштаб"
	timeline_hint.modulate = Color(1.0, 1.0, 1.0, 0.5)
	timeline_hint.add_theme_font_size_override(&"font_size", 10)
	timeline_header.add_child(timeline_hint)

	timeline_scroll = ScrollContainer.new()
	timeline_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timeline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	timeline_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right.add_child(timeline_scroll)

	timeline = TimelineScript.new()
	timeline.set_undo_redo(undo_redo)
	timeline.action_selected.connect(_on_timeline_action_selected)
	timeline.action_clicked.connect(_on_timeline_action_clicked)
	timeline.action_timing_changed.connect(_on_timeline_action_timing_changed)
	timeline.time_changed.connect(_on_timeline_time_changed)
	timeline.zoom_changed.connect(_on_timeline_zoom_changed)
	timeline_scroll.add_child(timeline)

	_set_action_editor_enabled(false)


func _create_editor_window() -> void:
	editor_window = Window.new()
	editor_window.title = "Редактор катсцен"
	editor_window.visible = false
	editor_window.force_native = true
	editor_window.transient = true
	editor_window.unresizable = false
	editor_window.min_size = Vector2i(720, 360)
	editor_window.size = saved_editor_size
	editor_window.close_requested.connect(_attach_editor)
	editor_window.focus_exited.connect(_on_editor_window_focus_exited)
	add_child(editor_window)

	editor_window_host = MarginContainer.new()
	editor_window.add_child(editor_window_host)
	editor_window_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor_window_host.add_theme_constant_override(&"margin_left", 6)
	editor_window_host.add_theme_constant_override(&"margin_right", 6)
	editor_window_host.add_theme_constant_override(&"margin_top", 6)
	editor_window_host.add_theme_constant_override(&"margin_bottom", 6)


func _create_preview_window() -> void:
	preview_window = Window.new()
	preview_window.title = "Предпросмотр катсцены"
	preview_window.visible = false
	preview_window.force_native = true
	# На Windows always_on_top несовместим с transient-окнами.
	# Предпросмотр намеренно независим от основного окна редактора.
	preview_window.transient = false
	preview_window.always_on_top = true
	preview_window.unresizable = false
	preview_window.min_size = Vector2i(480, 330)
	preview_window.size = saved_preview_size
	preview_window.close_requested.connect(_on_preview_window_close_requested)
	preview_window.focus_exited.connect(_on_preview_window_focus_exited)
	add_child(preview_window)

	preview = PreviewScript.new()
	preview.set_editor_interface(editor_interface)
	preview_window.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _create_time_spin(prefix_text: String, minimum: float) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = minimum
	spin.max_value = 100000.0
	spin.step = TIME_STEP
	spin.prefix = prefix_text
	spin.suffix = " с"
	spin.select_all_on_focus = true
	spin.allow_greater = true
	return spin


func _add_timing_control(
	container: Container,
	label_text: String,
	field: String
) -> void:
	var label: Label = Label.new()
	label.text = label_text
	container.add_child(label)

	var spin: SpinBox = _create_time_spin("", 0.0)
	spin.custom_minimum_size = Vector2(82.0, 0.0)
	container.add_child(spin)

	if field == "start":
		action_start_spin = spin
		action_start_spin.value_changed.connect(_on_action_start_value_changed)
	elif field == "duration":
		action_duration_spin = spin
		action_duration_spin.value_changed.connect(_on_action_duration_value_changed)
	elif field == "end":
		action_end_spin = spin
		action_end_spin.value_changed.connect(_on_action_end_value_changed)


func _rebuild_action_menu() -> void:
	if add_button == null:
		return

	var popup: PopupMenu = add_button.get_popup()
	popup.clear()

	for id in CutsceneActionRegistry.get_action_ids():
		var index: int = popup.item_count
		popup.add_item(_get_action_type_name_from_id(StringName(id)))
		popup.set_item_metadata(index, id)

	if not popup.id_pressed.is_connected(_on_add_action_pressed):
		popup.id_pressed.connect(_on_add_action_pressed)


func edit_cutscene(cutscene: CutsceneData) -> void:
	var changed_resource: bool = current_cutscene != cutscene

	if changed_resource:
		_set_playing(false)

	if changed_resource and current_cutscene != null:
		if current_cutscene.changed.is_connected(_on_cutscene_changed):
			current_cutscene.changed.disconnect(_on_cutscene_changed)

	current_cutscene = cutscene

	if changed_resource and current_cutscene != null:
		if not current_cutscene.changed.is_connected(_on_cutscene_changed):
			current_cutscene.changed.connect(_on_cutscene_changed)

	_refresh(changed_resource)


func clear_cutscene() -> void:
	_set_playing(false)

	if current_cutscene != null:
		if current_cutscene.changed.is_connected(_on_cutscene_changed):
			current_cutscene.changed.disconnect(_on_cutscene_changed)

	current_cutscene = null
	_refresh(true)


func _refresh(reset_timeline: bool = false) -> void:
	if action_tree == null:
		return

	var previous_selected: int = -1
	var previous_time: float = 0.0

	if timeline != null:
		previous_selected = timeline.get_selected_action()
		previous_time = timeline.get_current_time()

	updating_ui = true
	action_tree.clear()
	action_tree_items.clear()
	delete_button.disabled = true
	inspector_button.disabled = true

	var root: TreeItem = action_tree.create_item()

	if current_cutscene == null:
		title_label.text = "Редактор катсцен"
		duration_spin.value = 0.0
		current_time_spin.value = 0.0
		timeline.set_cutscene(null, true)
		preview.set_cutscene(null)
		_set_action_editor_enabled(false)
		updating_ui = false
		return

	title_label.text = "Катсцена: " + current_cutscene.title
	duration_spin.value = current_cutscene.duration

	for i in current_cutscene.actions.size():
		var action: CutsceneAction = current_cutscene.actions[i]
		var item: TreeItem = action_tree.create_item(root)
		action_tree_items.append(item)
		item.set_metadata(0, i)
		item.set_metadata(1, i)

		if action == null:
			item.set_text(0, "<ошибка>")
			item.set_text(1, "Неизвестно")
			item.set_editable(0, false)
			continue

		item.set_text(0, _get_action_list_name(action, i))
		item.set_text(1, _get_action_type_name(action))
		item.set_editable(0, true)
		item.set_tooltip_text(0, "Дважды щёлкните по имени, чтобы переименовать действие")

	timeline.set_cutscene(current_cutscene, reset_timeline)

	if not reset_timeline:
		timeline.set_current_time(previous_time, false)

	if (
		not reset_timeline
		and previous_selected >= 0
		and previous_selected < action_tree_items.size()
	):
		timeline.set_selected_action(previous_selected)
		action_tree_items[previous_selected].select(0)
		delete_button.disabled = false
		inspector_button.disabled = false
		_sync_action_editor(previous_selected)
	else:
		_set_action_editor_enabled(false)

	current_time_spin.max_value = maxf(
		timeline.get_timeline_duration(),
		current_cutscene.duration
	)
	current_time_spin.value = timeline.get_current_time()

	preview.set_cutscene(current_cutscene)
	preview.set_current_time(timeline.get_current_time())
	updating_ui = false


func _get_action_list_name(action: CutsceneAction, index: int) -> String:
	var custom_name: String = action.resource_name.strip_edges()

	if not custom_name.is_empty():
		return custom_name

	return "%s %d" % [_get_action_type_name(action), index + 1]


func _get_action_type_name(action: CutsceneAction) -> String:
	if action is DialogueAction:
		return "Диалог"
	if action is AnimationAction:
		return "Анимация"
	if action is MoveAction:
		return "Движение"
	if action is WaitAction:
		return "Ожидание"
	if action is FadeAction:
		return "Затемнение"
	return "Действие"


func _get_action_type_name_from_id(id: StringName) -> String:
	if id == &"dialogue":
		return "Диалог"
	if id == &"animation":
		return "Анимация"
	if id == &"move":
		return "Движение"
	if id == &"wait":
		return "Ожидание"
	if id == &"fade":
		return "Затемнение"

	return CutsceneActionRegistry.get_display_name(id)


func _on_action_tree_selected() -> void:
	if updating_ui:
		return

	var index: int = _get_tree_selected_index()

	if index >= 0:
		_select_action(index)


func _on_action_tree_item_edited() -> void:
	if updating_ui or current_cutscene == null:
		return

	if action_tree.get_edited_column() != 0:
		return

	var item: TreeItem = action_tree.get_edited()

	if item == null:
		return

	var index: int = int(item.get_metadata(0))

	if index < 0 or index >= current_cutscene.actions.size():
		return

	var action: CutsceneAction = current_cutscene.actions[index]

	if action == null:
		return

	var new_name: String = item.get_text(0).strip_edges()
	var old_name: String = action.resource_name

	if old_name == new_name:
		return

	if undo_redo != null:
		undo_redo.create_action("Переименовать действие")
		undo_redo.add_do_property(action, &"resource_name", new_name)
		undo_redo.add_do_method(action, &"emit_changed")
		undo_redo.add_do_method(current_cutscene, &"emit_changed")
		undo_redo.add_undo_property(action, &"resource_name", old_name)
		undo_redo.add_undo_method(action, &"emit_changed")
		undo_redo.add_undo_method(current_cutscene, &"emit_changed")
		undo_redo.commit_action()
	else:
		action.resource_name = new_name
		action.emit_changed()
		current_cutscene.emit_changed()

	timeline.queue_redraw()


func _get_tree_selected_index() -> int:
	if action_tree == null:
		return -1

	var item: TreeItem = action_tree.get_selected()

	if item == null:
		return -1

	var metadata: Variant = item.get_metadata(0)

	if metadata == null:
		return -1

	return int(metadata)


func _select_action(index: int) -> void:
	if current_cutscene == null:
		return

	if index < 0 or index >= current_cutscene.actions.size():
		return

	delete_button.disabled = false
	inspector_button.disabled = false
	timeline.set_selected_action(index)
	_sync_action_editor(index)


func _on_inspector_pressed() -> void:
	var index: int = _get_selected_action_index()

	if index < 0 or editor_interface == null:
		return

	var action: CutsceneAction = current_cutscene.actions[index]

	if action == null:
		return

	var preserved_time: float = timeline.get_current_time()
	editor_interface.edit_resource(action)
	timeline.set_current_time(preserved_time, false)
	preview.set_current_time(preserved_time)

	if plugin != null:
		plugin.call_deferred("show_dock")


func _on_timeline_action_selected(index: int) -> void:
	if index < 0 or index >= action_tree_items.size():
		return

	var was_updating: bool = updating_ui
	updating_ui = true
	action_tree_items[index].select(0)
	updating_ui = was_updating
	delete_button.disabled = false
	inspector_button.disabled = false
	_sync_action_editor(index)


func _on_timeline_action_clicked(index: int) -> void:
	if index < 0 or index >= action_tree_items.size():
		return

	var preserved_time: float = timeline.get_current_time()
	var was_updating: bool = updating_ui
	updating_ui = true
	action_tree_items[index].select(0)
	updating_ui = was_updating
	_select_action(index)
	timeline.set_current_time(preserved_time, false)
	preview.set_current_time(preserved_time)
	_sync_time_spin(preserved_time)


func _on_timeline_action_timing_changed(
	index: int,
	start_time: float,
	duration: float
) -> void:
	if current_cutscene == null or index < 0 or index >= current_cutscene.actions.size():
		return

	if timeline.get_selected_action() == index:
		var was_updating: bool = updating_ui
		updating_ui = true
		action_start_spin.value = start_time
		action_duration_spin.value = duration
		action_end_spin.value = start_time + duration
		updating_ui = was_updating

	preview.set_current_time(timeline.get_current_time())


func _sync_action_editor(index: int) -> void:
	if current_cutscene == null or index < 0 or index >= current_cutscene.actions.size():
		_set_action_editor_enabled(false)
		return

	var action: CutsceneAction = current_cutscene.actions[index]

	if action == null:
		_set_action_editor_enabled(false)
		return

	var was_updating: bool = updating_ui
	updating_ui = true
	_set_action_editor_enabled(true)
	action_start_spin.value = action.start_time
	action_duration_spin.value = action.duration
	action_end_spin.value = action.start_time + action.duration
	updating_ui = was_updating


func _set_action_editor_enabled(enabled: bool) -> void:
	if action_start_spin != null:
		action_start_spin.editable = enabled
	if action_duration_spin != null:
		action_duration_spin.editable = enabled
	if action_end_spin != null:
		action_end_spin.editable = enabled
	if inspector_button != null:
		inspector_button.disabled = not enabled


func _get_selected_action_index() -> int:
	if timeline == null or current_cutscene == null:
		return -1

	var index: int = timeline.get_selected_action()

	if index < 0 or index >= current_cutscene.actions.size():
		return -1

	return index


func _on_action_start_value_changed(value: float) -> void:
	if updating_ui:
		return

	var index: int = _get_selected_action_index()

	if index < 0:
		return

	var action: CutsceneAction = current_cutscene.actions[index]
	_commit_action_timing(
		index,
		maxf(0.0, value),
		action.duration,
		"Изменить начало действия"
	)


func _on_action_duration_value_changed(value: float) -> void:
	if updating_ui:
		return

	var index: int = _get_selected_action_index()

	if index < 0:
		return

	var action: CutsceneAction = current_cutscene.actions[index]
	_commit_action_timing(
		index,
		action.start_time,
		maxf(MIN_ACTION_DURATION, value),
		"Изменить длительность действия"
	)


func _on_action_end_value_changed(value: float) -> void:
	if updating_ui:
		return

	var index: int = _get_selected_action_index()

	if index < 0:
		return

	var action: CutsceneAction = current_cutscene.actions[index]
	var end_time: float = maxf(
		value,
		action.start_time + MIN_ACTION_DURATION
	)
	_commit_action_timing(
		index,
		action.start_time,
		end_time - action.start_time,
		"Изменить конец действия"
	)


func _commit_action_timing(
	index: int,
	new_start: float,
	new_duration: float,
	action_name: String
) -> void:
	if current_cutscene == null or index < 0 or index >= current_cutscene.actions.size():
		return

	var action: CutsceneAction = current_cutscene.actions[index]

	if action == null:
		return

	new_start = maxf(0.0, new_start)
	new_duration = maxf(MIN_ACTION_DURATION, new_duration)

	var old_start: float = action.start_time
	var old_duration: float = action.duration

	if (
		is_equal_approx(old_start, new_start)
		and is_equal_approx(old_duration, new_duration)
	):
		_sync_action_editor(index)
		return

	if undo_redo != null:
		undo_redo.create_action(action_name)
		undo_redo.add_do_property(action, &"start_time", new_start)
		undo_redo.add_do_property(action, &"duration", new_duration)
		undo_redo.add_do_method(action, &"emit_changed")
		undo_redo.add_do_method(current_cutscene, &"emit_changed")
		undo_redo.add_undo_property(action, &"start_time", old_start)
		undo_redo.add_undo_property(action, &"duration", old_duration)
		undo_redo.add_undo_method(action, &"emit_changed")
		undo_redo.add_undo_method(current_cutscene, &"emit_changed")
		undo_redo.commit_action()
	else:
		action.start_time = new_start
		action.duration = new_duration
		action.emit_changed()
		current_cutscene.emit_changed()


func _on_current_time_value_changed(value: float) -> void:
	if updating_ui or timeline == null:
		return

	timeline.set_current_time(value)


func _on_duration_value_changed(value: float) -> void:
	if updating_ui or current_cutscene == null:
		return

	var new_duration: float = maxf(0.0, value)
	var old_duration: float = current_cutscene.duration

	if is_equal_approx(old_duration, new_duration):
		return

	if undo_redo != null:
		undo_redo.create_action("Изменить длительность катсцены")
		undo_redo.add_do_property(current_cutscene, &"duration", new_duration)
		undo_redo.add_do_method(current_cutscene, &"emit_changed")
		undo_redo.add_undo_property(current_cutscene, &"duration", old_duration)
		undo_redo.add_undo_method(current_cutscene, &"emit_changed")
		undo_redo.commit_action()
	else:
		current_cutscene.duration = new_duration
		current_cutscene.emit_changed()


func _on_zoom_slider_value_changed(value: float) -> void:
	if updating_ui or timeline == null:
		return

	timeline.set_zoom_factor(value, false)
	_update_zoom_label(value)
	saved_zoom = value
	_save_layout_settings()
	call_deferred("_center_timeline_on_playhead")


func _on_timeline_zoom_changed(value: float) -> void:
	var was_updating: bool = updating_ui
	updating_ui = true
	zoom_slider.value = value
	updating_ui = was_updating
	_update_zoom_label(value)
	saved_zoom = value
	_save_layout_settings()
	call_deferred("_center_timeline_on_playhead")


func _update_zoom_label(value: float) -> void:
	if zoom_value_label != null:
		zoom_value_label.text = "%d%%" % int(roundf(value * 100.0))


func _center_timeline_on_playhead() -> void:
	if timeline_scroll == null or timeline == null:
		return

	var x: float = timeline.time_to_x(timeline.get_current_time())
	var visible_width: float = timeline_scroll.size.x
	var target_scroll: int = maxi(int(x - visible_width * 0.5), 0)
	timeline_scroll.scroll_horizontal = target_scroll


func _on_play_pressed() -> void:
	if current_cutscene == null or timeline == null:
		return

	if is_playing:
		_set_playing(false)
		return

	var end_time: float = timeline.get_timeline_duration()

	if timeline.get_current_time() >= end_time - 0.0001:
		timeline.set_current_time(0.0)

	_set_playing(true)


func _on_stop_pressed() -> void:
	_set_playing(false)

	if timeline != null:
		timeline.set_current_time(0.0)


func _set_playing(value: bool) -> void:
	is_playing = value

	if play_button != null:
		if is_playing:
			play_button.text = "⏸"
			play_button.tooltip_text = "Пауза"
		else:
			play_button.text = "▶"
			play_button.tooltip_text = "Воспроизвести"


func _on_preview_pressed() -> void:
	if preview == null or preview_window == null:
		return

	preview.set_cutscene(current_cutscene)
	preview.refresh()
	preview.set_current_time(timeline.get_current_time())
	_show_preview_window()


func _show_preview_window() -> void:
	if preview_window.visible:
		preview_window.move_to_foreground()
		return

	preview_window.size = saved_preview_size

	if saved_preview_position == INVALID_WINDOW_POSITION:
		preview_window.position = _get_default_preview_position(
			saved_preview_size
		)
	else:
		preview_window.position = saved_preview_position

	# Не используем popup_*(): preview — обычное независимое native-окно,
	# а не popup/transient окно. Это важно для always_on_top на Windows.
	preview_window.show()
	preview_window.move_to_foreground()
	saved_preview_visible = true
	_save_layout_settings()


func _get_default_preview_position(
	window_size: Vector2i
) -> Vector2i:
	var reference_window: Window = null

	if (
		is_detached
		and editor_window != null
		and editor_window.visible
	):
		reference_window = editor_window
	else:
		reference_window = get_window()

	if reference_window == null:
		return Vector2i(80, 80)

	var offset_x: int = maxi(
		int((reference_window.size.x - window_size.x) * 0.5),
		0
	)
	var offset_y: int = maxi(
		int((reference_window.size.y - window_size.y) * 0.5),
		0
	)

	return reference_window.position + Vector2i(
		offset_x,
		offset_y
	)


func _on_preview_window_close_requested() -> void:
	_store_preview_window_geometry()
	preview_window.hide()
	saved_preview_visible = false
	_save_layout_settings()


func _on_preview_window_focus_exited() -> void:
	if preview_window != null and preview_window.visible:
		_store_preview_window_geometry()
		_save_layout_settings()


func _on_detach_pressed() -> void:
	if is_detached:
		_attach_editor()
	else:
		_detach_editor()


func _detach_editor() -> void:
	if is_detached or workspace == null or editor_window_host == null:
		return

	is_detached = true
	saved_detached = true
	detached_placeholder.visible = true
	detach_button.text = "Прикрепить"
	workspace.reparent(editor_window_host, false)
	editor_window.size = saved_editor_size

	if saved_editor_position == INVALID_WINDOW_POSITION:
		editor_window.popup_centered(saved_editor_size)
	else:
		editor_window.position = saved_editor_position
		editor_window.show()

	editor_window.move_to_foreground()
	_save_layout_settings()


func _attach_editor() -> void:
	if not is_detached:
		return

	_store_editor_window_geometry()
	workspace.reparent(self, false)
	move_child(workspace, 0)
	detached_placeholder.visible = false
	is_detached = false
	saved_detached = false
	detach_button.text = "Открепить"
	editor_window.hide()
	_save_layout_settings()


func _on_editor_window_focus_exited() -> void:
	if is_detached and editor_window != null and editor_window.visible:
		_store_editor_window_geometry()
		_save_layout_settings()


func _on_main_split_drag_ended() -> void:
	if main_split.split_offsets.size() > 0:
		saved_split_offset = main_split.split_offsets[0]
		_save_layout_settings()


func _on_add_action_pressed(menu_index: int) -> void:
	if current_cutscene == null:
		return

	var popup: PopupMenu = add_button.get_popup()
	var metadata: Variant = popup.get_item_metadata(menu_index)
	var action_id: StringName = StringName(str(metadata))
	var action: CutsceneAction = CutsceneActionRegistry.create_action(action_id)

	if action == null:
		return

	action.start_time = _get_next_start_time()

	var before: Array[CutsceneAction] = current_cutscene.actions.duplicate()
	var after: Array[CutsceneAction] = current_cutscene.actions.duplicate()
	after.append(action)

	_apply_actions(before, after, "Добавить действие")
	_refresh(false)
	_select_last_action()


func _delete_selected_action() -> void:
	if current_cutscene == null:
		return

	var index: int = _get_selected_action_index()

	if index < 0 or index >= current_cutscene.actions.size():
		return

	var before: Array[CutsceneAction] = current_cutscene.actions.duplicate()
	var after: Array[CutsceneAction] = current_cutscene.actions.duplicate()
	after.remove_at(index)

	_apply_actions(before, after, "Удалить действие")
	timeline.set_selected_action(-1)
	_refresh(false)


func _apply_actions(
	before: Array[CutsceneAction],
	after: Array[CutsceneAction],
	action_name: String
) -> void:
	if undo_redo != null:
		undo_redo.create_action(action_name)
		undo_redo.add_do_property(current_cutscene, &"actions", after)
		undo_redo.add_undo_property(current_cutscene, &"actions", before)
		undo_redo.add_do_method(current_cutscene, &"emit_changed")
		undo_redo.add_undo_method(current_cutscene, &"emit_changed")
		undo_redo.commit_action()
	else:
		current_cutscene.actions = after
		current_cutscene.emit_changed()


func _get_next_start_time() -> float:
	if current_cutscene == null:
		return 0.0

	var result: float = 0.0

	for action in current_cutscene.actions:
		if action == null:
			continue

		result = maxf(result, action.start_time + action.duration)

	return result


func _select_last_action() -> void:
	if current_cutscene == null or current_cutscene.actions.is_empty():
		return

	var index: int = current_cutscene.actions.size() - 1

	if index >= action_tree_items.size():
		return

	var was_updating: bool = updating_ui
	updating_ui = true
	action_tree_items[index].select(0)
	updating_ui = was_updating
	_select_action(index)


func _on_cutscene_changed() -> void:
	if refresh_queued:
		return

	refresh_queued = true
	call_deferred("_run_deferred_refresh")


func _run_deferred_refresh() -> void:
	refresh_queued = false
	_refresh(false)


func save_cutscene() -> void:
	if current_cutscene == null:
		return

	if current_cutscene.resource_path.is_empty():
		push_warning(
			"Редактор катсцен: у текущей CutsceneData нет resource_path."
		)
		return

	var error: Error = ResourceSaver.save(
		current_cutscene,
		current_cutscene.resource_path
	)

	if error != OK:
		push_error(
			"Редактор катсцен: не удалось сохранить ресурс. Ошибка: %s"
			% error
		)


func _on_timeline_time_changed(time: float) -> void:
	_sync_time_spin(time)

	if preview != null:
		preview.set_current_time(time)

	if is_playing:
		_ensure_playhead_visible(time)


func _sync_time_spin(time: float) -> void:
	if current_time_spin == null:
		return

	var was_updating: bool = updating_ui
	updating_ui = true
	current_time_spin.value = time
	updating_ui = was_updating


func _ensure_playhead_visible(time: float) -> void:
	if timeline_scroll == null or timeline == null:
		return

	var x: float = timeline.time_to_x(time)
	var left: float = float(timeline_scroll.scroll_horizontal)
	var right: float = left + timeline_scroll.size.x
	var margin: float = 70.0

	if x > right - margin:
		timeline_scroll.scroll_horizontal = maxi(
			int(x - timeline_scroll.size.x + margin),
			0
		)
	elif x < left + margin:
		timeline_scroll.scroll_horizontal = maxi(int(x - margin), 0)


func _apply_saved_layout() -> void:
	if main_split != null:
		main_split.split_offsets = PackedInt32Array([saved_split_offset])

	if timeline != null:
		timeline.set_zoom_factor(saved_zoom, false)

	var was_updating: bool = updating_ui
	updating_ui = true
	zoom_slider.value = saved_zoom
	updating_ui = was_updating
	_update_zoom_label(saved_zoom)

	if saved_detached:
		_detach_editor()

	if saved_preview_visible:
		_show_preview_window()


func _load_layout_settings() -> void:
	var error: Error = layout_config.load(_get_layout_config_path())

	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("Редактор катсцен: не удалось прочитать настройки интерфейса.")

	saved_split_offset = int(layout_config.get_value("layout", "split_offset", 0))
	saved_zoom = clampf(float(layout_config.get_value("timeline", "zoom", 1.0)), 0.25, 4.0)
	saved_detached = bool(layout_config.get_value("editor_window", "detached", false))
	saved_editor_position = _read_vector2i(
		"editor_window",
		"position",
		INVALID_WINDOW_POSITION
	)
	saved_editor_size = _read_vector2i(
		"editor_window",
		"size",
		DEFAULT_EDITOR_SIZE
	)
	saved_preview_position = _read_vector2i(
		"preview_window",
		"position",
		INVALID_WINDOW_POSITION
	)
	saved_preview_size = _read_vector2i(
		"preview_window",
		"size",
		DEFAULT_PREVIEW_SIZE
	)
	saved_preview_visible = bool(
		layout_config.get_value("preview_window", "visible", false)
	)


func _save_layout_settings() -> void:
	if main_split != null and main_split.split_offsets.size() > 0:
		saved_split_offset = main_split.split_offsets[0]

	layout_config.set_value("layout", "split_offset", saved_split_offset)
	layout_config.set_value("timeline", "zoom", saved_zoom)
	layout_config.set_value("editor_window", "detached", saved_detached)
	layout_config.set_value("editor_window", "position", saved_editor_position)
	layout_config.set_value("editor_window", "size", saved_editor_size)
	layout_config.set_value("preview_window", "position", saved_preview_position)
	layout_config.set_value("preview_window", "size", saved_preview_size)
	layout_config.set_value("preview_window", "visible", saved_preview_visible)

	var error: Error = layout_config.save(_get_layout_config_path())

	if error != OK:
		push_warning("Редактор катсцен: не удалось сохранить настройки интерфейса.")


func _store_editor_window_geometry() -> void:
	if editor_window == null or not is_detached:
		return

	saved_editor_position = editor_window.position
	saved_editor_size = editor_window.size


func _store_preview_window_geometry() -> void:
	if preview_window == null or not preview_window.visible:
		return

	saved_preview_position = preview_window.position
	saved_preview_size = preview_window.size


func _read_vector2i(
	section: String,
	key: String,
	default_value: Vector2i
) -> Vector2i:
	var value: Variant = layout_config.get_value(section, key, default_value)

	if typeof(value) == TYPE_VECTOR2I:
		var vector_value: Vector2i = value
		return vector_value

	return default_value


func _get_layout_config_path() -> String:
	if editor_interface != null:
		var editor_paths: EditorPaths = editor_interface.get_editor_paths()

		if editor_paths != null:
			return editor_paths.get_project_settings_dir().path_join(
				"cutscene_editor.cfg"
			)

	return "res://.godot/editor/cutscene_editor.cfg"

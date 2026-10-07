@tool
extends Control


signal action_selected(index: int)
signal action_clicked(index: int)
signal action_timing_changed(index: int, start_time: float, duration: float)
signal time_changed(time: float)
signal zoom_changed(zoom: float)

const BASE_PIXELS_PER_SECOND: float = 100.0
const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 4.0
const ZOOM_WHEEL_STEP: float = 1.15
const RULER_HEIGHT: float = 26.0
const ROW_HEIGHT: float = 32.0
const LEFT_MARGIN: float = 10.0
const SNAP_STEP: float = 0.1
const EDGE_THRESHOLD: float = 8.0
const MIN_ACTION_DURATION: float = 0.1

const RESIZE_NONE: int = 0
const RESIZE_LEFT: int = 1
const RESIZE_RIGHT: int = 2

var cutscene: CutsceneData = null
var selected_index: int = -1
var current_time: float = 0.0
var zoom_factor: float = 1.0
var pixels_per_second: float = BASE_PIXELS_PER_SECOND
var undo_redo: EditorUndoRedoManager = null

var dragging: bool = false
var resizing: bool = false
var scrubbing: bool = false
var resize_edge: int = RESIZE_NONE
var drag_index: int = -1
var drag_start_mouse_x: float = 0.0
var drag_initial_start: float = 0.0
var drag_initial_duration: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_undo_redo(value: EditorUndoRedoManager) -> void:
	undo_redo = value


func set_cutscene(value: CutsceneData, reset_view: bool = true) -> void:
	var changed_resource: bool = cutscene != value

	if changed_resource and cutscene != null:
		if cutscene.changed.is_connected(_on_cutscene_changed):
			cutscene.changed.disconnect(_on_cutscene_changed)

	cutscene = value

	if changed_resource and cutscene != null:
		if not cutscene.changed.is_connected(_on_cutscene_changed):
			cutscene.changed.connect(_on_cutscene_changed)

	if reset_view or changed_resource:
		selected_index = -1
		current_time = 0.0

	if cutscene == null:
		selected_index = -1
		current_time = 0.0
	else:
		if selected_index >= cutscene.actions.size():
			selected_index = -1

		current_time = clampf(
			current_time,
			0.0,
			get_timeline_duration()
		)

	_update_size()
	queue_redraw()


func set_selected_action(index: int) -> void:
	selected_index = index
	queue_redraw()


func get_selected_action() -> int:
	return selected_index


func set_current_time(
	value: float,
	emit_signal: bool = true,
	snap_value: bool = true
) -> void:
	var target_time: float = value

	if snap_value:
		target_time = _snap_time(target_time)

	current_time = clampf(
		target_time,
		0.0,
		get_timeline_duration()
	)

	if emit_signal:
		time_changed.emit(current_time)

	queue_redraw()


func get_current_time() -> float:
	return current_time


func set_zoom_factor(value: float, emit_signal: bool = true) -> void:
	var new_zoom: float = clampf(value, MIN_ZOOM, MAX_ZOOM)

	if is_equal_approx(new_zoom, zoom_factor):
		return

	zoom_factor = new_zoom
	pixels_per_second = BASE_PIXELS_PER_SECOND * zoom_factor
	_update_size()
	queue_redraw()

	if emit_signal:
		zoom_changed.emit(zoom_factor)


func get_zoom_factor() -> float:
	return zoom_factor


func time_to_x(time: float) -> float:
	return LEFT_MARGIN + maxf(time, 0.0) * pixels_per_second


func get_timeline_duration() -> float:
	if cutscene == null:
		return 1.0

	var result: float = maxf(cutscene.duration, 1.0)

	for action in cutscene.actions:
		if action == null:
			continue

		result = maxf(result, action.start_time + action.duration)

	return result


func _update_size() -> void:
	if cutscene == null:
		custom_minimum_size = Vector2(600.0, 150.0)
		return

	var height: float = maxf(
		150.0,
		RULER_HEIGHT
		+ cutscene.actions.size() * ROW_HEIGHT
		+ 12.0
	)

	custom_minimum_size = Vector2(
		get_timeline_duration() * pixels_per_second
		+ LEFT_MARGIN
		+ 120.0,
		height
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#18181d"))

	if cutscene == null:
		return

	_draw_ruler()
	_draw_rows()
	_draw_actions()
	_draw_playhead()


func _draw_ruler() -> void:
	var duration: float = get_timeline_duration()
	var major_step: int = 1

	if pixels_per_second < 45.0:
		major_step = 5
	elif pixels_per_second < 75.0:
		major_step = 2

	var max_second: int = ceili(duration)
	var second: int = 0

	while second <= max_second:
		var x: float = time_to_x(float(second))

		draw_line(
			Vector2(x, 0.0),
			Vector2(x, RULER_HEIGHT),
			Color("#494951"),
			1.0
		)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x + 3.0, 17.0),
			str(second),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			11,
			Color("#c7c7ce")
		)

		second += major_step

	var minor_step: float = 0.1

	if pixels_per_second < 55.0:
		minor_step = 0.5
	elif pixels_per_second < 85.0:
		minor_step = 0.2

	var tick: float = 0.0

	while tick <= duration + 0.0001:
		var tick_x: float = time_to_x(tick)
		var rounded_seconds: float = roundf(tick)

		if absf(tick - rounded_seconds) > 0.001:
			draw_line(
				Vector2(tick_x, RULER_HEIGHT - 6.0),
				Vector2(tick_x, RULER_HEIGHT),
				Color("#303038"),
				1.0
			)

		tick += minor_step


func _draw_rows() -> void:
	for i in cutscene.actions.size():
		var y: float = RULER_HEIGHT + float(i) * ROW_HEIGHT
		var row_rect: Rect2 = Rect2(0.0, y, size.x, ROW_HEIGHT)

		if i % 2 == 0:
			draw_rect(row_rect, Color("#1d1d23"))

		draw_line(
			Vector2(0.0, y),
			Vector2(size.x, y),
			Color("#292930"),
			1.0
		)


func _draw_actions() -> void:
	for i in cutscene.actions.size():
		var action: CutsceneAction = cutscene.actions[i]

		if action == null:
			continue

		var rect: Rect2 = _get_action_rect(action, i)

		if i == selected_index:
			draw_rect(rect.grow(2.0), Color("#ffffff"), false, 2.0)

		draw_rect(rect, _get_action_color(action))

		if rect.size.x >= 18.0:
			draw_string(
				ThemeDB.fallback_font,
				Vector2(rect.position.x + 5.0, rect.position.y + 16.0),
				_get_action_name(action),
				HORIZONTAL_ALIGNMENT_LEFT,
				maxf(rect.size.x - 9.0, 0.0),
				11,
				Color("#ffffff")
			)

		if i == selected_index:
			_draw_resize_handle(rect.position.x, rect.position.y, rect.end.y)
			_draw_resize_handle(rect.end.x, rect.position.y, rect.end.y)


func _draw_resize_handle(x: float, top: float, bottom: float) -> void:
	draw_line(
		Vector2(x, top + 3.0),
		Vector2(x, bottom - 3.0),
		Color("#ffffff"),
		3.0
	)


func _draw_playhead() -> void:
	var x: float = floorf(time_to_x(current_time)) + 0.5

	draw_line(
		Vector2(x, 0.0),
		Vector2(x, size.y),
		Color("#e65c5c"),
		2.0
	)

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(x - 5.0, 0.0),
			Vector2(x + 5.0, 0.0),
			Vector2(x, 7.0)
		]),
		Color("#e65c5c")
	)


func _get_action_rect(action: CutsceneAction, index: int) -> Rect2:
	var x: float = time_to_x(action.start_time)
	var width: float = maxf(action.duration * pixels_per_second, 8.0)
	var y: float = RULER_HEIGHT + float(index) * ROW_HEIGHT + 4.0
	return Rect2(x, y, width, ROW_HEIGHT - 8.0)


func _gui_input(event: InputEvent) -> void:
	if cutscene == null:
		return

	if not event is InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton

	if mouse_event.ctrl_pressed:
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			set_zoom_factor(zoom_factor * ZOOM_WHEEL_STEP)
			accept_event()
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			set_zoom_factor(zoom_factor / ZOOM_WHEEL_STEP)
			accept_event()
			return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	if mouse_event.position.y <= RULER_HEIGHT:
		scrubbing = true
		_set_time_from_mouse(mouse_event.position.x)
		accept_event()
		return

	_begin_mouse_action(mouse_event.position)
	accept_event()


func _input(event: InputEvent) -> void:
	if not dragging and not resizing and not scrubbing:
		return

	if event is InputEventMouseMotion:
		var local_position: Vector2 = get_local_mouse_position()

		if scrubbing:
			_set_time_from_mouse(local_position.x)
		elif dragging or resizing:
			_update_mouse_action(local_position)

		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if mouse_event.button_index != MOUSE_BUTTON_LEFT or mouse_event.pressed:
			return

		if scrubbing:
			scrubbing = false
			get_viewport().set_input_as_handled()
			return

		if dragging or resizing:
			_finish_mouse_action()
			get_viewport().set_input_as_handled()


func _set_time_from_mouse(mouse_x: float) -> void:
	set_current_time((mouse_x - LEFT_MARGIN) / pixels_per_second)


func _begin_mouse_action(mouse_position: Vector2) -> void:
	var index: int = _get_action_index_at(mouse_position)

	if index < 0:
		selected_index = -1
		queue_redraw()
		return

	selected_index = index
	action_selected.emit(index)

	var action: CutsceneAction = cutscene.actions[index]

	if action == null:
		queue_redraw()
		return

	var rect: Rect2 = _get_action_rect(action, index)
	var distance_left: float = absf(mouse_position.x - rect.position.x)
	var distance_right: float = absf(rect.end.x - mouse_position.x)

	drag_index = index
	drag_start_mouse_x = mouse_position.x
	drag_initial_start = action.start_time
	drag_initial_duration = action.duration
	resize_edge = RESIZE_NONE

	if minf(distance_left, distance_right) <= EDGE_THRESHOLD:
		resizing = true
		dragging = false

		if distance_left <= distance_right:
			resize_edge = RESIZE_LEFT
		else:
			resize_edge = RESIZE_RIGHT
	else:
		dragging = true
		resizing = false

	queue_redraw()


func _update_mouse_action(mouse_position: Vector2) -> void:
	if drag_index < 0 or drag_index >= cutscene.actions.size():
		return

	var action: CutsceneAction = cutscene.actions[drag_index]

	if action == null:
		return

	var delta_time: float = (mouse_position.x - drag_start_mouse_x) / pixels_per_second
	var initial_end: float = drag_initial_start + maxf(drag_initial_duration, MIN_ACTION_DURATION)

	if dragging:
		action.start_time = _snap_time(
			maxf(0.0, drag_initial_start + delta_time)
		)

	elif resizing and resize_edge == RESIZE_LEFT:
		var max_start: float = initial_end - MIN_ACTION_DURATION
		var new_start: float = _snap_time(
			clampf(drag_initial_start + delta_time, 0.0, max_start)
		)
		action.start_time = minf(new_start, max_start)
		action.duration = maxf(
			MIN_ACTION_DURATION,
			initial_end - action.start_time
		)

	elif resizing and resize_edge == RESIZE_RIGHT:
		var new_end: float = _snap_time(
			maxf(
				drag_initial_start + MIN_ACTION_DURATION,
				initial_end + delta_time
			)
		)
		action.duration = maxf(
			MIN_ACTION_DURATION,
			new_end - drag_initial_start
		)

	action_timing_changed.emit(
		drag_index,
		action.start_time,
		action.duration
	)
	_update_size()
	queue_redraw()


func _finish_mouse_action() -> void:
	if drag_index < 0 or drag_index >= cutscene.actions.size():
		_reset_mouse_state()
		return

	var action: CutsceneAction = cutscene.actions[drag_index]

	if action == null:
		_reset_mouse_state()
		return

	var index: int = drag_index
	var old_start: float = drag_initial_start
	var old_duration: float = drag_initial_duration
	var new_start: float = action.start_time
	var new_duration: float = action.duration
	var changed: bool = (
		not is_equal_approx(old_start, new_start)
		or not is_equal_approx(old_duration, new_duration)
	)

	if not changed:
		action_clicked.emit(index)
		_reset_mouse_state()
		return

	if undo_redo != null:
		undo_redo.create_action("Изменить тайминг действия")

		undo_redo.add_do_property(action, &"start_time", new_start)
		undo_redo.add_do_property(action, &"duration", new_duration)
		undo_redo.add_do_method(action, &"emit_changed")
		undo_redo.add_do_method(cutscene, &"emit_changed")

		undo_redo.add_undo_property(action, &"start_time", old_start)
		undo_redo.add_undo_property(action, &"duration", old_duration)
		undo_redo.add_undo_method(action, &"emit_changed")
		undo_redo.add_undo_method(cutscene, &"emit_changed")

		undo_redo.commit_action()
	else:
		_apply_action_timing(action, new_start, new_duration)

	_reset_mouse_state()


func _apply_action_timing(
	action: CutsceneAction,
	start_time: float,
	duration: float
) -> void:
	if action == null:
		return

	action.start_time = start_time
	action.duration = duration
	action.emit_changed()

	if cutscene != null:
		cutscene.emit_changed()

	_update_size()
	queue_redraw()


func _reset_mouse_state() -> void:
	dragging = false
	resizing = false
	scrubbing = false
	resize_edge = RESIZE_NONE
	drag_index = -1
	drag_start_mouse_x = 0.0
	drag_initial_start = 0.0
	drag_initial_duration = 0.0
	queue_redraw()


func _get_action_index_at(position: Vector2) -> int:
	if position.y < RULER_HEIGHT:
		return -1

	for i in cutscene.actions.size():
		var action: CutsceneAction = cutscene.actions[i]

		if action == null:
			continue

		if _get_action_rect(action, i).has_point(position):
			return i

	return -1


func _snap_time(value: float) -> float:
	return roundf(value / SNAP_STEP) * SNAP_STEP


func _get_action_name(action: CutsceneAction) -> String:
	var custom_name: String = action.resource_name.strip_edges()

	if not custom_name.is_empty():
		return custom_name

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


func _get_action_color(action: CutsceneAction) -> Color:
	if action is DialogueAction:
		return Color("#704f8f")
	if action is AnimationAction:
		return Color("#3f7199")
	if action is MoveAction:
		return Color("#467c62")
	if action is WaitAction:
		return Color("#66666f")
	if action is FadeAction:
		return Color("#8a6b3d")
	return Color("#55555c")


func _on_cutscene_changed() -> void:
	_update_size()

	if cutscene != null and selected_index >= cutscene.actions.size():
		selected_index = -1

	var max_time: float = get_timeline_duration()

	if current_time > max_time:
		current_time = max_time
		time_changed.emit(current_time)

	queue_redraw()

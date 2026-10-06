@tool
extends Control


signal action_selected(index)


const PIXELS_PER_SECOND: float = 100.0
const RULER_HEIGHT: float = 30.0
const ROW_HEIGHT: float = 40.0
const LEFT_MARGIN: float = 10.0

const SNAP_STEP: float = 0.1
const EDGE_THRESHOLD: float = 7.0
const MIN_ACTION_DURATION: float = 0.1


var cutscene: CutsceneData = null
var selected_index: int = -1

var undo_redo = null

var dragging: bool = false
var resizing: bool = false

var drag_index: int = -1

var drag_start_mouse_x: float = 0.0
var drag_initial_start: float = 0.0
var drag_initial_duration: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_undo_redo(
	value
) -> void:

	undo_redo = value


func set_cutscene(
	value: CutsceneData
) -> void:

	if cutscene != null:

		if cutscene.changed.is_connected(
			_on_cutscene_changed
		):
			cutscene.changed.disconnect(
				_on_cutscene_changed
			)


	cutscene = value


	if cutscene != null:

		cutscene.changed.connect(
			_on_cutscene_changed
		)


	selected_index = -1

	_update_size()

	queue_redraw()


func set_selected_action(
	index: int
) -> void:

	selected_index = index

	queue_redraw()


func _update_size() -> void:

	if cutscene == null:

		custom_minimum_size = Vector2(
			600.0,
			160.0
		)

		return


	var max_time: float = max(
		cutscene.duration,
		1.0
	)


	for action in cutscene.actions:

		if action == null:
			continue


		max_time = max(
			max_time,
			action.start_time
			+ action.duration
		)


	var height: float = max(
		160.0,
		RULER_HEIGHT
		+ cutscene.actions.size()
		* ROW_HEIGHT
		+ 20.0
	)


	custom_minimum_size = Vector2(
		max_time * PIXELS_PER_SECOND
		+ LEFT_MARGIN
		+ 120.0,
		height
	)


func _draw() -> void:

	draw_rect(
		Rect2(
			Vector2.ZERO,
			size
		),
		Color("#18181d")
	)


	if cutscene == null:
		return


	_draw_ruler()
	_draw_rows()
	_draw_actions()


func _draw_ruler() -> void:

	var duration: float = max(
		cutscene.duration,
		1.0
	)


	for action in cutscene.actions:

		if action == null:
			continue


		duration = max(
			duration,
			action.start_time
			+ action.duration
		)


	var seconds := int(
		ceil(duration)
	)


	for second in range(
		seconds + 1
	):

		var x := (
			LEFT_MARGIN
			+ float(second)
			* PIXELS_PER_SECOND
		)


		draw_line(
			Vector2(
				x,
				0.0
			),
			Vector2(
				x,
				RULER_HEIGHT
			),
			Color("#45454d"),
			1.0
		)


		var font := ThemeDB.fallback_font


		draw_string(
			font,
			Vector2(
				x + 3.0,
				18.0
			),
			str(second),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Color("#bcbcc4")
		)


		for subdivision in range(
			1,
			10
		):

			var sub_x := (
				x
				+ float(subdivision)
				* PIXELS_PER_SECOND
				/ 10.0
			)


			if sub_x >= size.x:
				continue


			draw_line(
				Vector2(
					sub_x,
					RULER_HEIGHT - 7.0
				),
				Vector2(
					sub_x,
					RULER_HEIGHT
				),
				Color("#303038"),
				1.0
			)


func _draw_rows() -> void:

	if cutscene == null:
		return


	for i in cutscene.actions.size():

		var y := (
			RULER_HEIGHT
			+ float(i) * ROW_HEIGHT
		)


		var row_rect := Rect2(
			0.0,
			y,
			size.x,
			ROW_HEIGHT
		)


		if i % 2 == 0:

			draw_rect(
				row_rect,
				Color("#1d1d23")
			)


		draw_line(
			Vector2(
				0.0,
				y
			),
			Vector2(
				size.x,
				y
			),
			Color("#292930"),
			1.0
		)


func _draw_actions() -> void:

	if cutscene == null:
		return


	for i in cutscene.actions.size():

		var action := cutscene.actions[i]

		if action == null:
			continue


		var rect := _get_action_rect(
			action,
			i
		)


		if i == selected_index:

			draw_rect(
				rect.grow(2.0),
				Color("#ffffff"),
				false,
				2.0
			)


		draw_rect(
			rect,
			_get_action_color(action)
		)


		var label := _get_action_name(
			action
		)


		var font := ThemeDB.fallback_font


		draw_string(
			font,
			Vector2(
				rect.position.x + 6.0,
				rect.position.y + 18.0
			),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			max(
				rect.size.x - 10.0,
				0.0
			),
			12,
			Color("#ffffff")
		)


		if i == selected_index:

			var edge_x := (
				rect.position.x
				+ rect.size.x
			)


			draw_line(
				Vector2(
					edge_x,
					rect.position.y + 3.0
				),
				Vector2(
					edge_x,
					rect.end.y - 3.0
				),
				Color("#ffffff"),
				2.0
			)


func _get_action_rect(
	action: CutsceneAction,
	index: int
) -> Rect2:

	var x := (
		LEFT_MARGIN
		+ action.start_time
		* PIXELS_PER_SECOND
	)


	var width := max(
		action.duration
		* PIXELS_PER_SECOND,
		8.0
	)


	var y := (
		RULER_HEIGHT
		+ float(index)
		* ROW_HEIGHT
		+ 5.0
	)


	return Rect2(
		x,
		y,
		width,
		ROW_HEIGHT - 10.0
	)


func _gui_input(
	event: InputEvent
) -> void:

	if cutscene == null:
		return


	if event is InputEventMouseButton:

		var mouse_event := (
			event as InputEventMouseButton
		)


		if mouse_event.button_index != (
			MOUSE_BUTTON_LEFT
		):
			return


		if mouse_event.pressed:

			_begin_mouse_action(
				mouse_event.position
			)

			accept_event()

			return


		if dragging or resizing:

			_finish_mouse_action()

			accept_event()

			return


	if event is InputEventMouseMotion:

		if not dragging and not resizing:
			return


		_update_mouse_action(
			(event as InputEventMouseMotion).position
		)

		accept_event()


func _begin_mouse_action(
	mouse_position: Vector2
) -> void:

	var index := _get_action_index_at(
		mouse_position
	)


	if index < 0:
		selected_index = -1
		queue_redraw()
		return


	selected_index = index

	action_selected.emit(
		index
	)


	var action := cutscene.actions[index]

	if action == null:
		queue_redraw()
		return


	var rect := _get_action_rect(
		action,
		index
	)


	drag_index = index

	drag_start_mouse_x = mouse_position.x

	drag_initial_start = (
		action.start_time
	)

	drag_initial_duration = (
		action.duration
	)


	var distance_to_edge := abs(
		rect.end.x
		- mouse_position.x
	)


	if distance_to_edge <= EDGE_THRESHOLD:

		resizing = true
		dragging = false

	else:

		dragging = true
		resizing = false


	queue_redraw()


func _update_mouse_action(
	mouse_position: Vector2
) -> void:

	if drag_index < 0:
		return


	if drag_index >= cutscene.actions.size():
		return


	var action := (
		cutscene.actions[drag_index]
	)


	if action == null:
		return


	var delta_x := (
		mouse_position.x
		- drag_start_mouse_x
	)


	var delta_time := (
		delta_x
		/ PIXELS_PER_SECOND
	)


	if dragging:

		var new_start := (
			drag_initial_start
			+ delta_time
		)


		new_start = max(
			0.0,
			new_start
		)


		new_start = _snap_time(
			new_start
		)


		action.start_time = new_start


	if resizing:

		var new_duration := (
			drag_initial_duration
			+ delta_time
		)


		new_duration = max(
			MIN_ACTION_DURATION,
			new_duration
		)


		new_duration = _snap_time(
			new_duration
		)


		action.duration = new_duration


	cutscene.emit_changed()

	_update_size()

	queue_redraw()


func _finish_mouse_action() -> void:

	if drag_index < 0:
		_reset_mouse_state()
		return


	if drag_index >= cutscene.actions.size():
		_reset_mouse_state()
		return


	var action := (
		cutscene.actions[drag_index]
	)


	if action == null:
		_reset_mouse_state()
		return


	var old_start := drag_initial_start
	var old_duration := drag_initial_duration

	var new_start := action.start_time
	var new_duration := action.duration


	if (
		is_equal_approx(
			old_start,
			new_start
		)
		and is_equal_approx(
			old_duration,
			new_duration
		)
	):

		_reset_mouse_state()
		return


	if undo_redo != null:

		undo_redo.create_action(
			"Edit Cutscene Action"
		)


		undo_redo.add_do_method(
			_apply_action_timing.bind(
				action,
				new_start,
				new_duration
			)
		)


		undo_redo.add_undo_method(
			_apply_action_timing.bind(
				action,
				old_start,
				old_duration
			)
		)


		undo_redo.commit_action()


	else:

		_apply_action_timing(
			action,
			new_start,
			new_duration
		)


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

	drag_index = -1

	drag_start_mouse_x = 0.0
	drag_initial_start = 0.0
	drag_initial_duration = 0.0

	queue_redraw()


func _get_action_index_at(
	position: Vector2
) -> int:

	if position.y < RULER_HEIGHT:
		return -1


	for i in cutscene.actions.size():

		var action := (
			cutscene.actions[i]
		)


		if action == null:
			continue


		var rect := _get_action_rect(
			action,
			i
		)


		if rect.has_point(position):
			return i


	return -1


func _snap_time(
	value: float
) -> float:

	return (
		round(value / SNAP_STEP)
		* SNAP_STEP
	)


func _get_action_name(
	action: CutsceneAction
) -> String:

	var script: Script = action.get_script()

	if script == null:
		return "Action"


	var global_name: StringName = (
		script.get_global_name()
	)

	if global_name == &"":
		return "Action"


	var result: String = String(
		global_name
	)


	if result.ends_with("Action"):

		result = result.trim_suffix(
			"Action"
		)


	return result


func _get_action_color(
	action: CutsceneAction
) -> Color:

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

	queue_redraw()

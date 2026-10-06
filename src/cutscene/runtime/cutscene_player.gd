class_name CutscenePlayer
extends Node


signal started(cutscene)
signal finished(cutscene)


var is_playing: bool = false
var is_stopped: bool = false

var _current_cutscene: CutsceneData = null
var _target_root: Node = null
var _binding_context: CutsceneBindingContext = null
var _execution_context: CutsceneExecutionContext = null

var _remaining_actions: int = 0
var _run_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func play(
	data: CutsceneData,
	target_root: Node,
	binding_context: CutsceneBindingContext
) -> void:
	if is_playing:
		return

	if data == null:
		push_error("CutscenePlayer: CutsceneData is null.")
		return

	if target_root == null:
		push_error("CutscenePlayer: target_root is null.")
		return

	if binding_context == null:
		push_error("CutscenePlayer: binding context is null.")
		return

	_current_cutscene = data
	_target_root = target_root
	_binding_context = binding_context

	_execution_context = CutsceneExecutionContext.new(
		target_root,
		binding_context
	)

	is_playing = true
	is_stopped = false

	_run_id += 1

	var current_run_id := _run_id

	started.emit(_current_cutscene)

	if _current_cutscene.actions.is_empty():
		_finish(current_run_id)
		return

	var actions: Array[CutsceneAction] = _current_cutscene.actions.duplicate()

	actions.sort_custom(
		func(
			a: CutsceneAction,
			b: CutsceneAction
		) -> bool:
			return a.start_time < b.start_time
	)

	_remaining_actions = actions.size()

	for action in actions:
		_run_action(
			action,
			current_run_id
		)

	await finished


func stop() -> void:
	if not is_playing:
		return

	is_stopped = true

	_run_id += 1

	if _execution_context != null:
		_execution_context.cancel()

	var stopped_cutscene := _current_cutscene

	is_playing = false

	_current_cutscene = null
	_target_root = null
	_binding_context = null
	_execution_context = null

	_remaining_actions = 0

	finished.emit(stopped_cutscene)


func _run_action(
	action: CutsceneAction,
	current_run_id: int
) -> void:
	await _wait_for_start_time(
		action.start_time,
		current_run_id
	)

	if current_run_id != _run_id:
		return

	if _execution_context == null:
		return

	if _execution_context.is_cancelled():
		return

	await action.execute(
		_execution_context
	)

	if current_run_id != _run_id:
		return

	if _execution_context == null:
		return

	if _execution_context.is_cancelled():
		return

	_remaining_actions -= 1

	if _remaining_actions <= 0:
		_finish(current_run_id)


func _wait_for_start_time(
	start_time: float,
	current_run_id: int
) -> void:
	if start_time <= 0.0:
		return

	var end_time := (
		Time.get_ticks_usec()
		+ int(start_time * 1_000_000.0)
	)

	while current_run_id == _run_id:
		if Time.get_ticks_usec() >= end_time:
			break

		if (
			_execution_context != null
			and _execution_context.is_cancelled()
		):
			return

		await Engine.get_main_loop().process_frame


func _finish(
	current_run_id: int
) -> void:
	if current_run_id != _run_id:
		return

	if not is_playing:
		return

	is_playing = false

	var completed_cutscene := _current_cutscene

	_current_cutscene = null
	_target_root = null
	_binding_context = null
	_execution_context = null

	_remaining_actions = 0

	finished.emit(completed_cutscene)

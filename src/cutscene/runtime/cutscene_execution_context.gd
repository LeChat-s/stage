class_name CutsceneExecutionContext
extends RefCounted


var target_root: Node = null
var binding_context: CutsceneBindingContext = null

var _cancelled: bool = false
var _active_tweens: Array[Tween] = []


func _init(
	root: Node,
	context: CutsceneBindingContext
) -> void:
	target_root = root
	binding_context = context


func resolve_target(id: StringName) -> Node:
	if binding_context == null:
		return null

	return binding_context.get_binding(id)


func is_cancelled() -> bool:
	return _cancelled


func cancel() -> void:
	_cancelled = true

	for tween in _active_tweens:
		if tween != null and tween.is_valid():
			tween.kill()

	_active_tweens.clear()


func wait(seconds: float) -> void:
	if seconds <= 0.0:
		return

	var end_time := (
		Time.get_ticks_usec()
		+ int(seconds * 1_000_000.0)
	)

	while not _cancelled:
		if Time.get_ticks_usec() >= end_time:
			break

		await Engine.get_main_loop().process_frame


func create_tween() -> Tween:
	if target_root == null:
		return null

	var tween := target_root.create_tween()

	tween.set_pause_mode(
		Tween.TWEEN_PAUSE_PROCESS
	)

	_active_tweens.append(tween)

	tween.finished.connect(
		func() -> void:
			_active_tweens.erase(tween),
		CONNECT_ONE_SHOT
	)

	return tween


func wait_for_tween(tween: Tween) -> void:
	if tween == null:
		return

	while not _cancelled:
		if not tween.is_valid():
			break

		if not tween.is_running():
			break

		await Engine.get_main_loop().process_frame

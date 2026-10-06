class_name CutsceneTrigger
extends Area2D


signal cutscene_triggered(cutscene)
signal cutscene_completed(cutscene)


enum TriggerMode {
	ON_START,
	ON_PLAYER_ENTER,
	ON_INTERACT,
	MANUAL
}


@export_category("Cutscene")

@export var cutscene: CutsceneData

@export var trigger_mode: TriggerMode = TriggerMode.ON_PLAYER_ENTER

@export var play_once: bool = true


@export_category("Bindings")

@export var binding_context_path: NodePath


@export_category("Player Detection")

@export var player_group: StringName = &"player"


var _triggered: bool = false
var _player_inside: bool = false
var _running: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if trigger_mode == TriggerMode.ON_START:
		call_deferred("_trigger_from_start")


func _unhandled_input(event: InputEvent) -> void:
	if trigger_mode != TriggerMode.ON_INTERACT:
		return

	if not _player_inside:
		return

	if _running:
		return

	if not event.is_action_pressed("interact"):
		return

	trigger()


func _on_body_entered(body: Node2D) -> void:
	if trigger_mode != TriggerMode.ON_PLAYER_ENTER:
		return

	if not _is_player(body):
		return

	_player_inside = true

	trigger()


func _on_body_exited(body: Node2D) -> void:
	if not _is_player(body):
		return

	_player_inside = false


func _trigger_from_start() -> void:
	trigger()


func trigger() -> void:
	if _running:
		return

	if play_once and _triggered:
		return

	if cutscene == null:
		push_error(
			"CutsceneTrigger: CutsceneData is not assigned."
		)
		return

	if CutsceneManager.is_playing:
		return

	var binding_context := _get_binding_context()

	if binding_context == null:
		push_error(
			"CutsceneTrigger: Binding context not found."
		)
		return

	_running = true
	_triggered = true

	set_deferred("monitoring", false)

	cutscene_triggered.emit(cutscene)

	var target_root := binding_context.get_parent()

	await CutsceneManager.play(
		cutscene,
		target_root,
		binding_context
	)

	set_deferred("monitoring", true)

	_running = false

	cutscene_completed.emit(cutscene)


func reset() -> void:
	_triggered = false


func is_triggered() -> bool:
	return _triggered


func _is_player(node: Node) -> bool:
	var current: Node = node

	while current != null:
		if current.is_in_group(player_group):
			return true

		current = current.get_parent()

	return false


func _get_binding_context() -> CutsceneBindingContext:
	if not binding_context_path.is_empty():
		var context := get_node_or_null(
			binding_context_path
		)

		if context == null:
			push_error(
				"CutsceneTrigger: binding context path not found: %s"
				% binding_context_path
			)

			return null

		if not context is CutsceneBindingContext:
			push_error(
				"CutsceneTrigger: node is not CutsceneBindingContext: %s"
				% binding_context_path
			)

			return null

		return context as CutsceneBindingContext


	var current_scene := get_tree().current_scene

	if current_scene == null:
		return null

	var contexts := current_scene.find_children(
		"*",
		"CutsceneBindingContext",
		true,
		false
	)

	if contexts.is_empty():
		return null

	return contexts[0] as CutsceneBindingContext

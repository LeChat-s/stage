extends Node

signal cutscene_started(cutscene)
signal cutscene_finished(cutscene)

var is_playing: bool = false
var current_cutscene: CutsceneData = null

var player: CutscenePlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	player = CutscenePlayer.new()

	player.name = "CutscenePlayer"

	player.process_mode = Node.PROCESS_MODE_ALWAYS

	add_child(player)


func play(
	cutscene: CutsceneData,
	target_root: Node,
	binding_context: CutsceneBindingContext
) -> void:

	if is_playing:
		return

	if cutscene == null:
		push_error(
			"CutsceneManager: cutscene is null."
		)
		return

	if target_root == null:
		push_error(
			"CutsceneManager: target_root is null."
		)
		return

	if binding_context == null:
		push_error(
			"CutsceneManager: binding context is null."
		)
		return

	is_playing = true
	current_cutscene = cutscene

	cutscene_started.emit(cutscene)

	get_tree().paused = true

	await player.play(
		cutscene,
		target_root,
		binding_context
	)

	get_tree().paused = false

	cutscene_finished.emit(cutscene)

	current_cutscene = null
	is_playing = false


func stop() -> void:

	if not is_playing:
		return

	player.stop()

	get_tree().paused = false

	current_cutscene = null
	is_playing = false

@tool
class_name DialogueAction
extends CutsceneAction


@export var speaker: String = ""
@export_multiline var text: String = ""
@export var wait_for_input: bool = true


func execute(
	context: CutsceneExecutionContext
) -> void:

	if context.is_cancelled():
		return

	print(
		"[CUTSCENE] %s: %s"
		% [
			speaker,
			text
		]
	)

	if duration > 0.0:
		await context.wait(duration)

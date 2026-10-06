@tool
class_name WaitAction
extends CutsceneAction


func execute(
	context: CutsceneExecutionContext
) -> void:

	await context.wait(duration)

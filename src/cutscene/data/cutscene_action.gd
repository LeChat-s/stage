@tool
class_name CutsceneAction
extends Resource


@export var start_time: float = 0.0
@export var duration: float = 0.0


func execute(
	context: CutsceneExecutionContext
) -> void:
	push_error(
		"CutsceneAction: execute() is not implemented for %s."
		% get_class()
	)

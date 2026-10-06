@tool
class_name FadeAction
extends CutsceneAction


@export var target_id: StringName = &""


@export_range(
	0.0,
	1.0,
	0.01
)
var target_alpha: float = 1.0


func execute(
	context: CutsceneExecutionContext
) -> void:

	if context.is_cancelled():
		return


	var target := context.resolve_target(
		target_id
	)


	if target == null:
		push_error(
			"FadeAction: target '%s' not found."
			% target_id
		)
		return


	if not target is CanvasItem:
		push_error(
			"FadeAction: target '%s' is not CanvasItem."
			% target_id
		)
		return


	var canvas_item := target as CanvasItem


	var tween := context.create_tween()

	if tween == null:
		return


	tween.tween_property(
		canvas_item,
		"modulate:a",
		target_alpha,
		duration
	)


	await context.wait_for_tween(tween)

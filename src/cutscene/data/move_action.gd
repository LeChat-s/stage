@tool
class_name MoveAction
extends CutsceneAction


@export var target_id: StringName = &""

@export var target_position: Vector2 = Vector2.ZERO

@export var transition: Tween.TransitionType = (
	Tween.TRANS_QUAD
)

@export var ease: Tween.EaseType = (
	Tween.EASE_IN_OUT
)


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
			"MoveAction: target '%s' not found."
			% target_id
		)
		return


	if not target is Node2D:
		push_error(
			"MoveAction: target '%s' is not Node2D."
			% target_id
		)
		return


	var target_2d := target as Node2D


	var tween := context.create_tween()

	if tween == null:
		return


	tween.set_trans(transition)
	tween.set_ease(ease)

	tween.tween_property(
		target_2d,
		"position",
		target_position,
		duration
	)

	await context.wait_for_tween(tween)

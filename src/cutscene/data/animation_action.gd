@tool
class_name AnimationAction
extends CutsceneAction


@export var target_id: StringName = &""
@export var animation: StringName = &""
@export var wait_for_animation: bool = true


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
			"AnimationAction: target '%s' not found."
			% target_id
		)
		return


	var animator := _find_animator(target)


	if animator == null:
		push_error(
			"AnimationAction: AnimationPlayer or AnimatedSprite2D not found inside target '%s'."
			% target_id
		)
		return


	var previous_process_mode := (
		animator.process_mode
	)

	animator.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)


	if animator is AnimatedSprite2D:

		var sprite := animator as AnimatedSprite2D

		if not sprite.sprite_frames.has_animation(
			animation
		):
			animator.process_mode = previous_process_mode

			push_error(
				"AnimationAction: animation '%s' not found."
				% animation
			)

			return

		sprite.play(animation)

		if wait_for_animation:
			while not context.is_cancelled():

				if not sprite.is_playing():
					break

				await Engine.get_main_loop().process_frame

		animator.process_mode = previous_process_mode

		return


	if animator is AnimationPlayer:

		var animation_player := (
			animator as AnimationPlayer
		)

		if not animation_player.has_animation(
			animation
		):
			animator.process_mode = previous_process_mode

			push_error(
				"AnimationAction: animation '%s' not found."
				% animation
			)

			return

		animation_player.play(
			animation
		)

		if wait_for_animation:
			while not context.is_cancelled():

				if not animation_player.is_playing():
					break

				await Engine.get_main_loop().process_frame

		animator.process_mode = previous_process_mode

		return


	animator.process_mode = previous_process_mode

	push_error(
		"AnimationAction: unsupported animator inside target '%s'."
		% target_id
	)


func _find_animator(
	target: Node
) -> Node:

	if target is AnimationPlayer:
		return target

	if target is AnimatedSprite2D:
		return target


	var animation_player := target.find_child(
		"AnimationPlayer",
		true,
		false
	)


	if animation_player != null:
		return animation_player


	var animated_sprite := target.find_child(
		"AnimatedSprite2D",
		true,
		false
	)


	if animated_sprite != null:
		return animated_sprite


	return null

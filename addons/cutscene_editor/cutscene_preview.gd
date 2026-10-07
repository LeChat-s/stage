@tool
extends VBoxContainer


var editor_interface: EditorInterface = null
var cutscene: CutsceneData = null
var current_time: float = 0.0

var aspect_container: AspectRatioContainer
var viewport_container: SubViewportContainer
var viewport: SubViewport
var status_label: Label
var dialogue_label: Label
var refresh_button: Button

var preview_root: Node = null
var preview_camera: Camera2D = null
var game_view_size: Vector2i = Vector2i(1280, 720)
var binding_targets: Dictionary = {}
var baseline_state: Dictionary = {}


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var toolbar: HBoxContainer = HBoxContainer.new()
	add_child(toolbar)

	status_label = Label.new()
	status_label.text = "Катсцена не выбрана"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(status_label)

	refresh_button = Button.new()
	refresh_button.text = "↻"
	refresh_button.tooltip_text = "Пересобрать предпросмотр из открытой сцены"
	refresh_button.pressed.connect(refresh)
	toolbar.add_child(refresh_button)

	game_view_size = _get_game_view_size()

	aspect_container = AspectRatioContainer.new()
	aspect_container.custom_minimum_size = Vector2(0.0, 260.0)
	aspect_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aspect_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	aspect_container.ratio = float(game_view_size.x) / float(game_view_size.y)
	aspect_container.stretch_mode = AspectRatioContainer.STRETCH_FIT
	aspect_container.clip_contents = true
	add_child(aspect_container)

	viewport_container = SubViewportContainer.new()
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspect_container.add_child(viewport_container)

	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.size_2d_override = game_view_size
	viewport.size_2d_override_stretch = true
	viewport_container.add_child(viewport)

	dialogue_label = Label.new()
	dialogue_label.text = ""
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size = Vector2(0.0, 44.0)
	add_child(dialogue_label)


func set_editor_interface(value: EditorInterface) -> void:
	editor_interface = value


func set_cutscene(value: CutsceneData) -> void:
	var changed_resource: bool = cutscene != value
	cutscene = value

	if changed_resource:
		current_time = 0.0
		_rebuild_preview_scene()

	_apply_time()


func set_current_time(value: float) -> void:
	current_time = maxf(value, 0.0)
	_apply_time()


func refresh() -> void:
	_rebuild_preview_scene()
	_apply_time()


func _rebuild_preview_scene() -> void:
	_clear_preview_scene()

	if cutscene == null:
		status_label.text = "Катсцена не выбрана"
		dialogue_label.text = ""
		return

	if editor_interface == null:
		status_label.text = "Предпросмотр недоступен: нет EditorInterface"
		return

	var source_root: Node = editor_interface.get_edited_scene_root()

	if source_root == null:
		status_label.text = "Предпросмотр недоступен: сцена не открыта"
		return

	var source_trigger: CutsceneTrigger = _find_matching_trigger(source_root)

	if source_trigger == null:
		status_label.text = "Не найден CutsceneTrigger для этой катсцены"
		return

	var source_context: Node = _get_trigger_binding_context(source_trigger)

	if source_context == null:
		status_label.text = "Не найден контекст привязок"
		return

	# Duplicate only native node state, not scripts/signals. This keeps preview
	# isolated from @tool callbacks in the scene being edited. Bindings are
	# resolved from the source scene and mapped to the duplicate by NodePath.
	preview_root = source_root.duplicate(Node.DUPLICATE_GROUPS)

	if preview_root == null:
		status_label.text = "Не удалось создать копию сцены для предпросмотра"
		return

	_disable_processing_recursive(preview_root)
	viewport.add_child(preview_root)

	_configure_preview_camera()
	_build_binding_map(source_root, source_context, preview_root)
	_capture_baseline_state()

	if preview_camera != null:
		status_label.text = (
			"Привязок: %d | Камера: %s | %dx%d"
			% [
				binding_targets.size(),
				preview_camera.name,
				game_view_size.x,
				game_view_size.y
			]
		)
	else:
		status_label.text = (
			"Привязок: %d | Без Camera2D | %dx%d"
			% [binding_targets.size(), game_view_size.x, game_view_size.y]
		)


func _clear_preview_scene() -> void:
	preview_camera = null
	binding_targets.clear()
	baseline_state.clear()

	if preview_root != null and is_instance_valid(preview_root):
		preview_root.free()

	preview_root = null


func _disable_processing_recursive(node: Node) -> void:
	# Scene scripts/timers must not run in editor preview. Camera2D stays active
	# so its viewport transform can be updated exactly like the game view.
	if node is Camera2D:
		node.process_mode = Node.PROCESS_MODE_ALWAYS
	else:
		node.process_mode = Node.PROCESS_MODE_DISABLED

	for child in node.get_children():
		_disable_processing_recursive(child)


func _get_game_view_size() -> Vector2i:
	var width: int = int(
		ProjectSettings.get_setting(
			"display/window/size/viewport_width",
			1280
		)
	)
	var height: int = int(
		ProjectSettings.get_setting(
			"display/window/size/viewport_height",
			720
		)
	)

	return Vector2i(maxi(width, 2), maxi(height, 2))


func _configure_preview_camera() -> void:
	preview_camera = viewport.get_camera_2d()

	if preview_camera == null:
		preview_camera = _find_first_enabled_camera(preview_root)

		if preview_camera != null:
			preview_camera.make_current()

	if preview_camera != null:
		preview_camera.reset_smoothing()
		preview_camera.force_update_scroll()


func _find_first_enabled_camera(node: Node) -> Camera2D:
	if node is Camera2D:
		var camera: Camera2D = node as Camera2D

		if camera.enabled:
			return camera

	for child in node.get_children():
		var found: Camera2D = _find_first_enabled_camera(child)

		if found != null:
			return found

	return null


func _update_preview_camera() -> void:
	if preview_camera == null or not is_instance_valid(preview_camera):
		return

	preview_camera.force_update_scroll()


func _find_matching_trigger(node: Node) -> CutsceneTrigger:
	if node is CutsceneTrigger:
		var trigger: CutsceneTrigger = node as CutsceneTrigger

		if trigger.cutscene == cutscene:
			return trigger

	for child in node.get_children():
		var found: CutsceneTrigger = _find_matching_trigger(child)

		if found != null:
			return found

	return null


func _get_trigger_binding_context(trigger: CutsceneTrigger) -> Node:
	if trigger == null:
		return null

	if not trigger.binding_context_path.is_empty():
		return trigger.get_node_or_null(trigger.binding_context_path)

	var scene_root: Node = editor_interface.get_edited_scene_root()

	if scene_root == null:
		return null

	return _find_first_binding_context(scene_root)


func _find_first_binding_context(node: Node) -> CutsceneBindingContext:
	if node is CutsceneBindingContext:
		return node as CutsceneBindingContext

	for child in node.get_children():
		var found: CutsceneBindingContext = _find_first_binding_context(child)

		if found != null:
			return found

	return null


func _build_binding_map(
	source_root: Node,
	source_context: Node,
	duplicate_root: Node
) -> void:
	binding_targets.clear()

	var bindings = source_context.get("bindings")

	if not bindings is Array:
		return

	for binding in bindings:
		if binding == null:
			continue

		var id_value = binding.get("id")
		var target_path_value = binding.get("target_path")

		if id_value == null or target_path_value == null:
			continue

		var id: StringName = StringName(str(id_value))
		var target_path: NodePath = NodePath(str(target_path_value))

		if id == &"" or target_path.is_empty():
			continue

		var source_target: Node = source_context.get_node_or_null(target_path)

		if source_target == null and source_context.get_parent() != null:
			source_target = source_context.get_parent().get_node_or_null(target_path)

		if source_target == null:
			continue

		var relative_path: NodePath = source_root.get_path_to(source_target)
		var preview_target: Node = duplicate_root.get_node_or_null(relative_path)

		if preview_target != null:
			binding_targets[id] = preview_target


func _capture_baseline_state() -> void:
	baseline_state.clear()

	for id in binding_targets.keys():
		var target: Node = binding_targets[id]
		var state: Dictionary = {}

		if target is Node2D:
			state["position"] = (target as Node2D).position

		if target is CanvasItem:
			state["modulate"] = (target as CanvasItem).modulate

		var animator: Node = _find_animator(target)

		if animator is AnimationPlayer:
			var player: AnimationPlayer = animator as AnimationPlayer
			state["animator_type"] = "animation_player"
			state["animation"] = player.assigned_animation

			if player.assigned_animation != &"":
				state["animation_position"] = player.current_animation_position
			else:
				state["animation_position"] = 0.0
		elif animator is AnimatedSprite2D:
			var sprite: AnimatedSprite2D = animator as AnimatedSprite2D
			state["animator_type"] = "animated_sprite"
			state["animation"] = sprite.animation
			state["frame"] = sprite.frame
			state["frame_progress"] = sprite.frame_progress

		baseline_state[id] = state


func _restore_baseline_state() -> void:
	for id in binding_targets.keys():
		if not baseline_state.has(id):
			continue

		var target: Node = binding_targets[id]
		var state: Dictionary = baseline_state[id]
		var animator: Node = _find_animator(target)
		var animator_type: String = str(state.get("animator_type", ""))

		# Reset animation-driven properties first. Explicit transform/modulate
		# snapshots are restored afterwards so the serialized scene state wins.
		if animator_type == "animation_player" and animator is AnimationPlayer:
			var player: AnimationPlayer = animator as AnimationPlayer

			if player.has_animation(&"RESET"):
				player.play(&"RESET")
				player.seek(0.0, true, true)
				player.pause()

			var animation: StringName = state.get("animation", &"")

			if animation != &"" and player.has_animation(animation):
				player.play(animation)
				player.seek(float(state.get("animation_position", 0.0)), true, true)
				player.pause()
			elif not player.has_animation(&"RESET"):
				player.stop(true)

		elif animator_type == "animated_sprite" and animator is AnimatedSprite2D:
			var sprite: AnimatedSprite2D = animator as AnimatedSprite2D
			var animation: StringName = state.get("animation", &"")

			if animation != &"" and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation):
				sprite.animation = animation

			sprite.set_frame_and_progress(
				int(state.get("frame", 0)),
				float(state.get("frame_progress", 0.0))
			)
			sprite.pause()

		if target is Node2D and state.has("position"):
			(target as Node2D).position = state["position"]

		if target is CanvasItem and state.has("modulate"):
			(target as CanvasItem).modulate = state["modulate"]


func _apply_time() -> void:
	if cutscene == null or preview_root == null:
		dialogue_label.text = ""
		return

	_restore_baseline_state()

	var actions: Array[CutsceneAction] = cutscene.actions.duplicate()

	actions.sort_custom(
		func(a: CutsceneAction, b: CutsceneAction) -> bool:
			if a == null:
				return false
			if b == null:
				return true
			return a.start_time < b.start_time
	)

	var active_dialogues: Array[String] = []

	for action in actions:
		if action == null:
			continue

		if current_time < action.start_time:
			continue

		if action is MoveAction:
			_apply_move_action(action as MoveAction)
		elif action is FadeAction:
			_apply_fade_action(action as FadeAction)
		elif action is AnimationAction:
			_apply_animation_action(action as AnimationAction)
		elif action is DialogueAction:
			var dialogue: DialogueAction = action as DialogueAction
			var dialogue_end: float = dialogue.start_time + maxf(dialogue.duration, 0.1)

			if current_time <= dialogue_end:
				var line: String = dialogue.text

				if not dialogue.speaker.is_empty():
					line = "%s: %s" % [dialogue.speaker, dialogue.text]

				active_dialogues.append(line)

	dialogue_label.text = "\n".join(active_dialogues)
	_update_preview_camera()


func _apply_move_action(action: MoveAction) -> void:
	var target: Node = _get_binding_target(action.target_id)

	if not target is Node2D:
		return

	var target_2d: Node2D = target as Node2D
	var start_value: Vector2 = target_2d.position

	if action.duration <= 0.0:
		target_2d.position = action.target_position
		return

	var elapsed: float = clampf(
		current_time - action.start_time,
		0.0,
		action.duration
	)

	target_2d.position = Vector2(Tween.interpolate_value(
		start_value,
		action.target_position - start_value,
		elapsed,
		action.duration,
		action.transition,
		action.ease
	))


func _apply_fade_action(action: FadeAction) -> void:
	var target: Node = _get_binding_target(action.target_id)

	if not target is CanvasItem:
		return

	var canvas_item: CanvasItem = target as CanvasItem
	var start_alpha: float = canvas_item.modulate.a

	if action.duration <= 0.0:
		var immediate: Color = canvas_item.modulate
		immediate.a = action.target_alpha
		canvas_item.modulate = immediate
		return

	var elapsed: float = clampf(
		current_time - action.start_time,
		0.0,
		action.duration
	)

	var alpha: float = float(Tween.interpolate_value(
		start_alpha,
		action.target_alpha - start_alpha,
		elapsed,
		action.duration,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	))

	var modulate: Color = canvas_item.modulate
	modulate.a = alpha
	canvas_item.modulate = modulate


func _apply_animation_action(action: AnimationAction) -> void:
	var target: Node = _get_binding_target(action.target_id)

	if target == null:
		return

	var animator: Node = _find_animator(target)

	if animator == null:
		return

	var local_time: float = maxf(current_time - action.start_time, 0.0)

	if animator is AnimationPlayer:
		var player: AnimationPlayer = animator as AnimationPlayer

		if not player.has_animation(action.animation):
			return

		var animation_resource: Animation = player.get_animation(action.animation)

		if animation_resource != null and animation_resource.length > 0.0:
			if animation_resource.loop_mode != Animation.LOOP_NONE:
				local_time = fmod(local_time, animation_resource.length)
			else:
				local_time = minf(local_time, animation_resource.length)

		player.play(action.animation)
		player.seek(local_time, true, true)
		player.pause()
		return

	if animator is AnimatedSprite2D:
		_apply_animated_sprite_time(
			animator as AnimatedSprite2D,
			action.animation,
			local_time
		)


func _apply_animated_sprite_time(
	sprite: AnimatedSprite2D,
	animation: StringName,
	local_time: float
) -> void:
	var frames: SpriteFrames = sprite.sprite_frames

	if frames == null or not frames.has_animation(animation):
		return

	var frame_count: int = frames.get_frame_count(animation)

	if frame_count <= 0:
		return

	var fps: float = absf(frames.get_animation_speed(animation))

	if fps <= 0.0:
		return

	var frame_lengths: Array[float] = []
	var total_length: float = 0.0

	for i in frame_count:
		var frame_length: float = frames.get_frame_duration(animation, i) / fps
		frame_lengths.append(frame_length)
		total_length += frame_length

	if total_length <= 0.0:
		return

	var loop_mode: int = frames.get_animation_loop_mode(animation)
	var time_in_animation: float = local_time

	if loop_mode == SpriteFrames.LOOP_LINEAR:
		time_in_animation = fmod(time_in_animation, total_length)
	elif loop_mode == SpriteFrames.LOOP_PINGPONG:
		var pingpong_length: float = total_length * 2.0
		var pingpong_time: float = fmod(time_in_animation, pingpong_length)

		if pingpong_time > total_length:
			time_in_animation = pingpong_length - pingpong_time
		else:
			time_in_animation = pingpong_time
	else:
		time_in_animation = minf(time_in_animation, maxf(total_length - 0.000001, 0.0))

	var accumulated: float = 0.0
	var selected_frame: int = frame_count - 1
	var progress: float = 1.0

	for i in frame_count:
		var frame_length: float = frame_lengths[i]

		if time_in_animation < accumulated + frame_length:
			selected_frame = i
			progress = (time_in_animation - accumulated) / maxf(frame_length, 0.000001)
			break

		accumulated += frame_length

	sprite.animation = animation
	sprite.set_frame_and_progress(
		selected_frame,
		clampf(progress, 0.0, 1.0)
	)
	sprite.pause()


func _get_binding_target(id: StringName) -> Node:
	if not binding_targets.has(id):
		return null

	var target: Node = binding_targets[id]

	if target == null or not is_instance_valid(target):
		return null

	return target


func _find_animator(target: Node) -> Node:
	if target is AnimationPlayer or target is AnimatedSprite2D:
		return target

	var animation_player: Node = target.find_child(
		"AnimationPlayer",
		true,
		false
	)

	if animation_player != null:
		return animation_player

	return target.find_child(
		"AnimatedSprite2D",
		true,
		false
	)

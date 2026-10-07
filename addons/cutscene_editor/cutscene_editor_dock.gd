@tool
extends VBoxContainer


const TimelineScript = preload(
	"res://addons/cutscene_editor/cutscene_timeline.gd"
)

var plugin = null
var editor_interface = null
var undo_redo = null


var current_cutscene: CutsceneData = null


var title_label: Label
var duration_label: Label
var current_time_label: Label

var action_list: ItemList

var add_button: MenuButton
var delete_button: Button
var save_button: Button

var timeline: Control
var timeline_scroll: ScrollContainer


func _ready() -> void:

	custom_minimum_size = Vector2(
		900.0,
		320.0
	)

	_build_ui()
	_rebuild_action_menu()


func _build_ui() -> void:

	var header := HBoxContainer.new()

	header.custom_minimum_size = Vector2(
		0.0,
		32.0
	)

	add_child(header)


	title_label = Label.new()

	title_label.text = "Cutscene Editor"

	title_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	header.add_child(title_label)


	duration_label = Label.new()

	duration_label.text = "Duration: 0.0"

	header.add_child(duration_label)
	
	current_time_label = Label.new()

	current_time_label.text = "Time: 0.00"

	header.add_child(current_time_label)

	save_button = Button.new()

	save_button.text = "Save"

	save_button.pressed.connect(
		save_cutscene
	)

	header.add_child(save_button)


	add_button = MenuButton.new()

	add_button.text = "Add Action"

	header.add_child(add_button)


	delete_button = Button.new()

	delete_button.text = "Delete"

	delete_button.disabled = true

	delete_button.pressed.connect(
		_delete_selected_action
	)

	header.add_child(delete_button)


	var separator := HSeparator.new()

	add_child(separator)


	var split := HSplitContainer.new()

	split.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	add_child(split)


	var left := VBoxContainer.new()

	left.custom_minimum_size = Vector2(
		240.0,
		0.0
	)

	split.add_child(left)


	var actions_label := Label.new()

	actions_label.text = "Actions"

	left.add_child(actions_label)


	action_list = ItemList.new()

	action_list.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	action_list.item_selected.connect(
		_on_action_selected
	)

	left.add_child(action_list)


	var right := VBoxContainer.new()

	right.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	split.add_child(right)


	var timeline_label := Label.new()

	timeline_label.text = "Timeline"

	right.add_child(timeline_label)


	timeline_scroll = ScrollContainer.new()

	timeline_scroll.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	timeline_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)

	timeline_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)

	right.add_child(timeline_scroll)


	timeline = TimelineScript.new()

	timeline.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	timeline.set_undo_redo(
		undo_redo
	)

	timeline.action_selected.connect(
		_on_timeline_action_selected
	)
	timeline.action_clicked.connect(
		_on_timeline_action_clicked
	)
	timeline.time_changed.connect(
		_on_timeline_time_changed
	)
	timeline_scroll.add_child(
		timeline
	)

func _rebuild_action_menu() -> void:

	if add_button == null:
		return


	var popup := add_button.get_popup()

	popup.clear()

	var ids := (
		CutsceneActionRegistry.get_action_ids()
	)

	for id in ids:

		var index := popup.item_count

		popup.add_item(
			CutsceneActionRegistry.get_display_name(id)
		)

		popup.set_item_metadata(
			index,
			id
		)


	if not popup.id_pressed.is_connected(
		_on_add_action_pressed
	):
		popup.id_pressed.connect(
			_on_add_action_pressed
		)


func edit_cutscene(
	cutscene: CutsceneData
) -> void:

	if current_cutscene != null:

		if current_cutscene.changed.is_connected(
			_on_cutscene_changed
		):
			current_cutscene.changed.disconnect(
				_on_cutscene_changed
			)


	current_cutscene = cutscene


	if current_cutscene != null:

		current_cutscene.changed.connect(
			_on_cutscene_changed
		)


	_refresh()


func clear_cutscene() -> void:

	if current_cutscene != null:

		if current_cutscene.changed.is_connected(
			_on_cutscene_changed
		):
			current_cutscene.changed.disconnect(
				_on_cutscene_changed
			)


	current_cutscene = null

	_refresh()


func _refresh() -> void:

	if action_list == null:
		return


	action_list.clear()

	delete_button.disabled = true


	if current_cutscene == null:

		title_label.text = "Cutscene Editor"
		duration_label.text = "Duration: 0.0"

		timeline.set_cutscene(
			null
		)

		return


	title_label.text = (
		"Cutscene: "
		+ current_cutscene.title
	)


	duration_label.text = (
		"Duration: %.2f"
		% current_cutscene.duration
	)

	current_time_label.text = "Time: 0.00"

	for i in current_cutscene.actions.size():

		var action := (
			current_cutscene.actions[i]
		)

		if action == null:

			action_list.add_item(
				"%d. <Invalid Action>"
				% [i + 1]
			)

			continue


		var action_name := (
			_get_action_display_name(action)
		)


		var item_text := (
			"%d. %s   %.2f → %.2f"
			% [
				i + 1,
				action_name,
				action.start_time,
				action.start_time + action.duration
			]
		)


		action_list.add_item(
			item_text
		)


	timeline.set_cutscene(
		current_cutscene
	)


func _get_action_display_name(
	action: CutsceneAction
) -> String:

	var script: Script = action.get_script()

	if script == null:
		return "Unknown"

	var global_name: StringName = (
		script.get_global_name()
	)

	if global_name == &"":
		return "Action"

	var result: String = String(
		global_name
	)

	if result.ends_with("Action"):
		result = result.trim_suffix(
			"Action"
		)

	return result


func _on_action_selected(
	index: int
) -> void:

	if current_cutscene == null:
		return


	if index < 0:
		return


	if index >= current_cutscene.actions.size():
		return


	delete_button.disabled = false


	var action := (
		current_cutscene.actions[index]
	)


	if action == null:
		return


	if editor_interface != null:

		editor_interface.edit_resource(
			action
		)

		if plugin != null:

			plugin.call_deferred(
				"show_dock"
			)


	timeline.set_selected_action(
		index
	)


func _on_timeline_action_selected(
	index: int
) -> void:

	if index < 0:
		return

	if index >= action_list.item_count:
		return

	action_list.select(
		index
	)

	delete_button.disabled = false


func _on_add_action_pressed(
	menu_index: int
) -> void:

	if current_cutscene == null:
		return


	var popup := add_button.get_popup()

	var metadata := (
		popup.get_item_metadata(
			menu_index
		)
	)


	var action_id := StringName(
		str(metadata)
	)


	var action := (
		CutsceneActionRegistry.create_action(
			action_id
		)
	)


	if action == null:
		return


	action.start_time = (
		_get_next_start_time()
	)


	var before := (
		current_cutscene.actions.duplicate()
	)


	var after := (
		current_cutscene.actions.duplicate()
	)

	after.append(action)


	_apply_actions(
		before,
		after,
		"Add Cutscene Action"
	)


	_select_last_action()


func _delete_selected_action() -> void:

	if current_cutscene == null:
		return


	var selected := (
		action_list.get_selected_items()
	)


	if selected.is_empty():
		return


	var index := selected[0]


	if index < 0:
		return


	if index >= current_cutscene.actions.size():
		return


	var before := (
		current_cutscene.actions.duplicate()
	)

	var after := (
		current_cutscene.actions.duplicate()
	)


	after.remove_at(
		index
	)


	_apply_actions(
		before,
		after,
		"Delete Cutscene Action"
	)


	_refresh()


func _apply_actions(
	before: Array[CutsceneAction],
	after: Array[CutsceneAction],
	action_name: String
) -> void:

	if undo_redo != null:

		undo_redo.create_action(
			action_name
		)

		undo_redo.add_do_property(
			current_cutscene,
			"actions",
			after
		)

		undo_redo.add_undo_property(
			current_cutscene,
			"actions",
			before
		)

		undo_redo.add_do_method(
			current_cutscene,
			"emit_changed"
		)

		undo_redo.add_undo_method(
			current_cutscene,
			"emit_changed"
		)

		undo_redo.commit_action()

	else:

		current_cutscene.actions = after

		current_cutscene.emit_changed()


func _get_next_start_time() -> float:

	if current_cutscene == null:
		return 0.0


	var result := 0.0


	for action in current_cutscene.actions:

		if action == null:
			continue


		result = max(
			result,
			action.start_time
			+ action.duration
		)


	return result


func _select_last_action() -> void:

	if current_cutscene == null:
		return


	if current_cutscene.actions.is_empty():
		return


	var index := (
		current_cutscene.actions.size() - 1
	)


	action_list.select(
		index
	)


	_on_action_selected(
		index
	)


func _on_cutscene_changed() -> void:

	_refresh()


func save_cutscene() -> void:

	if current_cutscene == null:
		return


	if current_cutscene.resource_path.is_empty():

		push_warning(
			"Cutscene Editor: current CutsceneData has no resource path."
		)

		return


	var error := ResourceSaver.save(
		current_cutscene,
		current_cutscene.resource_path
	)


	if error != OK:

		push_error(
			"Cutscene Editor: failed to save cutscene. Error: %s"
			% error
		)

func _on_timeline_time_changed(
	time: float
) -> void:

	if current_time_label == null:
		return

	current_time_label.text = (
		"Time: %.2f"
		% time
	)

func _on_timeline_action_clicked(
	index: int
) -> void:

	if index < 0:
		return

	if index >= action_list.item_count:
		return

	action_list.select(
		index
	)

	_on_action_selected(
		index
	)

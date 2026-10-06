@tool
extends EditorPlugin


const DockScript = preload(
	"res://addons/cutscene_editor/cutscene_editor_dock.gd"
)


var dock: Control = null


func _enter_tree() -> void:

	dock = DockScript.new()

	dock.editor_interface = get_editor_interface()
	dock.undo_redo = get_undo_redo()

	add_control_to_bottom_panel(
		dock,
		"Cutscene"
	)


func _exit_tree() -> void:

	if dock != null:
		remove_control_from_bottom_panel(
			dock
		)

		dock.queue_free()

		dock = null


func _handles(object: Object) -> bool:
	return object is CutsceneData


func _edit(object: Object) -> void:

	if dock == null:
		return


	if object == null:
		dock.clear_cutscene()
		return


	if object is CutsceneData:

		dock.edit_cutscene(
			object as CutsceneData
		)

		make_bottom_panel_item_visible(
			dock
		)


func _clear() -> void:

	if dock != null:
		dock.clear_cutscene()


func _save_external_data() -> void:

	if dock != null:
		dock.save_cutscene()

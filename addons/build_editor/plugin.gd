@tool
extends EditorPlugin

const PLUGIN_VERSION := "0.39.4"
const DOCK_PATH := "res://addons/build_editor/build_editor_dock.gd"

var editor_dock: EditorDock = null
var content: Control = null

func _enter_tree() -> void:
	print("Build Editor ", PLUGIN_VERSION, " loaded")
	var dock_script: Script = load(DOCK_PATH) as Script
	if dock_script == null:
		push_error("Build Editor %s: не удалось загрузить %s" % [PLUGIN_VERSION, DOCK_PATH])
		return
	if not dock_script.can_instantiate():
		push_error("Build Editor %s: dock-скрипт не может быть создан. Откройте %s — там будет первичная ошибка парсера." % [PLUGIN_VERSION, DOCK_PATH])
		return

	content = dock_script.new() as Control
	if content == null:
		push_error("Build Editor %s: dock_script.new() вернул null." % PLUGIN_VERSION)
		return
	content.set("editor_interface", get_editor_interface())

	editor_dock = EditorDock.new()
	editor_dock.name = "BuildEditorDock"
	editor_dock.title = "Билды"
	editor_dock.layout_key = "stage_build_editor"
	editor_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	editor_dock.available_layouts = EditorDock.DOCK_LAYOUT_ALL
	editor_dock.force_show_icon = true
	editor_dock.icon_name = &"ResourcePreloader"
	editor_dock.add_child(content)
	add_dock(editor_dock)

func _exit_tree() -> void:
	if editor_dock != null:
		remove_dock(editor_dock)
		editor_dock.queue_free()
		editor_dock = null
		content = null

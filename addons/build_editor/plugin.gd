@tool
extends EditorPlugin

const PLUGIN_VERSION := "0.37.1"
const DOCK_PATH := "res://addons/build_editor/build_editor_dock.gd"
var dock: Control = null

func _enter_tree() -> void:
	print("Build Editor ", PLUGIN_VERSION, " loaded")
	var dock_script: Script = load(DOCK_PATH) as Script
	if dock_script == null:
		push_error("Build Editor %s: не удалось загрузить %s" % [PLUGIN_VERSION, DOCK_PATH])
		return
	if not dock_script.can_instantiate():
		push_error("Build Editor %s: dock-скрипт не может быть создан. Откройте res://addons/build_editor/build_editor_dock.gd — там будет первичная ошибка парсера." % PLUGIN_VERSION)
		return

	dock = dock_script.new() as Control
	if dock == null:
		push_error("Build Editor %s: dock_script.new() вернул null." % PLUGIN_VERSION)
		return

	dock.set("editor_interface", get_editor_interface())
	add_control_to_bottom_panel(dock, "Билды")

func _exit_tree() -> void:
	if dock != null:
		remove_control_from_bottom_panel(dock)
		dock.queue_free()
		dock = null

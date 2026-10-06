@tool
class_name CutsceneActionRegistry
extends RefCounted


const ACTIONS: Dictionary = {
	&"dialogue": {
		"display_name": "Dialogue",
		"category": "Dialogue",
		"description": "Shows dialogue text.",
		"script": preload(
			"res://src/cutscene/data/dialogue_action.gd"
		)
	},

	&"wait": {
		"display_name": "Wait",
		"category": "Flow",
		"description": "Waits for a specified amount of time.",
		"script": preload(
			"res://src/cutscene/data/wait_action.gd"
		)
	},

	&"animation": {
		"display_name": "Animation",
		"category": "Animation",
		"description": "Plays an animation on a bound target.",
		"script": preload(
			"res://src/cutscene/data/animation_action.gd"
		)
	},

	&"move": {
		"display_name": "Move",
		"category": "Transform",
		"description": "Moves a bound Node2D.",
		"script": preload(
			"res://src/cutscene/data/move_action.gd"
		)
	},

	&"fade": {
		"display_name": "Fade",
		"category": "Visual",
		"description": "Changes the alpha of a bound CanvasItem.",
		"script": preload(
			"res://src/cutscene/data/fade_action.gd"
		)
	}
}


static func get_action_ids() -> Array[StringName]:
	var result: Array[StringName] = []

	for id in ACTIONS.keys():
		result.append(id)

	return result


static func has_action(id: StringName) -> bool:
	return ACTIONS.has(id)


static func get_definition(id: StringName) -> Dictionary:
	if not ACTIONS.has(id):
		return {}

	return ACTIONS[id]


static func get_display_name(id: StringName) -> String:
	var definition := get_definition(id)

	if definition.is_empty():
		return ""

	return definition.get(
		"display_name",
		String(id)
	)


static func get_category(id: StringName) -> String:
	var definition := get_definition(id)

	if definition.is_empty():
		return ""

	return definition.get(
		"category",
		""
	)


static func get_description(id: StringName) -> String:
	var definition := get_definition(id)

	if definition.is_empty():
		return ""

	return definition.get(
		"description",
		""
	)


static func create_action(id: StringName) -> CutsceneAction:
	if not ACTIONS.has(id):
		push_error(
			"CutsceneActionRegistry: action '%s' is not registered."
			% id
		)

		return null

	var definition: Dictionary = ACTIONS[id]

	var action_script: Script = definition.get(
		"script"
	)

	if action_script == null:
		push_error(
			"CutsceneActionRegistry: action '%s' has no script."
			% id
		)

		return null

	var action = action_script.new()

	if not action is CutsceneAction:
		push_error(
			"CutsceneActionRegistry: script for '%s' does not extend CutsceneAction."
			% id
		)

		return null

	return action as CutsceneAction

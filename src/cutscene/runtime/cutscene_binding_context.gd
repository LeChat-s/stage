class_name CutsceneBindingContext
extends Node


@export var bindings: Array[CutsceneBinding] = []

var _cache: Dictionary = {}


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	_cache.clear()

	for binding in bindings:
		if binding == null:
			continue

		if binding.id == &"":
			push_warning(
				"CutsceneBindingContext: binding has empty id."
			)
			continue

		if _cache.has(binding.id):
			push_error(
				"CutsceneBindingContext: duplicate binding id '%s'."
				% binding.id
			)
			continue

		var target := _resolve_path(binding.target_path)

		if target == null:
			push_error(
				"CutsceneBindingContext: target for '%s' not found: %s"
				% [
					binding.id,
					binding.target_path
				]
			)
			continue

		_cache[binding.id] = target


func has_binding(id: StringName) -> bool:
	return _cache.has(id)


func get_binding(id: StringName) -> Node:
	if not _cache.has(id):
		return null

	var target = _cache[id]

	if target == null:
		return null

	if not is_instance_valid(target):
		_cache.erase(id)
		return null

	return target


func get_binding_ids() -> Array[StringName]:
	var result: Array[StringName] = []

	for id in _cache.keys():
		result.append(id)

	return result


func _resolve_path(path: NodePath) -> Node:
	if path.is_empty():
		return null

	var target := get_node_or_null(path)

	if target != null:
		return target

	var root := get_parent()

	if root != null:
		target = root.get_node_or_null(path)

		if target != null:
			return target

	return null

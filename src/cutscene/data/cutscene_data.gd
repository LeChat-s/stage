@tool
class_name CutsceneData
extends Resource

@export var title: String = ""
@export var duration: float = 0.0

@export_category("Bindings")
@export var binding_ids: Array[StringName] = []

@export_category("Actions")
@export var actions: Array[CutsceneAction] = []

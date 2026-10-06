extends Node2D


@export var cutscene: CutsceneData

@onready var binding_context: CutsceneBindingContext = (
	$CutsceneBindings
)


func _ready() -> void:
	for id in CutsceneActionRegistry.get_action_ids():
		print(
			"Action: ",
			String(id),
			" | ",
			CutsceneActionRegistry.get_display_name(id),
			" | category = ",
			CutsceneActionRegistry.get_category(id)
		)

	var animation_action := CutsceneActionRegistry.create_action(
		&"animation"
	)

	print(
		"AnimationAction valid: ",
		animation_action is AnimationAction
	)

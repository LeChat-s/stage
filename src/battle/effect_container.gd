class_name EffectContainer
extends HBoxContainer

const EFFECT_ICON_SCENE = preload("res://src/ui/effect_icon.tscn")

var active_icons: Dictionary = {}

func update_effect(effect_id: String, value: int, icon_texture: Texture2D) -> void:
	if value == 0:
		remove_effect(effect_id)
		return

	if active_icons.has(effect_id):
		active_icons[effect_id].update_value(value)
	else:
		var new_icon = EFFECT_ICON_SCENE.instantiate() as EffectIcon
		add_child(new_icon)
		new_icon.setup(icon_texture, value)
		active_icons[effect_id] = new_icon
		
func remove_effect(effect_id: String) -> void:
	if active_icons.has(effect_id):
		active_icons[effect_id].queue_free()
		active_icons.erase(effect_id)

func clear_all() -> void:
	for effect_id in active_icons.keys():
		remove_effect(effect_id)

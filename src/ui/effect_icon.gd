class_name EffectIcon
extends TextureRect

@onready var value_label: Label = $ValueLabel

func setup(icon_texture: Texture2D, value: int) -> void:
	texture = icon_texture
	update_value(value)

func update_value(new_value: int) -> void:
	if value_label:
		if new_value == -1:
			value_label.visible = false
		else:
			value_label.text = str(new_value)
			value_label.visible = new_value > 0

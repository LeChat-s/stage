class_name CombatStatusIcon
extends PanelContainer

@onready var symbol_label: Label = $Symbol
@onready var value_label: Label = $Value
@onready var duration_label: Label = $Duration
var _style: StyleBoxFlat = StyleBoxFlat.new()

func _ready() -> void:
    custom_minimum_size = Vector2(30.0, 30.0)
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    mouse_filter = Control.MOUSE_FILTER_STOP
    _style.bg_color = Color("#20242b")
    _style.border_color = Color("#6d7582")
    _style.set_border_width_all(1)
    _style.corner_radius_top_left = 2
    _style.corner_radius_top_right = 2
    _style.corner_radius_bottom_left = 2
    _style.corner_radius_bottom_right = 2
    _style.anti_aliasing = false
    add_theme_stylebox_override("panel", _style)

func setup(symbol: String, accent: Color, value_text: String, duration: int, description: String) -> void:
    _style.bg_color = accent.darkened(0.62)
    _style.border_color = accent
    symbol_label.text = symbol
    symbol_label.modulate = accent.lightened(0.28)
    value_label.text = value_text
    value_label.visible = not value_text.is_empty()
    duration_label.text = str(duration)
    duration_label.visible = duration > 0
    tooltip_text = description

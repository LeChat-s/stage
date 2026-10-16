@tool
extends Control

const CardFaceScript = preload("res://src/data/cards/card_face.gd")
const NATIVE_SIZE := Vector2(212.0, 300.0)
const EMBEDDED_SCALE := 0.5
const DISPLAY_SIZE := NATIVE_SIZE * EMBEDDED_SCALE

var face: CardFace = null

func _ready() -> void:
	custom_minimum_size = DISPLAY_SIZE + Vector2(8.0, 8.0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	face = CardFaceScript.new() as CardFace
	face.size = NATIVE_SIZE
	face.scale = Vector2.ONE * EMBEDDED_SCALE
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(face)

	resized.connect(_layout_face)
	call_deferred("_layout_face")

func set_card(value) -> void:
	if face != null:
		face.set_card(value)

func set_draft(value: Dictionary) -> void:
	if face != null:
		face.set_draft(value)

func _layout_face() -> void:
	if face == null:
		return
	face.position = ((size - DISPLAY_SIZE) * 0.5).floor()

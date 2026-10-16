@tool
class_name CardFace
extends Control

const TEMPLATE_PATHS := {
	"attack": "res://assets/card/attack_base.png",
	"defense": "res://assets/card/defend_base.png",
	"event": "res://assets/card/event_base.png",
	"status": "res://assets/card/status_effect_base.png",
	"infection": "res://assets/card/contamination_base.png",
}

const CARD_SIZE := Vector2(212.0, 300.0)
const ART_RECT := Rect2(30.0, 70.0, 152.0, 64.0)
const DESC_RECT := Rect2(33.0, 143.0, 146.0, 72.0)

var card: Resource = null
var draft: Dictionary = {}

var _templates: Dictionary = {}
var _font: Font = null

func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED

	_font = load("res://assets/fonts/PixeloidSans.ttf") as Font
	if _font == null:
		_font = ThemeDB.fallback_font

	_load_templates()
	queue_redraw()

func set_card(value: Resource) -> void:
	card = value
	draft.clear()
	queue_redraw()

func set_draft(value: Dictionary) -> void:
	draft = value.duplicate(true)
	queue_redraw()

func _load_templates() -> void:
	_templates.clear()
	for type_id in TEMPLATE_PATHS.keys():
		var path: String = str(TEMPLATE_PATHS[type_id])
		if ResourceLoader.exists(path):
			_templates[type_id] = load(path) as Texture2D

func _draw() -> void:
	var card_type: String = _normalize_type(str(_value("type", "event")))
	var template: Texture2D = _templates.get(card_type, null) as Texture2D

	if template == null:
		draw_rect(Rect2(Vector2.ZERO, CARD_SIZE), Color("#2a2d34"))
		_draw_center_message("Нет шаблона")
		return

	draw_texture_rect(template, Rect2(Vector2.ZERO, CARD_SIZE), false)
	_draw_artwork()
	_draw_title()
	_draw_description()
	_draw_cost()
	_draw_stats()

func _value(key: String, fallback):
	if draft.has(key):
		return draft[key]
	if card != null:
		var value = card.get(key)
		if value != null:
			return value
	return fallback

func _normalize_type(value: String) -> String:
	var clean: String = value.to_lower().strip_edges()
	match clean:
		"attack", "atk":
			return "attack"
		"defense", "defend", "def":
			return "defense"
		"infection", "contamination":
			return "infection"
		"status", "status_effect", "effect":
			return "status"
		"event", "evt", "skill":
			return "event"
		_:
			var card_id: String = str(_value("id", ""))
			if card_id.begins_with("atk_"):
				return "attack"
			if card_id.begins_with("def_"):
				return "defense"
			if card_id.begins_with("con_"):
				return "infection"
			if card_id.begins_with("status_"):
				return "status"
			return "event"

func _draw_artwork() -> void:
	var artwork: Texture2D = _value("artwork", null) as Texture2D
	if artwork == null:
		return

	# Старые ресурсы хранили сам *_base.png в artwork.
	# В новой системе база — отдельный слой, поэтому такой artwork пропускаем.
	var path: String = artwork.resource_path
	if path.ends_with("_base.png"):
		return

	var art_size: Vector2 = artwork.get_size()
	if art_size.x <= 0.0 or art_size.y <= 0.0:
		return

	# Заполняем окно без выхода за рамки. Центрируем crop.
	var target_ratio: float = ART_RECT.size.x / ART_RECT.size.y
	var source_ratio: float = art_size.x / art_size.y
	var source := Rect2(Vector2.ZERO, art_size)

	if source_ratio > target_ratio:
		var wanted_width: float = art_size.y * target_ratio
		source.position.x = floor((art_size.x - wanted_width) * 0.5)
		source.size.x = wanted_width
	elif source_ratio < target_ratio:
		var wanted_height: float = art_size.x / target_ratio
		source.position.y = floor((art_size.y - wanted_height) * 0.5)
		source.size.y = wanted_height

	draw_texture_rect_region(artwork, ART_RECT, source)

func _draw_title() -> void:
	var text: String = str(_value("name", "Новая карта"))
	if text.is_empty():
		return

	var rect := Rect2(Vector2(31.0, 31.0), Vector2(150.0, 30.0))
	var font_size: int = int(_value("title_font_size", 11))
	var color: Color = _value("title_color", Color("#f8eef5"))
	_draw_centered_fitted(text, rect, font_size, 6, color)

func _draw_description() -> void:
	var text: String = str(_value("description", ""))
	if text.is_empty():
		return

	var font_size: int = int(_value("description_font_size", 7))
	var color: Color = _value("description_color", Color("#3b2938"))
	_draw_wrapped(text, DESC_RECT, font_size, color, 8)

func _draw_cost() -> void:
	var text: String = str(int(_value("cost", 0)))
	var rect := Rect2(Vector2(28.0, 238.0), Vector2(42.0, 42.0))
	var font_size: int = int(_value("cost_font_size", 18))
	var color: Color = _value("cost_color", Color("#342637"))
	_draw_centered_fitted(text, rect, font_size, 8, color)

func _draw_stats() -> void:
	var dmg: int = int(_value("dmg", 0))
	var shield: int = int(_value("shild", 0))
	var parts: PackedStringArray = []

	if dmg > 0:
		parts.append("УРН %d" % dmg)
	if shield > 0:
		parts.append("БЛК %d" % shield)
	if parts.is_empty():
		return

	var rect := Rect2(Vector2(82.0, 241.0), Vector2(100.0, 34.0))
	var text: String = "  ".join(parts)
	var font_size: int = int(_value("stats_font_size", 8))
	var color: Color = _value("stats_color", Color("#3b2938"))
	_draw_centered_fitted(text, rect, font_size, 6, color)

func _draw_centered_fitted(
	text: String,
	rect: Rect2,
	start_size: int,
	min_size: int,
	color: Color
) -> void:
	var font_size: int = maxi(start_size, min_size)

	while font_size > min_size:
		var width: float = _font.get_string_size(
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size
		).x
		if width <= rect.size.x:
			break
		font_size -= 1

	var text_size: Vector2 = _font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	)
	var baseline := Vector2(
		rect.position.x + (rect.size.x - text_size.x) * 0.5,
		rect.position.y + (rect.size.y + text_size.y) * 0.5 - 1.0
	).floor()

	draw_string(
		_font,
		baseline,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)

func _draw_wrapped(
	text: String,
	rect: Rect2,
	font_size: int,
	color: Color,
	max_lines: int
) -> void:
	var words: PackedStringArray = text.replace("\n", " \n ").split(" ", false)
	var lines: Array[String] = []
	var current: String = ""

	for word in words:
		if word == "\n":
			if not current.is_empty():
				lines.append(current)
				current = ""
			if lines.size() >= max_lines:
				break
			continue

		var candidate: String = word if current.is_empty() else current + " " + word
		var width: float = _font.get_string_size(
			candidate,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size
		).x

		if width <= rect.size.x:
			current = candidate
		else:
			if not current.is_empty():
				lines.append(current)
			current = word

		if lines.size() >= max_lines:
			break

	if not current.is_empty() and lines.size() < max_lines:
		lines.append(current)

	var line_height: float = float(font_size + 2)
	for i in range(mini(lines.size(), max_lines)):
		draw_string(
			_font,
			(rect.position + Vector2(0.0, float(i + 1) * line_height)).floor(),
			lines[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			color
		)

func _draw_center_message(value: String) -> void:
	var font_size := 12
	var width := _font.get_string_size(
		value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x
	draw_string(
		_font,
		Vector2((CARD_SIZE.x - width) * 0.5, CARD_SIZE.y * 0.5),
		value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color.WHITE
	)

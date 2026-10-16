@tool
extends Control

const MODE_IDLE := 0
const MODE_ATTACK := 1

var build = null
var frame_index: int = 0
var elapsed: float = 0.0
var animation_mode: int = MODE_IDLE
var paused: bool = false
var texture_override: Texture2D = null

func _ready() -> void:
	custom_minimum_size = Vector2(300.0, 280.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	set_process(true)

func set_build(value) -> void:
	build = value
	texture_override = null
	frame_index = 0
	elapsed = 0.0
	queue_redraw()

func set_texture_override(value: Texture2D) -> void:
	texture_override = value
	frame_index = 0
	elapsed = 0.0
	queue_redraw()

func set_animation_mode(value: int) -> void:
	animation_mode = clampi(value, MODE_IDLE, MODE_ATTACK)
	frame_index = 0
	elapsed = 0.0
	queue_redraw()

func set_paused(value: bool) -> void:
	paused = value
	set_process(not paused)
	queue_redraw()

func _process(delta: float) -> void:
	if paused or build == null:
		return
	var frames: PackedInt32Array = _get_frames()
	if frames.is_empty():
		return
	var fps: float = _get_fps()
	elapsed += delta
	var frame_time: float = 1.0 / maxf(fps, 1.0)
	if elapsed < frame_time:
		return
	elapsed = fmod(elapsed, frame_time)
	frame_index = (frame_index + 1) % frames.size()
	queue_redraw()

func _draw() -> void:
	_draw_background()
	if build == null:
		_draw_center_text("Выберите билд")
		return

	var texture: Texture2D = texture_override
	if texture == null:
		texture = build.get("player_sprite_sheet") as Texture2D
	if texture == null:
		_draw_center_text("Выберите sprite sheet")
		return

	var hframes: int = maxi(int(build.get("player_hframes")), 1)
	var vframes: int = maxi(int(build.get("player_vframes")), 1)
	var total_frames: int = hframes * vframes
	var frames: PackedInt32Array = _get_frames()
	var frame: int = 0
	if not frames.is_empty():
		frame = int(frames[clampi(frame_index, 0, frames.size() - 1)])
	frame = clampi(frame, 0, maxi(total_frames - 1, 0))

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		_draw_center_text("Невозможно прочитать текстуру")
		return

	var frame_size := Vector2(texture_size.x / float(hframes), texture_size.y / float(vframes))
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return

	var column: int = frame % hframes
	var row: int = floori(float(frame) / float(hframes))
	var source := Rect2(Vector2(float(column) * frame_size.x, float(row) * frame_size.y), frame_size)

	# Pixel-perfect preview: только 1x, 2x, 3x... без дробного масштабирования.
	var available: Vector2 = size - Vector2(36.0, 58.0)
	var raw_zoom: float = minf(available.x / frame_size.x, available.y / frame_size.y)
	var pixel_zoom: int = maxi(1, floori(raw_zoom))
	var destination_size: Vector2 = frame_size * float(pixel_zoom)
	var destination_position: Vector2 = ((size - destination_size) * 0.5).floor()
	destination_position.y += 8.0

	draw_texture_rect_region(texture, Rect2(destination_position, destination_size), source)

	var mode_name: String = "Idle" if animation_mode == MODE_IDLE else "Attack"
	_draw_footer("%s · кадр %d · %dx · NEAREST" % [mode_name, frame, pixel_zoom])

func _get_frames() -> PackedInt32Array:
	if build == null:
		return PackedInt32Array()
	var value = build.get("idle_frames") if animation_mode == MODE_IDLE else build.get("attack_frames")
	if value is PackedInt32Array:
		return value
	return PackedInt32Array()

func _get_fps() -> float:
	if build == null:
		return 8.0
	var key: String = "idle_fps" if animation_mode == MODE_IDLE else "attack_fps"
	return maxf(float(build.get(key)), 1.0)

func _draw_background() -> void:
	var bg := Color("#1f2229")
	var checker_a := Color("#242832")
	var checker_b := Color("#292e38")
	var line := Color("#343943")
	if has_theme_color(&"dark_color_2", &"Editor"):
		bg = get_theme_color(&"dark_color_2", &"Editor")
	if has_theme_color(&"dark_color_3", &"Editor"):
		checker_a = get_theme_color(&"dark_color_3", &"Editor")
	if has_theme_color(&"dark_color_1", &"Editor"):
		checker_b = get_theme_color(&"dark_color_1", &"Editor")

	draw_rect(Rect2(Vector2.ZERO, size), bg)
	var cell := 16.0
	var y := 8.0
	var row_index := 0
	while y < size.y - 28.0:
		var x := 8.0
		var col_index := 0
		while x < size.x - 8.0:
			var color: Color = checker_a if ((row_index + col_index) % 2 == 0) else checker_b
			draw_rect(Rect2(Vector2(x, y), Vector2(cell, cell)), color)
			x += cell
			col_index += 1
		y += cell
		row_index += 1
	draw_rect(Rect2(Vector2.ONE * 6.0, size - Vector2.ONE * 12.0), line, false, 1.0)

func _draw_footer(value: String) -> void:
	var font: Font = ThemeDB.fallback_font
	var color := Color("#aeb4c0")
	if has_theme_color(&"font_disabled_color", &"Editor"):
		color = get_theme_color(&"font_disabled_color", &"Editor")
	draw_string(font, Vector2(12.0, size.y - 12.0), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, color)

func _draw_center_text(value: String) -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
	var color := Color("#aeb4c0")
	if has_theme_color(&"font_disabled_color", &"Editor"):
		color = get_theme_color(&"font_disabled_color", &"Editor")
	draw_string(font, Vector2((size.x - width) * 0.5, size.y * 0.5), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, color)

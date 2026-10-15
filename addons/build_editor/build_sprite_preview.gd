@tool
extends Control

var build = null
var frame_index: int = 0
var elapsed: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(300.0, 280.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func set_build(value) -> void:
	build = value
	frame_index = 0
	elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if build == null:
		return
	var idle_frames = build.get("idle_frames")
	if idle_frames == null or idle_frames.is_empty():
		return
	var fps: float = maxf(float(build.get("idle_fps")), 1.0)
	elapsed += delta
	var frame_time: float = 1.0 / fps
	if elapsed < frame_time:
		return
	elapsed = fmod(elapsed, frame_time)
	frame_index = (frame_index + 1) % idle_frames.size()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#17191e"))
	draw_rect(Rect2(Vector2.ONE * 6.0, size - Vector2.ONE * 12.0), Color("#262932"), false, 1.0)

	if build == null:
		_draw_center_text("Выберите билд")
		return

	var texture = build.get("player_sprite_sheet") as Texture2D
	if texture == null:
		_draw_center_text("Выберите sprite sheet")
		return

	var hframes: int = maxi(int(build.get("player_hframes")), 1)
	var vframes: int = maxi(int(build.get("player_vframes")), 1)
	var total_frames: int = hframes * vframes
	var frame: int = 0
	var idle_frames = build.get("idle_frames")
	if idle_frames != null and not idle_frames.is_empty():
		frame = int(idle_frames[clampi(frame_index, 0, idle_frames.size() - 1)])
	frame = clampi(frame, 0, maxi(total_frames - 1, 0))

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		_draw_center_text("Невозможно прочитать текстуру")
		return

	var frame_size: Vector2 = Vector2(texture_size.x / float(hframes), texture_size.y / float(vframes))
	var column: int = frame % hframes
	var row: int = floori(float(frame) / float(hframes))
	var source: Rect2 = Rect2(Vector2(float(column) * frame_size.x, float(row) * frame_size.y), frame_size)

	var available: Vector2 = size - Vector2(32.0, 32.0)
	var fit_scale: float = minf(available.x / frame_size.x, available.y / frame_size.y)
	fit_scale = maxf(fit_scale, 0.01)
	var destination_size: Vector2 = frame_size * fit_scale
	var destination: Rect2 = Rect2((size - destination_size) * 0.5, destination_size)
	draw_texture_rect_region(texture, destination, source)

func _draw_center_text(value: String) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 14
	var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, size.y * 0.5), value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("#aeb4c0"))

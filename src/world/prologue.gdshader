shader_type canvas_item;

// Ссылка на экранный буфер (Nearest сохраняет пиксели четкими)
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// Настройки в инспекторе (Shader Parameters)
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.3; // Сила блика от ламп
uniform float blur_amount : hint_range(0.0, 0.05) = 0.005;     // Размытие вертикальной полосы
uniform float vertical_offset = 0.1;                          // Коррекция высоты отражения

void fragment() {
	// 1. Берем готовый пиксель зеленого пола, который нарисован в TileMap
	vec4 base_color = COLOR;
	
	// Если это пустой прозрачный тайл (воздух), ничего не делаем
	if (base_color.a < 0.01) {
		discard;
	}

	// 2. Рассчитываем зеркальные координаты (смотрим вверх на лампы)
	vec2 uv = SCREEN_UV;
	float dist = UV.y + vertical_offset;
	uv.y += dist * 0.12; 

	// 3. Делаем вертикальное пиксельное размытие отражения ламп
	vec4 blur_sum = vec4(0.0);
	blur_sum += texture(screen_texture, vec2(uv.x, uv.y - blur_amount));
	blur_sum += texture(screen_texture, vec2(uv.x, uv.y));
	blur_sum += texture(screen_texture, vec2(uv.x, uv.y + blur_amount));
	vec4 reflected_color = blur_sum / 3.0;

	// 4. Добавляем отражение ламп ТОЛЬКО на видимые пиксели зеленого пола
	// Режим "max" не затирает текстуру пола, а подсвечивает ее там, где падает свет
	vec3 final_rgb = max(base_color.rgb, reflected_color.rgb * reflection_strength);

	// Записываем результат обратно в пиксель тайла
	COLOR = vec4(final_rgb, base_color.a);
}

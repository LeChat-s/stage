shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float width : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * width;
	vec4 col = texture(TEXTURE, UV);
	
	// Если ширина обводки 0, просто рисуем обычную текстуру
	if (width == 0.0) {
		COLOR = col;
	} else {
		// Проверяем соседние пиксели
		float alpha = col.a;
		alpha += texture(TEXTURE, UV + vec2(0.0, -size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(0.0, size.y)).a;
		alpha += texture(TEXTURE, UV + vec2(-size.x, 0.0)).a;
		alpha += texture(TEXTURE, UV + vec2(size.x, 0.0)).a;
		
		// Если текущий пиксель прозрачный, но рядом есть видимые — красим в цвет обводки
		if (col.a == 0.0 && alpha > 0.0) {
			COLOR = outline_color;
		} else {
			COLOR = col;
		}
	}
}
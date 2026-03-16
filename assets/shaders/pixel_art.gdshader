shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int pixel_scale : hint_range(1, 16) = 3;
uniform int color_count : hint_range(2, 256) = 8;
uniform float dither_spread : hint_range(0.0, 1.0) = 0.5;

float bayer4(ivec2 coord) {
	int x = coord.x % 4;
	int y = coord.y % 4;
	int index = y * 4 + x;
	if (index == 0)  return 0.0;
	if (index == 1)  return 8.0;
	if (index == 2)  return 2.0;
	if (index == 3)  return 10.0;
	if (index == 4)  return 12.0;
	if (index == 5)  return 4.0;
	if (index == 6)  return 14.0;
	if (index == 7)  return 6.0;
	if (index == 8)  return 3.0;
	if (index == 9)  return 11.0;
	if (index == 10) return 1.0;
	if (index == 11) return 9.0;
	if (index == 12) return 15.0;
	if (index == 13) return 7.0;
	if (index == 14) return 13.0;
	return 5.0;
}

void fragment() {
	// Stage 1: Pixelation — snap UVs to pixel_scale grid
	vec2 pixel_size = SCREEN_PIXEL_SIZE * float(pixel_scale);
	vec2 pixelated_uv = floor(SCREEN_UV / pixel_size) * pixel_size;
	vec4 color = texture(screen_texture, pixelated_uv);

	// Stage 2: Ordered dithering — Bayer 4x4 aligned to pixelated grid
	ivec2 pixel_coord = ivec2(FRAGCOORD.xy) / pixel_scale;
	float threshold = (bayer4(pixel_coord) / 16.0 - 0.5) * dither_spread;
	color.rgb += vec3(threshold);

	// Stage 3: Color quantization
	float steps = float(color_count - 1);
	color.rgb = clamp(floor(color.rgb * steps + 0.5) / steps, 0.0, 1.0);

	COLOR = color;
}

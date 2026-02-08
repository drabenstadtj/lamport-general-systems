shader_type spatial;
render_mode unshaded, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform float q_levels = 1.0;
uniform float interpolation_z = 0.0;
uniform float zoom = 1.0;
uniform float o_y = 0.0005;
// 6 cubemap faces
uniform sampler2D tex_posx : filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_negx : filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_posy : filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_negy : filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_posz : filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_negz : filter_nearest_mipmap_anisotropic;

uniform sampler2D tex_posx_z : filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_negx_z : filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_posy_z : filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_negy_z : filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_posz_z : filter_nearest_mipmap_anisotropic;
uniform sampler2D tex_negz_z : filter_nearest_mipmap_anisotropic;

// controls how "smooth" the transition is between cube faces
uniform float blend_sharpness : hint_range(1.0, 256.0) = 8.0;


// Convert a direction vector into UVs for a given face
vec2 cube_uv(vec3 dir, int face) {
	dir = normalize(dir);
	vec2 uv;
	
	if (face == 0) uv = vec2(-dir.z, dir.y) / abs(dir.x);   // +X
	if (face == 1) uv = vec2(dir.z, dir.y) / abs(dir.x);    // -X
	if (face == 2) uv = vec2(dir.x, -dir.z) / abs(dir.y);   // +Y
	if (face == 3) uv = vec2(dir.x, dir.z) / abs(dir.y);    // -Y
	if (face == 4) uv = vec2(dir.x, dir.y) / abs(dir.z);    // +Z
	if (face == 5) uv = vec2(-dir.x, dir.y) / abs(dir.z);   // -Z
	
	uv = vec2(-uv.x, uv.y);
	uv = clamp(uv, -0.999, 0.999);
	
	return uv * 0.5 + 0.5;
}


// Blend all 6 cube faces based on the view direction
vec3 sample_cubemap(vec3 dir) {
	vec3 abs_dir = abs(dir);
	float max_axis = max(max(abs_dir.x, abs_dir.y), abs_dir.z);
	
	// Smooth blending weights
	vec3 weights = pow(abs_dir / max_axis, vec3(blend_sharpness));
	weights /= (weights.x + weights.y + weights.z);
	
	vec3 col_x = mix(
		texture(tex_negx, cube_uv(dir, 1)).rgb,
		texture(tex_posx, cube_uv(dir, 0)).rgb,
		step(0.0, dir.x)
	);
	vec3 col_y = mix(
		texture(tex_negy, cube_uv(dir, 3)).rgb,
		texture(tex_posy, cube_uv(dir, 2)).rgb,
		step(0.0, dir.y)
	);
	vec3 col_z = mix(
		texture(tex_negz, cube_uv(dir, 5)).rgb,
		texture(tex_posz, cube_uv(dir, 4)).rgb,
		step(0.0, dir.z)
	);
	return weights.x * col_x + weights.y * col_y + weights.z * col_z;
}

vec3 sample_cubemap2(vec3 dir) {
	vec3 abs_dir = abs(dir);
	float max_axis = max(max(abs_dir.x, abs_dir.y), abs_dir.z);

	// Smooth blending weights
	vec3 weights = pow(abs_dir / max_axis, vec3(blend_sharpness));
	weights /= (weights.x + weights.y + weights.z);

	// offset half a pixel to create antialiasing
	// but if we do so, we are doubling our final render resolution.
	// out textures are 256x256, a pixel equals 1/256 or 0.004. Half a pixel = 0.002
	// we can add a smaller value to keep the final image very pixelated and
	// still add a bit of antialiasing like 0.0004

	vec3 col_x = mix(
		texture(tex_negx_z, clamp(cube_uv(dir, 1) + vec2(o_y,o_y), 0.001, 0.999)).rgb,
		texture(tex_posx_z, clamp(cube_uv(dir, 0) + vec2(o_y,o_y), 0.001, 0.999)).rgb,
		step(0.0, dir.x)
	);
	vec3 col_y = mix(
		texture(tex_negy_z, clamp(cube_uv(dir, 3) + vec2(o_y,o_y), 0.001, 0.999)).rgb,
		texture(tex_posy_z, clamp(cube_uv(dir, 2) + vec2(o_y,o_y), 0.001, 0.999)).rgb,
		step(0.0, dir.y)
	);
	vec3 col_z = mix(
		texture(tex_negz_z, clamp(cube_uv(dir, 5) + vec2(o_y,o_y), 0.001, 0.999)).rgb,
		texture(tex_posz_z, clamp(cube_uv(dir, 4) + vec2(o_y,o_y), 0.001, 0.999)).rgb,
		step(0.0, dir.z)
	);
	
	return weights.x * col_x + weights.y * col_y + weights.z * col_z;
}
void fragment() {
	// Reconstruct view ray from UV coordinates
	// Convert UV from (0,1) to NDC (-1,1)
	vec2 ndc = UV * 2.0 - 1.0;
	
	// Unproject to get view space direction (z=1.0 = far plane in Godot 4 Vulkan NDC)
	vec4 clip = vec4(ndc, 1.0, 1.0);
	vec4 view_space = INV_PROJECTION_MATRIX * clip;
	vec3 view_dir = view_space.xyz / view_space.w;
	
	// Transform to world space
	vec3 world_view_dir = normalize((INV_VIEW_MATRIX * vec4(view_dir, 0.0)).xyz);
	
	vec3 color = sample_cubemap(world_view_dir);
	vec3 color2 = sample_cubemap2(world_view_dir);
	
	// quantize before mixing, to we have intermediate colors for blending
	color = floor(color * 6.0) / 6.0;
	color2 = floor(color2 * 6.0) / 6.0;
	
	ALBEDO = mix(color, color2, 0.5); // blend to minimize distance flickering
}
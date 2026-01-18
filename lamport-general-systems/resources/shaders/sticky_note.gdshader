shader_type spatial;

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 0.7, 1.0);
uniform sampler2D text_decal : filter_nearest;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.8;
uniform vec2 decal_scale = vec2(1.0, 1.0);

void fragment() {
    // Adjust UVs to maintain aspect ratio (fit to note)
    vec2 adjusted_uv = (UV - 0.5) / decal_scale + 0.5;
    
    // Sample the text decal with adjusted UVs
    vec4 decal = vec4(0.0);
    if (adjusted_uv.x >= 0.0 && adjusted_uv.x <= 1.0 && 
        adjusted_uv.y >= 0.0 && adjusted_uv.y <= 1.0) {
        decal = texture(text_decal, adjusted_uv);
    }
    
    // Blend text over base color
    ALBEDO = mix(base_color.rgb, decal.rgb, decal.a);
    ROUGHNESS = roughness_value;
}
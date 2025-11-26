shader_type canvas_item;

uniform sampler2D u_dither_tex : repeat_enable;  // Enable repeat
uniform int u_color_depth : hint_range(1, 8) = 5;
uniform int u_dither_size = 1;

void fragment() 
{
    // Sample screen with optional pixelation
    vec2 screen_size = vec2(textureSize(TEXTURE, 0)) / float(u_dither_size);
    vec2 screen_sample_uv = floor(UV * screen_size) / screen_size;
    vec3 screen_col = texture(TEXTURE, screen_sample_uv).rgb;
    
    // Get dither pattern - use FRAGCOORD for stable tiling
    ivec2 noise_size = textureSize(u_dither_tex, 0);
    vec2 noise_uv = mod(FRAGCOORD.xy, vec2(noise_size)) / vec2(noise_size);
    float threshold = texture(u_dither_tex, noise_uv).r;
    
    // Adjust threshold range
    threshold = threshold * 0.99 + 0.005;
    
    // Apply dithering to EACH color channel independently
    float levels = pow(2.0, float(u_color_depth));
    vec3 dithered;
    
    for (int i = 0; i < 3; i++) {
        float color_val = screen_col[i];
        float quantized = floor(color_val * levels) / levels;
        float next_val = min(quantized + (1.0 / levels), 1.0);
        
        // Calculate how far between quantized levels
        float error = (color_val - quantized) * levels;
        
        // Use dither pattern to choose between current and next level
        dithered[i] = error > threshold ? next_val : quantized;
    }
    
    COLOR.rgb = dithered;
}
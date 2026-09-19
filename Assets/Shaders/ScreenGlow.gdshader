shader_type canvas_item;

// Grab the screen behind this ColorRect
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// --- CONFIGURATION SETTINGS ---
uniform float blur_amount : hint_range(0.0, 10.0) = 4.5;
uniform float glow_intensity : hint_range(0.0, 10.0) = 0.35;
uniform float threshold : hint_range(0.0, 1.0) = 0.0; // Only glow pixels brighter than this
uniform float soft_edge : hint_range(0.0, 1.0) = 0.0;  // How softly the glow starts
uniform vec4 glow_color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	// 1. Get the original sharp image
	vec4 source = texture(screen_texture, SCREEN_UV);
	
	// 2. Get the blurred "Bloom" layer
	vec4 blurred = texture(screen_texture, SCREEN_UV, blur_amount);
	
	// 3. Calculate Luminance (Brightness) of the blurred pixels
	// These numbers are standard for how human eyes perceive brightness
	float brightness = dot(blurred.rgb, vec3(0.299, 0.587, 0.114));
	
	// 4. Apply the Threshold (The "Cutoff")
	// This makes sure only the bright white logos create a glow
	float glow_mask = smoothstep(threshold, threshold + soft_edge, brightness);
	
	// 5. Combine everything
	vec3 final_glow = blurred.rgb * glow_mask * glow_intensity * glow_color_tint.rgb;
	
	// Screen blend mode logic (Source + Glow)
	COLOR.rgb = source.rgb + final_glow;
	COLOR.a = 1.0;
}

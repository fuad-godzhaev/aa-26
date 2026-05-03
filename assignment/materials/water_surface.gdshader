shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// TODO(placeholder): simple placeholder water shader. Polish pass should bring in Gerstner waves, refraction (SCREEN_TEXTURE sample with normal-offset), foam edges at object intersections, and per-frame UV scrolling for the foam noise. See ARCHITECTURE.md §9.

uniform vec4 deep_color : source_color = vec4(0.10, 0.32, 0.42, 0.65);
uniform vec4 shallow_color : source_color = vec4(0.55, 0.85, 0.92, 0.45);
uniform float wave_speed = 0.6;
uniform float wave_freq = 0.18;
uniform float wave_amp = 0.22;
uniform float foam_scale = 4.0;
uniform float metallic = 0.30;
uniform float roughness = 0.40;

void vertex() {
	float w1 = sin(VERTEX.x * wave_freq + TIME * wave_speed);
	float w2 = cos(VERTEX.z * wave_freq * 0.85 + TIME * wave_speed * 0.7);
	VERTEX.y += (w1 + w2) * wave_amp * 0.5;
	// Cheap finite-difference normal so the waves catch the sunlight.
	float dx = cos(VERTEX.x * wave_freq + TIME * wave_speed) * wave_freq * wave_amp;
	float dz = -sin(VERTEX.z * wave_freq * 0.85 + TIME * wave_speed * 0.7) * wave_freq * 0.85 * wave_amp;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	vec2 uv = UV * foam_scale + vec2(TIME * 0.04, TIME * 0.03);
	float n = sin(uv.x * 3.1) * cos(uv.y * 2.7) + sin(uv.x * 1.7 + uv.y * 1.3) * 0.5;
	float foam_mask = smoothstep(0.6, 1.0, n);
	vec4 col = mix(deep_color, shallow_color, foam_mask);
	ALBEDO = col.rgb;
	ALPHA = col.a;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}

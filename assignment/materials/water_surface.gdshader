shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// TODO(placeholder): placeholder water shader. Polish should bring in Gerstner waves, refraction (SCREEN_TEXTURE with normal offset), edge foam, and proper Snell's-window for the underside. See ARCHITECTURE.md §9.

uniform vec4 deep_color : source_color = vec4(0.10, 0.32, 0.42, 0.95);
uniform vec4 crest_color : source_color = vec4(0.55, 0.82, 0.92, 0.85);
uniform vec4 underside_color : source_color = vec4(0.18, 0.42, 0.50, 0.97);
uniform float wave_speed = 0.6;
uniform float wave_freq = 0.18;
uniform float wave_amp = 0.22;
uniform float metallic = 0.05;
uniform float roughness = 0.45;

void vertex() {
	float w1 = sin(VERTEX.x * wave_freq + TIME * wave_speed);
	float w2 = cos(VERTEX.z * wave_freq * 0.85 + TIME * wave_speed * 0.7);
	VERTEX.y += (w1 + w2) * wave_amp * 0.5;
	// Cheap finite-difference normal so the waves catch the sunlight on crests.
	float dx = cos(VERTEX.x * wave_freq + TIME * wave_speed) * wave_freq * wave_amp;
	float dz = -sin(VERTEX.z * wave_freq * 0.85 + TIME * wave_speed * 0.7) * wave_freq * 0.85 * wave_amp;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	// Above-water (looking down): deep -> crest gradient by wave-normal y.
	// Below-water (looking up): a flatter near-opaque underside so the sun disk and skybox singularity don't punch through the surface.
	float crest = smoothstep(0.985, 1.0, NORMAL.y);
	vec4 above = mix(deep_color, crest_color, crest);
	if (FRONT_FACING) {
		ALBEDO = above.rgb;
		ALPHA = above.a;
	} else {
		ALBEDO = underside_color.rgb;
		ALPHA = underside_color.a;
	}
	METALLIC = metallic;
	ROUGHNESS = roughness;
}

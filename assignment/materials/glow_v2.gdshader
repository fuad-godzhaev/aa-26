shader_type spatial;

// Bioluminescent body shader v2: dark albedo + pulsing emissive + sharper fresnel rim.
// Adds warm belly tint (driven by world-space normal) and HSV saturation boost.
// Successor to glow.gdshader; pulse + rim driven per-frame by Gemini BT state.

uniform vec4 base_color : source_color = vec4(0.04, 0.16, 0.20, 1.0);
uniform vec4 glow_color : source_color = vec4(0.10, 0.85, 0.80, 1.0);
uniform vec4 belly_color : source_color = vec4(0.95, 0.90, 0.75, 1.0);
uniform float pulse_speed = 1.5;
uniform float pulse_strength = 0.55;
uniform float rim_strength = 2.4;
uniform float rim_curve = 3.0;
uniform float emission_energy = 2.2;
uniform float emission_pulse = 1.0;
uniform float saturation = 1.2;

// RGB->HSV helper (Sam Hocevar branchless).
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV->RGB helper.
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	ALBEDO = base_color.rgb;
	METALLIC = 0.2;
	ROUGHNESS = 0.55;

	// Sharper fresnel rim using configurable curve.
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float f = pow(1.0 - ndv, rim_curve) * rim_strength;

	// Pulse term in [1.0 - pulse_strength, 1.0 + pulse_strength] roughly.
	float p = 0.5 + 0.5 * sin(TIME * pulse_speed) * pulse_strength;

	// Convert view-space NORMAL to world space to test belly orientation.
	// INV_VIEW_MATRIX is available in Godot 4 spatial shaders.
	vec3 world_n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float bf = smoothstep(0.0, -0.4, world_n.y);

	// Blend glow tint with warm belly tint where the surface faces downward.
	vec3 tinted = mix(glow_color.rgb, belly_color.rgb, bf);

	// HSV saturation boost on the blended emission tint.
	vec3 hsv = rgb2hsv(tinted);
	hsv.y = clamp(hsv.y * saturation, 0.0, 1.0);
	vec3 emission_color = hsv2rgb(hsv);

	EMISSION = emission_color * f * p * emission_energy * emission_pulse;
}

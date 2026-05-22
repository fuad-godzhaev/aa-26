shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Bioluminescent vein shader: successor to glow_v2.gdshader.
// Adds vertex-color-driven vein emission on a coral/salmon base body.
// Vertices painted bright in the .glb -> glowing vein channels.
// Unpainted vertices (near-black COLOR) -> base body, rim+pulse only.
// Compiles cleanly on Forward+ and Mobile renderers (no screen/depth samplers).

uniform vec4 base_color : source_color = vec4(0.55, 0.30, 0.22, 1.0);
uniform vec4 glow_color : source_color = vec4(0.10, 0.85, 0.90, 1.0);
uniform vec4 belly_color : source_color = vec4(0.95, 0.75, 0.50, 1.0);
uniform float pulse_speed = 1.5;
uniform float pulse_strength = 0.45;
uniform float rim_strength = 2.0;
uniform float rim_curve = 3.0;
uniform float emission_energy = 2.4;
uniform float emission_pulse = 1.0;
uniform float vein_intensity = 4.0;
uniform float vein_threshold = 0.15;
uniform float vein_softness = 0.25;
uniform float saturation = 1.2;
uniform bool veins_enabled = true;

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
	// World-space normal for belly orientation test; same trick as glow_v2.
	vec3 world_n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float bf = smoothstep(0.0, -0.4, world_n.y);

	// Blend body toward warm belly tint where the surface faces downward.
	ALBEDO = mix(base_color.rgb, belly_color.rgb, bf * 0.5);
	METALLIC = 0.15;
	ROUGHNESS = 0.55;

	// Vein mask from per-vertex color luminance; gated by uniform flag.
	float lum = COLOR.r * 0.6 + COLOR.g * 0.3 + COLOR.b * 0.1;
	float v = smoothstep(vein_threshold, vein_threshold + vein_softness, lum);
	if (!veins_enabled) {
		v = 0.0;
	}

	// Pulse term matches glow_v2.
	float p = 0.5 + 0.5 * sin(TIME * pulse_speed) * pulse_strength;

	// Fresnel rim, configurable curve.
	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float f = pow(1.0 - ndv, rim_curve) * rim_strength;

	// HSV saturation boost on glow tint.
	vec3 hsv = rgb2hsv(glow_color.rgb);
	hsv.y = clamp(hsv.y * saturation, 0.0, 1.0);
	vec3 glow_sat = hsv2rgb(hsv);

	// Vein term: strong where painted bright; rim term: soft glow everywhere.
	vec3 vein_em = glow_sat * vein_intensity * v * p * emission_pulse * emission_energy;
	vec3 rim_em = glow_sat * f * 0.3 * emission_pulse;
	EMISSION = vein_em + rim_em;
}

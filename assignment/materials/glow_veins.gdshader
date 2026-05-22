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
uniform float skin_detail = 0.20;
uniform float skin_freq = 14.0;
uniform float skin_roughness_mod = 0.18;
uniform float proc_vein_freq = 5.5;
uniform float proc_vein_lo = 1.10;
uniform float proc_vein_hi = 1.55;
uniform float proc_vein_intensity = 1.4;
uniform float base_metallic = 0.25;
uniform float base_roughness = 0.35;
uniform float iris_threshold = 0.03;
uniform vec4 iris_color : source_color = vec4(0.02, 0.03, 0.05, 1.0);
uniform vec4 iris_emission : source_color = vec4(0.10, 0.85, 0.95, 1.0);
uniform float iris_emission_strength = 0.6;

// 3D value noise helpers for procedural skin variation. Branchless, no textures.
vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
			 dot(p, vec3(269.5, 183.3, 246.1)),
			 dot(p, vec3(113.5, 271.9, 124.6)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = dot(hash3(i + vec3(0,0,0)), f - vec3(0,0,0));
	float n100 = dot(hash3(i + vec3(1,0,0)), f - vec3(1,0,0));
	float n010 = dot(hash3(i + vec3(0,1,0)), f - vec3(0,1,0));
	float n110 = dot(hash3(i + vec3(1,1,0)), f - vec3(1,1,0));
	float n001 = dot(hash3(i + vec3(0,0,1)), f - vec3(0,0,1));
	float n101 = dot(hash3(i + vec3(1,0,1)), f - vec3(1,0,1));
	float n011 = dot(hash3(i + vec3(0,1,1)), f - vec3(0,1,1));
	float n111 = dot(hash3(i + vec3(1,1,1)), f - vec3(1,1,1));
	float nx00 = mix(n000, n100, u.x);
	float nx10 = mix(n010, n110, u.x);
	float nx01 = mix(n001, n101, u.x);
	float nx11 = mix(n011, n111, u.x);
	return mix(mix(nx00, nx10, u.y), mix(nx01, nx11, u.y), u.z);
}

// Ridged FBM for organic branching vein patterns on the body surface.
// Three octaves of inverted-abs noise produce sharp ridges along noise-zero contours,
// which read as capillary-like glowing channels under the bioluminescent emission.
float vein_pattern(vec3 p) {
	float v = 0.0;
	float amp = 1.0;
	float freq = proc_vein_freq;
	for (int i = 0; i < 3; i++) {
		float n = vnoise(p * freq);
		v += amp * (1.0 - abs(n));
		freq *= 2.1;
		amp *= 0.55;
	}
	return v;
}

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

varying vec3 v_local_pos;

void vertex() {
	v_local_pos = VERTEX;
}

void fragment() {
	// World-space normal for belly orientation test; same trick as glow_v2.
	vec3 world_n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float bf = smoothstep(0.0, -0.4, world_n.y);

	// Blend body toward warm belly tint where the surface faces downward.
	ALBEDO = mix(base_color.rgb, belly_color.rgb, bf * 0.5);
	METALLIC = base_metallic;
	ROUGHNESS = base_roughness;

	// Procedural skin variation: value noise on model-local position breaks up the
	// plastic look without geometry or texture cost. Subtle dark patches + roughness modulation.
	float skin_n = vnoise(v_local_pos * skin_freq) * 0.5 + 0.5;
	ALBEDO *= 1.0 - skin_detail * skin_n;
	ROUGHNESS = clamp(ROUGHNESS + (skin_n - 0.5) * skin_roughness_mod, 0.1, 0.95);

	// Vein mask: combine per-vertex paint (deliberate hot-spots like eye-ring, dorsal spine)
	// with procedural ridged noise (organic branching capillaries across the whole body).
	float lum = COLOR.r * 0.6 + COLOR.g * 0.3 + COLOR.b * 0.1;
	float v_paint = smoothstep(vein_threshold, vein_threshold + vein_softness, lum);
	float v_proc = smoothstep(proc_vein_lo, proc_vein_hi, vein_pattern(v_local_pos)) * proc_vein_intensity;
	float v = clamp(max(v_paint, v_proc), 0.0, 1.5);
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

	// Iris pass: mark iris-zone fragments by mesh-local position proximity to the two iris
	// centres in the body-local frame. Robust to vertex-colour gamma encoding which
	// darkens painted values unpredictably across the glTF round-trip.
	vec3 iris_r_centre = vec3(0.42, 0.10, 0.45);
	vec3 iris_l_centre = vec3(-0.42, 0.10, 0.45);
	float dr = distance(v_local_pos, iris_r_centre);
	float dl = distance(v_local_pos, iris_l_centre);
	float d_eye = min(dr, dl);
	// Larger iris radius: out to 0.085m gives a prominent eye disc.
	float iris_mask = 1.0 - smoothstep(0.065, 0.085, d_eye);
	// Inner pupil: a darker dot inside the iris disc.
	float pupil_mask = 1.0 - smoothstep(0.025, 0.040, d_eye);
	if (iris_mask > 0.01) {
		// Mix the iris color over the body, then mix the pupil (pure black) over the iris.
		vec3 iris_albedo = mix(iris_color.rgb, vec3(0.0, 0.0, 0.0), pupil_mask);
		vec3 iris_em = iris_emission.rgb * iris_emission_strength * (0.7 + 0.5 * f);
		iris_em = mix(iris_em, vec3(0.0, 0.0, 0.0), pupil_mask * 0.8);
		ALBEDO = mix(ALBEDO, iris_albedo, iris_mask);
		EMISSION = mix(EMISSION, iris_em, iris_mask);
		ROUGHNESS = mix(ROUGHNESS, 0.15, iris_mask);
		METALLIC = mix(METALLIC, 0.05, iris_mask);
	}
}

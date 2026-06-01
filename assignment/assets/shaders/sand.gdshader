shader_type spatial;

// Tri-planar sand: warm albedo + 2-octave FBM variation, derivative ripple
// normal scrolled by wind_speed, top-facing caustic stripe overlay.

uniform vec4 sand_color : source_color = vec4(0.78, 0.68, 0.52, 1.0);
uniform float dark_variation = 0.15;
uniform float ripple_amount = 0.04;
uniform float ripple_freq = 6.0;
uniform float wind_speed = 0.015;
uniform float caustic_intensity = 0.25;
uniform vec4 caustic_color : source_color = vec4(0.95, 0.97, 0.85, 1.0);
uniform float albedo_scale = 0.35;

// Hash + value noise + 2-octave FBM (self-contained, no texture sampling).
float hash2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm2(vec2 p) {
	float v = 0.0;
	v += 0.6 * vnoise(p);
	v += 0.4 * vnoise(p * 2.13 + vec2(7.7, 3.3));
	return v;
}

// Tri-planar weights from world normal.
vec3 triplanar_weights(vec3 n) {
	vec3 w = abs(normalize(n));
	w = max(w - 0.20, vec3(0.0));
	float s = w.x + w.y + w.z + 1e-5;
	return w / s;
}

// Project world position onto each axis plane and sum FBM by weight.
float triplanar_fbm(vec3 p, vec3 w, float scale) {
	float fx = fbm2(p.yz * scale);
	float fy = fbm2(p.xz * scale);
	float fz = fbm2(p.xy * scale);
	return fx * w.x + fy * w.y + fz * w.z;
}

void fragment() {
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wnorm = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 w = triplanar_weights(wnorm);

	// Albedo variation: large-scale FBM dimming to a darker tone.
	float n_albedo = triplanar_fbm(wpos, w, albedo_scale);
	vec3 base = sand_color.rgb * (1.0 - dark_variation * (1.0 - n_albedo));
	ALBEDO = base;

	// Ripple normal via derivative noise (scrolled by wind).
	float t = TIME * wind_speed;
	float n0 = triplanar_fbm(wpos + vec3(t, 0.0, t), w, ripple_freq);
	float nx = triplanar_fbm(wpos + vec3(0.05 + t, 0.0, t), w, ripple_freq);
	float nz = triplanar_fbm(wpos + vec3(t, 0.0, 0.05 + t), w, ripple_freq);
	vec3 ripple = vec3((nx - n0) / 0.05, 1.0, (nz - n0) / 0.05);
	NORMAL = normalize(mix(NORMAL, normalize(ripple), ripple_amount));

	// Caustic stripe overlay on top-facing surfaces only.
	float top_mask = smoothstep(0.8, 0.95, wnorm.y);
	float caustic = fbm2(wpos.xz * 0.6 + vec2(t * 3.0, t * 1.5));
	caustic = smoothstep(0.55, 0.8, caustic);
	ALBEDO += caustic_color.rgb * caustic * caustic_intensity * top_mask;

	ROUGHNESS = 0.9;
	METALLIC = 0.0;
}

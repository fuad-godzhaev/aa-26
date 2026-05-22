shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Water surface: 3-wave Gerstner displacement + analytic normal.
// Above-water: deep/crest gradient, fresnel-mixed sky-gradient reflection.
// F+ only (enable_refraction = true): screen-space refraction + depth-driven edge foam.
// Mobile (enable_refraction = false): opaque underside, no screen sampling.
// Underside (back-face) stays near-opaque so the sun disk never punches through.

uniform vec4 deep_color : source_color = vec4(0.10, 0.32, 0.42, 0.95);
uniform vec4 crest_color : source_color = vec4(0.55, 0.82, 0.92, 0.85);
uniform vec4 underside_color : source_color = vec4(0.18, 0.42, 0.50, 0.97);
uniform float wave_speed = 0.6;
uniform float metallic = 0.05;
uniform float roughness = 0.45;

// Refraction + foam: only sampled when enable_refraction = true (F+ path).
// Uniforms are always declared so the .tscn shader_parameter list is stable across renderers.
uniform bool enable_refraction = false;
uniform float refract_strength = 0.04;
uniform float foam_threshold = 0.5;
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

// Three Gerstner waves. Direction is in XZ plane (unit length).
// theta = k * dot(dir, pos.xz) - omega * TIME, omega = TAU * speed / wavelength.
// Vertex offset: pos.xz -= Q * amp * dir * cos(theta), pos.y += amp * sin(theta).
const vec2 W1_DIR = vec2(1.0, 0.0);
const float W1_LEN = 4.0;
const float W1_AMP = 0.18;
const float W1_SPD = 1.2;
const float W1_Q = 0.5;

const vec2 W2_DIR = vec2(0.70710677, 0.70710677);
const float W2_LEN = 6.0;
const float W2_AMP = 0.15;
const float W2_SPD = 0.9;
const float W2_Q = 0.4;

const vec2 W3_DIR = vec2(-0.5070201, 0.8619342);
const float W3_LEN = 9.0;
const float W3_AMP = 0.12;
const float W3_SPD = 0.6;
const float W3_Q = 0.35;

// One Gerstner wave: adds its xz/y contribution to the running sum, accumulates analytic dx/dz.
void gerstner_wave(vec2 dir, float wavelength, float amp, float speed, float Q, vec2 xz, float t, inout vec3 offset, inout float dydx, inout float dydz) {
	float k = 6.28318530718 / wavelength;
	float omega = 6.28318530718 * speed / wavelength;
	float theta = k * dot(dir, xz) - omega * t;
	float c = cos(theta);
	float s = sin(theta);
	offset.x -= Q * amp * dir.x * c;
	offset.z -= Q * amp * dir.y * c;
	offset.y += amp * s;
	// Partial derivative of pos.y w.r.t. world xz on the deformed surface.
	// d(amp * sin(theta))/d(xz) = amp * cos(theta) * k * dir.
	dydx += amp * c * k * dir.x;
	dydz += amp * c * k * dir.y;
}

void vertex() {
	vec3 offset = vec3(0.0);
	float dydx = 0.0;
	float dydz = 0.0;
	vec2 xz = VERTEX.xz;
	float t = TIME * wave_speed;
	gerstner_wave(W1_DIR, W1_LEN, W1_AMP, W1_SPD, W1_Q, xz, t, offset, dydx, dydz);
	gerstner_wave(W2_DIR, W2_LEN, W2_AMP, W2_SPD, W2_Q, xz, t, offset, dydx, dydz);
	gerstner_wave(W3_DIR, W3_LEN, W3_AMP, W3_SPD, W3_Q, xz, t, offset, dydx, dydz);
	VERTEX += offset;
	NORMAL = normalize(vec3(-dydx, 1.0, -dydz));
}

// Procedural sky-gradient stand-in for a radiance cube.
// Godot 4.6 spatial shaders do not expose RADIANCE_MAP / sky cubemap to fragment shaders;
// the proper paths (reflection probe, environment) feed through the lighting pipeline, not a direct sample.
// To keep the .tscn shader_parameter list renderer-agnostic and avoid a custom samplerCube uniform,
// we fake the reflection by blending crest_color (near horizon) to a brighter zenith tint.
vec3 fake_sky(vec3 refl_dir) {
	float horizon = clamp(1.0 - abs(refl_dir.y), 0.0, 1.0);
	vec3 zenith = crest_color.rgb * 1.15 + vec3(0.05);
	vec3 ground = deep_color.rgb;
	return mix(zenith, mix(ground, crest_color.rgb, 0.7), horizon);
}

// Reconstruct view-space linear depth in metres from the depth_texture sample at SCREEN_UV.
// Standard Godot 4 unproject: ndc -> view, divide by w.
float linear_view_depth(vec2 screen_uv, mat4 inv_proj) {
	float raw = texture(depth_texture, screen_uv).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw);
	vec4 view = inv_proj * vec4(ndc, 1.0);
	return -(view.xyz / view.w).z;
}

void fragment() {
	float crest = smoothstep(0.985, 1.0, NORMAL.y);
	vec3 above = mix(deep_color.rgb, crest_color.rgb, crest);
	if (FRONT_FACING) {
		// Sky-gradient reflection, fresnel-weighted against the deep/crest base.
		vec3 refl_dir = reflect(-VIEW, NORMAL);
		vec3 sky_col = fake_sky(refl_dir);
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
		fres = mix(0.04, 1.0, fres);
		vec3 base = mix(above, sky_col, fres * 0.6);
		float out_alpha = mix(deep_color.a, crest_color.a, crest);
		if (enable_refraction) {
			// Screen-space refraction: sample warped scene behind the surface.
			vec2 warp = NORMAL.xz * refract_strength;
			vec3 refr_col = texture(screen_texture, SCREEN_UV + warp).rgb;
			// Fresnel: low view-angle -> refract, glancing -> reflect/base.
			base = mix(refr_col, base, fres);
			out_alpha = 1.0;
			// Edge foam: thin water between surface and opaque scene behind it.
			// VERTEX in fragment is already view-space in Godot 4 spatial shaders.
			float scene_z = linear_view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
			float surface_z = -VERTEX.z;
			float depth_diff = max(scene_z - surface_z, 0.0);
			float foam = 1.0 - smoothstep(0.0, foam_threshold, depth_diff);
			base = mix(base, foam_color.rgb, foam * foam_color.a);
		}
		ALBEDO = base;
		ALPHA = out_alpha;
	} else {
		// Underside (back-face): flat near-opaque so the sun + skybox singularity don't bleed through.
		ALBEDO = underside_color.rgb;
		ALPHA = underside_color.a;
	}
	METALLIC = metallic;
	ROUGHNESS = roughness;
}

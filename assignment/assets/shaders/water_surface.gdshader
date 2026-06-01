shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Water surface: 3-wave Gerstner displacement + analytic normal, now with
// uploadable detail maps (albedo / normal / AO / height) from a texture pack.
//
// The real upgrade is the NORMAL map: two scrolling layers blended onto the
// Gerstner slope normal give the fine ripple that big swells lack -> sun
// sparkle, and (because the scene is mostly viewed from BELOW) a shimmering
// underside "ceiling". Empty map slots are neutral, so plug in only what you
// have. For water you mainly want the Normal map; Height is optional fine chop;
// Albedo only if the pack ships a nice water tint; AO barely matters here.
//
// Above-water: deep/crest gradient + fresnel sky reflection.
// F+ (enable_refraction = true): screen-space refraction + depth edge foam.

// --- colour ---
uniform vec4 deep_color : source_color = vec4(0.10, 0.32, 0.42, 0.95);
uniform vec4 crest_color : source_color = vec4(0.55, 0.82, 0.92, 0.85);
uniform vec4 underside_color : source_color = vec4(0.18, 0.42, 0.50, 0.97);
uniform float wave_speed = 0.6;
uniform float metallic = 0.05;
uniform float roughness : hint_range(0.0, 1.0) = 0.12;   // low -> sharp sun sparkle on the ripples

// --- detail maps (upload from a water/texture pack; empty slots = no effect) ---
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float albedo_mix : hint_range(0.0, 1.0) = 0.0;       // 0 = pure colour gradient; raise to tint by texture
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale = 0.30;                           // ripple tiles per metre
uniform float normal_strength : hint_range(0.0, 2.0) = 0.5;  // 0 = analytic Gerstner normal only
uniform float normal_speed = 0.05;                           // ripple scroll speed
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.0;      // AO barely matters on water; off by default
uniform sampler2D height_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float height_amount : hint_range(0.0, 1.0) = 0.0;    // extra fine chop on top of Gerstner; off by default
uniform float tex_scale = 0.30;                              // albedo / AO / height tiles per metre

// --- refraction + foam (F+ path only) ---
uniform bool enable_refraction = false;
uniform float refract_strength = 0.04;
uniform float foam_threshold = 0.5;
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

// Three Gerstner waves. Direction is in XZ plane (unit length).
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

varying vec3 world_pos;
varying vec3 geo_normal_ws;

// One Gerstner wave: adds xz/y contribution to the sum, accumulates analytic dx/dz.
void gerstner_wave(vec2 dir, float wavelength, float amp, float speed, float Q, vec2 xz, float t, inout vec3 offset, inout float dydx, inout float dydz) {
	float k = 6.28318530718 / wavelength;
	float omega = 6.28318530718 * speed / wavelength;
	float theta = k * dot(dir, xz) - omega * t;
	float c = cos(theta);
	float s = sin(theta);
	offset.x -= Q * amp * dir.x * c;
	offset.z -= Q * amp * dir.y * c;
	offset.y += amp * s;
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

	// optional fine chop from a height map (scrolled); empty (black) -> no effect
	if (height_amount > 0.0) {
		vec2 huv = VERTEX.xz * tex_scale + vec2(0.6, 0.25) * t * 0.1;
		float h = textureLod(height_tex, huv, 0.0).r;
		VERTEX.y += h * height_amount;
	}

	vec3 nObj = normalize(vec3(-dydx, 1.0, -dydz));
	NORMAL = nObj;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	geo_normal_ws = normalize((MODEL_MATRIX * vec4(nObj, 0.0)).xyz);
}

// Procedural sky-gradient stand-in for a radiance cube (see original note).
vec3 fake_sky(vec3 refl_dir) {
	float horizon = clamp(1.0 - abs(refl_dir.y), 0.0, 1.0);
	vec3 zenith = crest_color.rgb * 1.15 + vec3(0.05);
	vec3 ground = deep_color.rgb;
	return mix(zenith, mix(ground, crest_color.rgb, 0.7), horizon);
}

float linear_view_depth(vec2 screen_uv, mat4 inv_proj) {
	float raw = texture(depth_texture, screen_uv).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, raw);
	vec4 view = inv_proj * vec4(ndc, 1.0);
	return -(view.xyz / view.w).z;
}

void fragment() {
	// --- fine ripple: dual scrolling normal maps blended onto the Gerstner normal ---
	vec3 nrm_ws = geo_normal_ws;
	if (normal_strength > 0.0) {
		vec2 fl = world_pos.xz;
		vec2 uv1 = fl * normal_scale + vec2(0.8, 0.2) * (TIME * normal_speed);
		vec2 uv2 = fl * normal_scale * 2.1 + vec2(-0.3, 0.7) * (TIME * normal_speed * 0.8);
		vec3 n1 = texture(normal_map, uv1).xyz * 2.0 - 1.0;
		vec3 n2 = texture(normal_map, uv2).xyz * 2.0 - 1.0;
		vec3 nt = normalize(n1 + n2);                 // tangent-space ripple, z = up
		// map the tangent ripple to world XZ slopes and add to the geometric normal
		nrm_ws = normalize(geo_normal_ws + vec3(nt.x, 0.0, nt.y) * normal_strength);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm_ws, 0.0)).xyz);   // view space for lighting + reflection

	// big-wave crest term uses world-up so it's camera-independent
	float crest = smoothstep(0.985, 1.0, geo_normal_ws.y);
	vec3 above = mix(deep_color.rgb, crest_color.rgb, crest);

	vec3 surf;
	float a;
	if (FRONT_FACING) {
		// Sky-gradient reflection, fresnel-weighted against the deep/crest base.
		vec3 refl_dir = reflect(-VIEW, NORMAL);
		vec3 sky_col = fake_sky(refl_dir);
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
		fres = mix(0.04, 1.0, fres);
		surf = mix(above, sky_col, fres * 0.6);
		a = mix(deep_color.a, crest_color.a, crest);
		if (enable_refraction) {
			vec2 warp = NORMAL.xz * refract_strength;
			vec3 refr_col = texture(screen_texture, SCREEN_UV + warp).rgb;
			surf = mix(refr_col, surf, fres);
			a = 1.0;
			float scene_z = linear_view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
			float surface_z = -VERTEX.z;
			float depth_diff = max(scene_z - surface_z, 0.0);
			float foam = 1.0 - smoothstep(0.0, foam_threshold, depth_diff);
			surf = mix(surf, foam_color.rgb, foam * foam_color.a);
		}
	} else {
		// Underside (what you see underwater): near-opaque, but the rippled
		// NORMAL above makes this "ceiling" shimmer under the sun.
		surf = underside_color.rgb;
		a = underside_color.a;
	}

	// --- detail-map tint + AO (empty slots stay neutral) ---
	vec2 tuv = world_pos.xz * tex_scale;
	surf *= mix(vec3(1.0), texture(albedo_tex, tuv).rgb, albedo_mix);
	surf *= mix(1.0, texture(ao_tex, tuv).r, ao_strength);

	ALBEDO = surf;
	ALPHA = a;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}

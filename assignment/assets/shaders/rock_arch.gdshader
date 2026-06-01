// rock_arch.gdshader
// Soft-stylized triplanar rock for Godot 4. Works on ANY mesh with or without
// UVs (arches, the tunnel-hill, boulders) because it projects the texture by
// world position - no unwrapping, no stretching on lumps. Matte, gently banded,
// depth-tinted to match the rest of the scene, with an optional algae tint that
// settles on upward faces.
//
// USE:
//   MeshInstance3D -> Material Override -> New ShaderMaterial -> load this file.
//   Drop rock_albedo.png into 'Rock Albedo', rock_normal.png into 'Rock Normal'.
//   Tune tri_scale (texture size), then depth/algae to taste.

shader_type spatial;
render_mode diffuse_toon, specular_disabled;
#include "res://assignment/assets/shaders/ocean_globals.gdshaderinc"

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float tri_scale = 0.25;                         // texture tiles per metre
uniform float blend_sharpness : hint_range(1.0, 8.0) = 4.0;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.8;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.95;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);  // nudge toward palette

// algae growth on upward faces (set amount to 0 for bare rock)
uniform vec3 algae_color : source_color = vec3(0.50, 0.52, 0.28);
uniform float algae_amount : hint_range(0.0, 1.0) = 0.18;
uniform float algae_scale = 0.6;                            // patch size (smaller value = bigger patches)
uniform float algae_threshold : hint_range(0.0, 1.0) = 0.5; // higher = less coverage / smaller blotches
uniform float algae_softness : hint_range(0.01, 0.5) = 0.2; // edge diffusion (bigger = softer)

// shared underwater depth tint now comes from the Ocean globals (ocean_globals.gdshaderinc)

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri_weights(vec3 n) {
    vec3 w = pow(abs(n), vec3(blend_sharpness));
    return w / (w.x + w.y + w.z);
}

vec3 tri_albedo(vec3 p, vec3 w) {
    vec3 ax = texture(rock_albedo, p.zy * tri_scale).rgb;
    vec3 ay = texture(rock_albedo, p.xz * tri_scale).rgb;
    vec3 az = texture(rock_albedo, p.xy * tri_scale).rgb;
    return ax * w.x + ay * w.y + az * w.z;
}

// whiteout triplanar normal blend -> a world-space normal
vec3 tri_normal(vec3 p, vec3 wn, vec3 w) {
    vec3 tx = texture(rock_normal, p.zy * tri_scale).xyz * 2.0 - 1.0;
    vec3 ty = texture(rock_normal, p.xz * tri_scale).xyz * 2.0 - 1.0;
    vec3 tz = texture(rock_normal, p.xy * tri_scale).xyz * 2.0 - 1.0;
    tx = vec3(tx.xy + wn.zy, abs(tx.z) * wn.x);
    ty = vec3(ty.xy + wn.xz, abs(ty.z) * wn.y);
    tz = vec3(tz.xy + wn.xy, abs(tz.z) * wn.z);
    return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

// value noise for breaking the algae into patches
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec3 wn = normalize(world_normal);
    vec3 w = tri_weights(wn);

    vec3 alb = tri_albedo(world_pos, w) * tint;

    // algae settles on top-facing surfaces, broken into patches by noise
    float up = clamp(wn.y, 0.0, 1.0);
    float n = vnoise(world_pos.xz * algae_scale);
    n = mix(n, vnoise(world_pos.xz * algae_scale * 2.7 + 11.0), 0.4);  // 2nd octave, more organic
    float patch = smoothstep(algae_threshold - algae_softness, algae_threshold + algae_softness, n);
    alb = mix(alb, algae_color, up * up * algae_amount * patch);

    // triplanar normal -> view space for lighting
    vec3 an = tri_normal(world_pos, wn, w);
    an = normalize(mix(wn, an, normal_strength));
    NORMAL = (VIEW_MATRIX * vec4(an, 0.0)).xyz;

    // shared depth tint (Ocean globals)
    float d = ocean_depth_factor(world_pos.y);
    ALBEDO = mix(alb, alb * ocean_deep_tint.rgb, d);
    ROUGHNESS = roughness_val;
}

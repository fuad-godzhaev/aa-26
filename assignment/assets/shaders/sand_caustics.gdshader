// sand_caustics.gdshader
// Stylized underwater sand for Godot 4: world-projected sand texture + animated
// caustic light web + depth tint. The caustics move on their own via TIME - no
// keyframe animation needed; it is all part of this material.
//
// QUICK TEST (any mesh):
//   1. Add a MeshInstance3D (a big PlaneMesh works for a sand floor).
//   2. Material Override -> New ShaderMaterial -> Shader -> load this file.
//   3. Under Shader Params, drop sand_albedo.png into 'Sand Albedo' and
//      sand_normal.png into 'Sand Normal'.
//   4. Tune tex_tiling / caustic_tiling / caustic_strength to taste.
//
// ON TERRAIN3D:
//   Put sand_albedo + sand_normal into a Terrain3D texture layer for the sand.
//   For the caustics, enable the Terrain3DMaterial 'Shader Override', then paste
//   the hash2 / worley / caustics functions and the EMISSION line below into the
//   generated shader's fragment(). (Terrain3D has its own albedo/normal handling,
//   so you only need to graft the caustic part on.)

shader_type spatial;
render_mode diffuse_toon, specular_disabled;   // matte, gently banded -> stylized
#include "res://assignment/assets/shaders/ocean_globals.gdshaderinc"

uniform sampler2D sand_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float tex_tiling = 0.35;                       // texture tiles per metre
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.9;

// underwater depth tint now comes from the shared Ocean globals (ocean_globals.gdshaderinc)

// caustics (the moving light web)
uniform vec3 caustic_color : source_color = vec3(1.0, 0.96, 0.78);
uniform float caustic_tiling = 0.18;                   // web cells per metre
uniform float caustic_speed = 0.25;
uniform float caustic_strength : hint_range(0.0, 2.0) = 0.5;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// distances to the nearest (F1) and second-nearest (F2) animated cell points
vec2 worley(vec2 p, float t) {
    vec2 n = floor(p);
    vec2 f = fract(p);
    float f1 = 8.0;
    float f2 = 8.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash2(n + g);
            o = 0.5 + 0.5 * sin(t + 6.2831 * o);       // drift points over time
            float d = length(g + o - f);
            if (d < f1) { f2 = f1; f1 = d; }
            else if (d < f2) { f2 = d; }
        }
    }
    return vec2(f1, f2);
}

// bright thin web where two cells meet -> looks like refracted light lines
float caustics(vec2 p, float t) {
    vec2 w = worley(p, t);
    float edge = 1.0 - smoothstep(0.0, 0.06, w.y - w.x);
    return pow(edge, 2.0);
}

void fragment() {
    vec2 uv = world_pos.xz * tex_tiling;

    vec3 base = texture(sand_albedo, uv).rgb;
    NORMAL_MAP = texture(sand_normal, uv).rgb;
    NORMAL_MAP_DEPTH = normal_strength;
    ROUGHNESS = roughness_val;

    // depth tint (shared Ocean globals)
    float d = ocean_depth_factor(world_pos.y);
    ALBEDO = mix(base, base * ocean_deep_tint.rgb, d);

    // caustics: additive light, only on upward-facing surfaces, easing with depth
    float up = clamp(world_normal.y, 0.0, 1.0);
    float ca = caustics(world_pos.xz * caustic_tiling, TIME * caustic_speed);
    EMISSION = caustic_color * ca * caustic_strength * up * (1.0 - 0.5 * d);
}

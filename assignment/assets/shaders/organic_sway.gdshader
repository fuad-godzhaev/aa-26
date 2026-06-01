// organic_sway.gdshader
// Kelp, seaweed, and SOFT corals: double-sided thin geometry that sways with the
// current and glows softly when backlit (translucency).
//
// Surface controls now mirror the rock shader: a full UV albedo + tint + normal
// map drive the look, so you get the same freedom/variety. The old base->tip
// colour gradient is still here but is now OPTIONAL — leave gradient_amount at 0
// to rely purely on the texture (like the rock shader), or raise it to darken the
// roots / lift the tips.
//
// Stays UV-based (not triplanar) because blades are thin and already UV-mapped;
// triplanar only makes sense on chunky rock. Assumes local origin at the base,
// +Y up the blade. No emission — only Gemini glows.

shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;
#include "res://assignment/assets/shaders/ocean_globals.gdshaderinc"

// --- surface (like the rock shader) ---
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap, repeat_enable;  // empty = no occlusion
uniform float ao_strength : hint_range(0.0, 1.0) = 1.0;
uniform float normal_depth : hint_range(0.0, 2.0) = 0.0;     // 0 if no normal map; raise when you add one
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);      // overall colour multiplier
uniform float uv_scale = 1.0;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.85;

// --- optional base->tip gradient (set amount to 0 to rely purely on the texture) ---
uniform float gradient_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 base_color : source_color = vec3(0.55, 0.65, 0.50);  // multiplier at the roots
uniform vec3 tip_color  : source_color = vec3(1.0, 1.0, 1.0);     // multiplier at the tips
uniform float plant_height = 2.0;          // metres, base -> tip (local Y); also drives sway

// --- current sway ---
uniform float sway_amount = 0.15;          // metres of tip drift
uniform float sway_speed = 1.2;
uniform vec3  current_dir = vec3(1.0, 0.0, 0.3);

// --- translucency (light through thin tips) ---
uniform vec3  translucency : source_color = vec3(0.30, 0.50, 0.25);
uniform float translucency_amount : hint_range(0.0, 1.0) = 1.0;

// --- shared depth tint: now from the Ocean globals (ocean_globals.gdshaderinc) ---

varying float blade_t;     // 0 at base, 1 at tip
varying vec3  world_pos;

void vertex() {
    blade_t = clamp(VERTEX.y / plant_height, 0.0, 1.0);
    vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float phase = wp.x * 0.5 + wp.z * 0.5;             // each plant sways differently
    float s = sin(TIME * sway_speed + phase) * sway_amount * blade_t * blade_t;
    VERTEX += normalize(current_dir) * s;              // more drift toward the tip
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 uv = UV * uv_scale;
    vec3 col = texture(albedo_tex, uv).rgb * tint;

    // optional base->tip gradient as a multiplier over the texture
    vec3 grad = mix(base_color, tip_color, blade_t);
    col = mix(col, col * grad, gradient_amount);

    // ambient occlusion baked into albedo
    col *= mix(1.0, texture(ao_tex, uv).r, ao_strength);

    NORMAL_MAP = texture(normal_tex, uv).rgb;
    NORMAL_MAP_DEPTH = normal_depth;                    // ignored when 0

    float d = ocean_depth_factor(world_pos.y);
    ALBEDO = mix(col, col * ocean_deep_tint.rgb, d);
    ROUGHNESS = roughness_val;
    BACKLIGHT = translucency * translucency_amount * (0.4 + 0.6 * blade_t);
}

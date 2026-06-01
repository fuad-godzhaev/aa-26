// stylized_fish.gdshader
// Background Earth fish: soft-toon, their own natural colours, no emission, a wet
// sheen via a lighting-based rim, and an optional gentle swim wobble.
//
// The wobble assumes the fish's forward axis is local +Z and it bends along X.
// Leave swim_amount = 0 for a static fish (e.g. if you drive motion by animation
// or steering instead - which is the better route for anything important).

shader_type spatial;
render_mode diffuse_toon, specular_toon;
#include "res://assignment/assets/shaders/ocean_globals.gdshaderinc"

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
// Use the model's own vertex-painted colours (the .glb's original look). Leave on
// and keep tint white for an authentic fish; turn off (or set tint) to recolour a
// duplicate of the same species.
uniform bool  use_vertex_color = true;
uniform vec3  tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.4;   // slight sheen
uniform float rim_strength : hint_range(0.0, 1.0) = 0.3;

uniform float swim_amount = 0.0;      // sideways bend, metres (0 = static)
uniform float swim_speed = 3.0;
uniform float body_length = 1.0;      // fish length along local +Z

// shared depth tint now from the Ocean globals (ocean_globals.gdshaderinc)

varying vec3 world_pos;

void vertex() {
    float along = clamp(VERTEX.z / max(body_length, 0.001), 0.0, 1.0);
    VERTEX.x += sin(TIME * swim_speed + along * 6.2831) * swim_amount * along;
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 tex = texture(albedo_tex, UV).rgb;
    // Original colour = texture x vertex paint; tint multiplies on top (white = no-op).
    vec3 col = (use_vertex_color ? tex * COLOR.rgb : tex) * tint;
    float d = ocean_depth_factor(world_pos.y);
    ALBEDO = mix(col, col * ocean_deep_tint.rgb, d);
    ROUGHNESS = roughness_val;
    RIM = rim_strength;
    RIM_TINT = 0.5;
}

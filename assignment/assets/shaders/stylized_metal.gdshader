// stylized_metal.gdshader
// Metal / painted-metal props: anchor (dark steel), buoy (bright paint), etc.
// Soft metallic with a banded specular and a lighting-based rim (NOT emission, so
// it respects "only Gemini glows"), plus rust/algae creeping onto upward faces.
//
// Anchor:  base_color dark, metallic ~0.85, roughness ~0.5, rust_amount ~0.3
// Buoy:    base_color a bright paint colour, metallic ~0.1, roughness ~0.4

shader_type spatial;
render_mode diffuse_toon, specular_toon;
#include "res://assignment/assets/shaders/ocean_globals.gdshaderinc"

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3  base_color : source_color = vec3(0.35, 0.37, 0.40);
uniform float metallic_val : hint_range(0.0, 1.0) = 0.8;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.5;
uniform float uv_scale = 1.0;

uniform float rim_strength : hint_range(0.0, 1.0) = 0.5;   // wet edge highlight

uniform vec3  rust_color : source_color = vec3(0.45, 0.26, 0.16);
uniform float rust_amount : hint_range(0.0, 1.0) = 0.25;

// shared depth tint now from the Ocean globals (ocean_globals.gdshaderinc)

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec3 col = texture(albedo_tex, UV * uv_scale).rgb * base_color;
    float up = clamp(world_normal.y, 0.0, 1.0);
    float rust = up * up * rust_amount;
    col = mix(col, rust_color, rust);                 // rust gathers on top faces

    float d = ocean_depth_factor(world_pos.y);
    ALBEDO = mix(col, col * ocean_deep_tint.rgb, d);
    METALLIC = metallic_val * (1.0 - rust);           // rust isn't metallic
    ROUGHNESS = mix(roughness_val, 0.9, rust);        // rust is rougher
    RIM = rim_strength;
    RIM_TINT = 0.4;
}

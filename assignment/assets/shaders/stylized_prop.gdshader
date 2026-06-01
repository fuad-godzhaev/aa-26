// stylized_prop.gdshader
// Generic matte stylized surface for authored props: wood treasure chest, planks,
// crates, etc. UV-based (these are modelled objects with UVs). Soft-toon, matte,
// depth-tinted to match the scene.

shader_type spatial;
render_mode diffuse_toon, specular_disabled;
#include "res://assignment/assets/shaders/ocean_globals.gdshaderinc"

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_depth : hint_range(0.0, 2.0) = 0.0;   // 0 if you have no normal map; raise when you assign one
uniform vec3  tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.8;
uniform float uv_scale = 1.0;

// shared depth tint now from the Ocean globals (ocean_globals.gdshaderinc)

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 uv = UV * uv_scale;
    vec3 col = texture(albedo_tex, uv).rgb * tint;
    NORMAL_MAP = texture(normal_tex, uv).rgb;
    NORMAL_MAP_DEPTH = normal_depth;                 // ignored when 0
    float d = ocean_depth_factor(world_pos.y);
    ALBEDO = mix(col, col * ocean_deep_tint.rgb, d);
    ROUGHNESS = roughness_val;
}

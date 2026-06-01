// Shared ocean shader globals + helpers.
// #include this in any shader that needs the world constants, e.g.:
//     #include "res://assignment/assets/shaders/ocean_globals.gdshaderinc"
// (put it right after the shader_type line).
//
// The VALUES come from the Ocean autoload (ocean.gd) at runtime. The NAMES are
// also declared in Project Settings > Shader Globals so the editor recognises them.

global uniform float ocean_surface_y;
global uniform float ocean_seabed_y;
global uniform float ocean_tint_start;
global uniform float ocean_tint_end;
global uniform vec4 ocean_water_tint;
global uniform vec4 ocean_deep_tint;
global uniform vec4 ocean_caustic_tint;

// 0 at the top of the tint band, 1 once fully cooled at depth. Pass world-space Y.
float ocean_depth_factor(float world_y) {
	return clamp((ocean_tint_start - world_y) / max(ocean_tint_start - ocean_tint_end, 0.001), 0.0, 1.0);
}

// Cool an albedo toward the deep tint based on world-space Y.
vec3 ocean_apply_depth_tint(vec3 albedo, float world_y) {
	return mix(albedo, albedo * ocean_deep_tint.rgb, ocean_depth_factor(world_y));
}

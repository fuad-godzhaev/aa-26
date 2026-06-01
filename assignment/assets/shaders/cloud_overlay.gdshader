shader_type spatial;
// Cumulus overlay rendered on the interior of an inverted hemisphere dome.
// cull_front so the camera at scene origin sees the dome's inside surface.
// unshaded + depth_test_disabled keeps clouds visually on top of the skybox without writing depth.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_front;

// Tileable 2D noise sampled by spherical UV from world-space view direction.
uniform sampler2D cloud_noise : hint_default_white, filter_linear, repeat_enable;

// Warm cream cumulus top; darker underside for soft self-shadow.
uniform vec4 cloud_color : source_color = vec4(0.95, 0.88, 0.78, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.55, 0.48, 0.42, 1.0);

// Fraction of sky filled (0 = clear, 1 = solid overcast). 0.4 = scattered cumulus.
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.4;

// Smoothstep width around the coverage threshold; controls edge softness.
uniform float cloud_softness : hint_range(0.001, 0.5) = 0.15;

// Horizontal drift speed in spherical-UV units per second.
uniform float wind_speed : hint_range(0.0, 0.1) = 0.008;

// Clouds fade in above this normalised elevation (view_dir.y in [-1, 1]).
uniform float min_elevation : hint_range(-1.0, 1.0) = 0.15;
uniform float elevation_softness : hint_range(0.001, 1.0) = 0.2;

// Tiling multiplier on the spherical UV; higher = smaller, more numerous clumps.
uniform float noise_scale : hint_range(0.1, 10.0) = 2.0;

void fragment() {
	// NORMAL is interpolated in view space and points inward on an inverted dome.
	// The world-space direction from the camera to this fragment is -NORMAL transformed by INV_VIEW_MATRIX.
	vec3 view_dir = normalize((INV_VIEW_MATRIX * vec4(-NORMAL, 0.0)).xyz);

	// Spherical projection: longitude from atan(x, z), latitude from asin(y).
	vec2 sph_uv = vec2(
		atan(view_dir.x, view_dir.z) / TAU + 0.5,
		asin(clamp(view_dir.y, -1.0, 1.0)) / PI + 0.5
	);

	// Slow horizontal drift to suggest wind without obvious motion.
	sph_uv.x += TIME * wind_speed;

	// Tile noise across the dome.
	sph_uv *= noise_scale;

	// Single noise tap; cumulus shape comes from the smoothstep threshold below.
	float n = texture(cloud_noise, sph_uv).r;

	// Coverage band: only the top fraction of noise values become cloud.
	float c = smoothstep(1.0 - cloud_coverage - cloud_softness, 1.0 - cloud_coverage + cloud_softness, n);

	// Elevation mask: zero below min_elevation, fades to one as we look up.
	// Looking straight down (view_dir.y << 0) -> e = 0 -> fully transparent so the seabed sky doesn't show clouds.
	float e = smoothstep(min_elevation - elevation_softness, min_elevation + elevation_softness, view_dir.y);

	ALPHA = c * e;

	// Self-shadow: brighter near zenith, darker near horizon for cumulus volume.
	ALBEDO = mix(cloud_shadow.rgb, cloud_color.rgb, clamp(view_dir.y * 1.5, 0.0, 1.0));
}

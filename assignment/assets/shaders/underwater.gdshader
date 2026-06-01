shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;

// Underwater screen-space effect — the "being submerged" look.
// Put this on a QuadMesh (Size = 2 x 2) whose MeshInstance3D has a large
// Extra Cull Margin so it never frustum-culls. The vertex shader forces the
// quad fullscreen, so its world position doesn't matter. underwater_effect.gd
// shows it only when the camera is below the surface and feeds `depth_amount`
// (0 at the surface, 1 at the seabed) so the murk/tint deepen as you descend.
//
// It reads the rendered frame + scene depth, then:
//   - fades distant geometry into the water colour (the murk / underwater fog),
//   - wobbles the screen sample (refraction shimmer),
//   - shifts colour bluer (red absorption),
//   - darkens the edges (vignette).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

// Match water_color to your WorldEnvironment fog (#1A739E).
uniform vec3 water_color : source_color = vec3(0.10, 0.45, 0.62);   // distance murk colour
uniform vec3 deep_color : source_color = vec3(0.03, 0.22, 0.38);    // blended in near the seabed
uniform float murk_distance : hint_range(2.0, 80.0) = 22.0;         // metres until fully murked
uniform float murk_strength : hint_range(0.0, 1.0) = 0.7;           // lower this if you also use env fog

uniform float tint_strength : hint_range(0.0, 1.0) = 0.25;          // blue shift on near objects

uniform float distortion_amount : hint_range(0.0, 0.02) = 0.005;    // refraction wobble
uniform float distortion_scale = 7.0;
uniform float distortion_speed = 0.6;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
uniform float vignette_radius : hint_range(0.1, 1.0) = 0.75;

uniform float depth_amount : hint_range(0.0, 1.0) = 0.0;            // set per-frame by the script

void vertex() {
	// Fullscreen: QuadMesh Size = 2 x 2 puts VERTEX in -1..1.
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
	vec4 view = inv_proj * vec4(ndc, 1.0);
	return -(view.xyz / view.w).z;
}

void fragment() {
	// refraction shimmer: wobble the screen sample
	float t = TIME * distortion_speed;
	vec2 wob = vec2(
		sin(SCREEN_UV.y * distortion_scale + t),
		cos(SCREEN_UV.x * distortion_scale + t * 1.3)
	) * distortion_amount;
	vec2 uv = SCREEN_UV + wob;

	vec3 col = texture(screen_tex, uv).rgb;

	// distance murk: fade scene toward the water colour by depth (exp fog).
	// Sky/background sits at far depth, so it murks out too — no sky underwater.
	float depth = linear_depth(uv, INV_PROJECTION_MATRIX);
	float fog = 1.0 - exp(-depth / murk_distance);
	fog *= murk_strength * (0.55 + 0.45 * depth_amount);   // thicker the deeper you are
	vec3 murk = mix(water_color, deep_color, depth_amount);
	col = mix(col, murk, clamp(fog, 0.0, 1.0));

	// red absorption: near objects shift bluer, more so with depth
	vec3 absorb = vec3(0.62, 0.93, 1.05);
	col *= mix(vec3(1.0), absorb, tint_strength * (0.4 + 0.6 * depth_amount));

	// vignette — the enclosed feeling
	float v = length(SCREEN_UV - 0.5);
	float vig = smoothstep(vignette_radius, vignette_radius * 0.4, v);
	col *= mix(1.0, vig, vignette_strength);

	ALBEDO = col;
}

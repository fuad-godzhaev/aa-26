shader_type canvas_item;

// Underwater screen post-process — the "being submerged" feel.
// Put this on a ColorRect anchored to Full Rect, under a CanvasLayer. A ColorRect
// IS the screen, so this is immune to camera movement and rotation: no quad, no
// mesh size, no cull margin, no transforms.
//
// Distance murk is handled by your WorldEnvironment fog, so this needs no scene
// depth. It only adds: a blue shift (red absorption), a gentle refraction wobble,
// and a soft vignette. underwater_effect.gd shows it only below the surface and
// feeds `depth_amount` (0 at the surface, 1 at the -27 m seabed) so it deepens
// as you descend.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float tint_strength : hint_range(0.0, 1.0) = 0.22;       // blue shift amount
uniform float distortion_amount : hint_range(0.0, 0.02) = 0.004; // refraction wobble (keep subtle)
uniform float distortion_scale = 7.0;
uniform float distortion_speed = 0.6;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_radius : hint_range(0.4, 1.4) = 1.0;      // larger = subtler edge darkening
uniform float depth_amount : hint_range(0.0, 1.0) = 0.0;         // set per-frame by the script

void fragment() {
	// refraction shimmer
	float t = TIME * distortion_speed;
	vec2 wob = vec2(
		sin(SCREEN_UV.y * distortion_scale + t),
		cos(SCREEN_UV.x * distortion_scale + t * 1.3)
	) * distortion_amount;
	vec3 col = texture(screen_tex, SCREEN_UV + wob).rgb;

	// red absorption -> bluer, stronger the deeper you are
	vec3 absorb = vec3(0.6, 0.92, 1.05);
	col *= mix(vec3(1.0), absorb, tint_strength * (0.4 + 0.6 * depth_amount));

	// soft vignette (gentle — not a porthole)
	float v = length(SCREEN_UV - 0.5);
	float vig = smoothstep(vignette_radius, vignette_radius * 0.45, v);
	col *= mix(1.0, vig, vignette_strength * (0.6 + 0.4 * depth_amount));

	COLOR = vec4(col, 1.0);
}

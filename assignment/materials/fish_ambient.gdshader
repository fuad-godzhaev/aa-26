shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_opaque;

// Shared ambient-fish surface. Albedo comes from vertex paint, so the same shader fits all 6 species and only the .glb's painted colours differ. Adds a subtle sine body-bend along local +Y (head=-Y, tail=+Y) so each fish wiggles gently. Per-instance bend_phase_offset lets the spawner desync neighbours.

uniform float bend_amplitude = 0.06;
uniform float bend_freq = 4.0;
uniform float bend_speed = 3.0;
uniform float bend_phase_offset = 0.0;
uniform float fresnel_strength = 0.4;
uniform float roughness : hint_range(0.0, 1.0) = 0.45;
uniform float metallic : hint_range(0.0, 1.0) = 0.15;

void vertex() {
	// Body bend: lateral (local X) displacement scaled by tail-distance, head stays anchored.
	float t = clamp((VERTEX.y + 0.1) / 0.3, 0.0, 1.0);
	float phase = TIME * bend_speed + bend_phase_offset;
	VERTEX.x += sin(VERTEX.y * bend_freq + phase) * bend_amplitude * t;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	// Subtle fresnel rim so silhouettes pop in the murky reef ambient light.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = COLOR.rgb * rim * fresnel_strength;
}

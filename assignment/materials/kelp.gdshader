shader_type spatial;
render_mode cull_disabled;

// Procedural kelp: vertices sway more toward the tip; each stalk is phase
// -offset by its world position so a forest does not move in lockstep.

uniform vec4 kelp_color : source_color = vec4(0.04, 0.22, 0.12, 1.0);
uniform float sway_speed = 1.0;
uniform float sway_amount = 0.28;

void vertex() {
	float h = max(VERTEX.y, 0.0);
	float phase = TIME * sway_speed + MODEL_MATRIX[3].x + MODEL_MATRIX[3].z;
	VERTEX.x += sin(phase) * sway_amount * h;
	VERTEX.z += cos(phase * 0.7) * sway_amount * 0.5 * h;
}

void fragment() {
	ALBEDO = kelp_color.rgb;
	ROUGHNESS = 0.85;
}

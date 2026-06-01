shader_type spatial;

// Fin / membrane shader: gentle vertex sway along local +X, dim emissive tint.
// Designed so base (z=0) stays anchored and the tip (z=fin_length) sways most.

uniform float sway_speed = 2.0;
uniform float sway_amount = 0.05;
uniform float sway_freq = 1.8;
uniform float fin_length = 0.5;
uniform vec4 tint : source_color = vec4(0.10, 0.85, 0.80, 1.0);
uniform float emission_energy = 1.2;

void vertex() {
	// Anchor base at z=0, amplify sway toward the tip along +Z.
	float t = VERTEX.z / fin_length;
	VERTEX.x += sin(TIME * sway_speed + VERTEX.z * sway_freq) * sway_amount * t;
}

void fragment() {
	ALBEDO = tint.rgb * 0.3;
	METALLIC = 0.1;
	ROUGHNESS = 0.6;
	EMISSION = tint.rgb * emission_energy;
}

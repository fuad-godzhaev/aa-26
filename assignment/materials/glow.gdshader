shader_type spatial;

// Bioluminescent body shader: dark albedo + pulsing emissive + fresnel rim.
// pulse_speed / pulse_strength are driven per-frame by Gemini's wariness.

uniform vec4 base_color : source_color = vec4(0.04, 0.16, 0.20, 1.0);
uniform vec4 glow_color : source_color = vec4(0.10, 0.85, 0.80, 1.0);
uniform float pulse_speed = 1.5;
uniform float pulse_strength = 0.5;
uniform float rim_strength = 1.6;
uniform float emission_energy = 2.2;

void fragment() {
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.55;

	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);

	vec3 e = glow_color.rgb * emission_energy * (pulse_strength + pulse * pulse_strength);
	e += glow_color.rgb * fresnel * rim_strength;
	EMISSION = e;
}

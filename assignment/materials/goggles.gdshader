shader_type canvas_item;

// Diver-mask vignette: two soft-edged oval lens cutouts on an opaque mask. See ARCHITECTURE.md §5d.

uniform float aspect : hint_range(0.5, 3.0) = 1.7777;
uniform float lens_offset : hint_range(0.0, 0.8) = 0.32;
uniform vec2  lens_size = vec2(0.56, 0.66);
uniform float feather : hint_range(0.0, 0.2) = 0.06;
uniform vec4  mask_color : source_color = vec4(0.012, 0.018, 0.022, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= aspect;

	vec2 d_l = (uv - vec2(-lens_offset, 0.0)) / lens_size;
	vec2 d_r = (uv - vec2( lens_offset, 0.0)) / lens_size;
	float dist_l = length(d_l);
	float dist_r = length(d_r);

	float v_l = 1.0 - smoothstep(1.0 - feather, 1.0 + feather, dist_l);
	float v_r = 1.0 - smoothstep(1.0 - feather, 1.0 + feather, dist_r);
	float visibility = max(v_l, v_r);

	COLOR = vec4(mask_color.rgb, mask_color.a * (1.0 - visibility));
}

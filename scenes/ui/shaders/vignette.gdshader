shader_type canvas_item;

// Radial vignette that slowly "breathes" so the framing never feels static.

uniform vec4 edge_color : source_color = vec4(0.02, 0.02, 0.04, 1.0);
uniform float inner = 0.30;
uniform float outer = 0.98;
uniform float strength = 0.92;
uniform float breathe = 0.025;
uniform vec2 center = vec2(0.5, 0.46);

void fragment() {
	float b = sin(TIME * 0.55) * breathe;
	float d = distance(UV, center);
	float a = smoothstep(inner + b, outer, d) * strength;
	COLOR = vec4(edge_color.rgb, a);
}

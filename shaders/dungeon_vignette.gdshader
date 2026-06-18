shader_type canvas_item;

// Radial darkening drawn over the 3D dungeon view to frame it and to swallow the
// hard far edge of the fog. `strength` is driven from code by the current light
// state (deeper in darkness), so the world literally closes in when the torch
// gutters out.

uniform vec4 edge_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float inner : hint_range(0.0, 1.5) = 0.45;
uniform float outer : hint_range(0.0, 2.0) = 1.18;
uniform float strength : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 d = UV - vec2(0.5);
	// 0 at centre, ~1 at the corners.
	float r = length(d) * 1.41421356;
	float v = smoothstep(inner, outer, r) * strength;
	COLOR = vec4(edge_color.rgb, v);
}

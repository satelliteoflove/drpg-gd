shader_type canvas_item;
render_mode blend_add;

// Soft radial halo that pools around a torch flame, flickering in sync and
// tinting blue-violet during arcane flickers. Additive -> reads as bloom.

uniform vec3 glow_color : source_color = vec3(1.0, 0.55, 0.22);
uniform vec3 arcane_color : source_color = vec3(0.34, 0.28, 1.0);
uniform float intensity = 0.65;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

// Synced with torch_flame: brief blue lick near each slow-sine crest.
float arcane(float t) {
	return smoothstep(0.74, 0.995, sin(t * 1.05));
}

void fragment() {
	vec2 d = (UV - vec2(0.5, 0.44)) * vec2(1.0, 1.15);
	float g = smoothstep(0.5, 0.0, length(d));
	float t = TIME * 1.8;
	float flick = 0.80 + 0.20 * (sin(t * 4.0) * 0.5 + 0.5)
		+ 0.12 * (hash(vec2(floor(t * 9.0), 1.0)) - 0.5);
	float arc = arcane(t);
	vec3 col = mix(glow_color, arcane_color, arc);
	float a = g * intensity * flick * (1.0 - 0.25 * arc);
	COLOR = vec4(col * a, a);
}

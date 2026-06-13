shader_type canvas_item;

// Lights a flat stone texture with two flickering torches so a static wall
// feels candle-lit and alive. All animation is driven by TIME (GPU-side).

uniform vec3 ambient : source_color = vec3(0.15, 0.15, 0.21);
uniform vec3 torch_color : source_color = vec3(1.0, 0.62, 0.30);
uniform float torch_strength = 1.25;
uniform float exposure = 0.9;
uniform float radius = 0.58;

float hash(float n) { return fract(sin(n) * 43758.5453); }

// Smooth, organic flicker: layered sines + a little stepped hash jitter.
float flicker(float t, float seed) {
	float f = 0.5 * sin(t * 6.5 + seed)
		+ 0.3 * sin(t * 12.7 + seed * 2.0)
		+ 0.2 * sin(t * 23.3 + seed * 4.0);
	float h = hash(floor(t * 16.0) + seed);
	return clamp(0.82 + 0.16 * f + 0.07 * (h - 0.5), 0.4, 1.3);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 tA = vec2(0.20, 0.28);
	vec2 tB = vec2(0.80, 0.28);
	float poolA = smoothstep(radius, 0.0, distance(UV, tA)) * flicker(TIME, 1.7);
	float poolB = smoothstep(radius, 0.0, distance(UV, tB)) * flicker(TIME, 4.3);
	float pool = max(poolA, poolB);
	vec3 light = ambient + torch_color * pool * torch_strength;
	COLOR = vec4(tex.rgb * light * exposure, tex.a);
}

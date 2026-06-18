shader_type canvas_item;

// Slow drifting volumetric fog/mist from layered procedural value noise.
// Denser toward the floor. Subtle by design.

uniform vec3 fog_color : source_color = vec3(0.40, 0.42, 0.55);
uniform float fog_strength = 0.11;
uniform float speed = 0.06;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i).x;
	float b = hash2(i + vec2(1.0, 0.0)).x;
	float c = hash2(i + vec2(0.0, 1.0)).x;
	float d = hash2(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * vec2(3.0, 2.0);
	float t = TIME * speed;
	float n = fbm(uv + vec2(t, t * 0.4));
	n *= fbm(uv * 1.7 - vec2(t * 0.7, t * 0.25));
	float a = smoothstep(0.12, 0.7, n) * fog_strength;
	a *= mix(1.5, 0.35, UV.y); // thicker at the bottom
	COLOR = vec4(fog_color, a);
}

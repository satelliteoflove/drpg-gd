shader_type canvas_item;
render_mode blend_add;

// A dancing teardrop torch flame from scrolling turbulent noise. Warm orange,
// with brief blue-violet "arcane" flickers licking through the fire.

uniform vec3 col_core : source_color = vec3(1.0, 0.97, 0.80);
uniform vec3 col_mid : source_color = vec3(1.0, 0.58, 0.18);
uniform vec3 col_edge : source_color = vec3(0.85, 0.18, 0.04);
uniform vec3 col_arcane : source_color = vec3(0.34, 0.28, 1.0);
uniform float brightness = 1.5;
uniform float speed = 1.8;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.02 + vec2(13.7, 5.1);
		a *= 0.5;
	}
	return v;
}

// A brief blue lick near each crest of a slow sine (~1 every ~3.3s),
// reaching full arcane at the peak. Reliable and deterministic.
float arcane(float t) {
	return smoothstep(0.74, 0.995, sin(t * 1.05));
}

void fragment() {
	vec2 uv = UV;
	float h = 1.0 - uv.y;        // 0 at base, 1 at tip
	float cx = uv.x - 0.5;
	float t = TIME * speed;

	vec2 q = vec2(uv.x * 3.0, uv.y * 3.5 - t);
	float warp = fbm(q * 0.7);
	float n = fbm(q + vec2(warp * 0.8, warp * 1.2));

	// Teardrop: rounded base tapering to a point, centerline swaying.
	float width = mix(0.42, 0.05, pow(h, 0.85));
	float sway = (fbm(vec2(uv.y * 1.5 - t * 0.6, 3.0)) - 0.5) * 0.12 * h;
	float core = smoothstep(width, width * 0.1, abs(cx - sway));

	// Vertical envelope; noise lets tongues lick higher.
	float lick = (n - 0.5) * 0.7;
	float env = smoothstep(1.05, 0.15, h + lick) * smoothstep(0.0, 0.10, h);
	float flame = clamp(core * env * smoothstep(0.18, 0.8, n * 0.55 + core * 0.7), 0.0, 1.0);

	if (flame < 0.004) {
		COLOR = vec4(0.0);
	} else {
		float heat = clamp(flame * 1.3 - h * 0.35, 0.0, 1.0);
		vec3 col = mix(col_edge, col_mid, smoothstep(0.15, 0.5, heat));
		col = mix(col, col_core, smoothstep(0.62, 0.95, heat));
		float arc = arcane(t) * smoothstep(0.2, 0.85, flame);
		col = mix(col, col_arcane, arc);
		// Dim during the arcane flicker so additive stacking doesn't blow to white.
		float b = brightness * (1.0 - 0.35 * arc);
		COLOR = vec4(col * b, flame);
	}
}

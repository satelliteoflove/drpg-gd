shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D texture_albedo : hint_default_transparent, filter_linear_mipmap;
uniform float distance_fade_start = 4.0;
uniform float distance_fade_end = 8.0;
uniform float pulse_speed = 3.0;

varying float vertex_distance;

void vertex() {
	vertex_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec4 tex_color = texture(texture_albedo, UV);

	float fade_factor = clamp((vertex_distance - distance_fade_start) / (distance_fade_end - distance_fade_start), 0.0, 1.0);

	vec3 silhouette_color = vec3(0.2, 0.2, 0.25);
	float pulse = 0.6 + 0.4 * sin(TIME * pulse_speed);

	vec3 final_color = mix(tex_color.rgb, silhouette_color * pulse, fade_factor);

	ALBEDO = final_color;
	ALPHA = tex_color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

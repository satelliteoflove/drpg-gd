shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 silhouette_color : source_color = vec4(0.1, 0.1, 0.15, 1.0);
uniform float silhouette_strength : hint_range(0.0, 1.0) = 1.0;
uniform float distance_fade_start = 3.0;
uniform float distance_fade_end = 6.0;

varying float vertex_distance;

void vertex() {
	vertex_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);

	float fade_factor = clamp((vertex_distance - distance_fade_start) / (distance_fade_end - distance_fade_start), 0.0, 1.0);
	float silhouette_factor = fade_factor * silhouette_strength;

	vec3 final_color = mix(tex_color.rgb, silhouette_color.rgb, silhouette_factor);

	ALBEDO = final_color;
	ALPHA = tex_color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

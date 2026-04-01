shader_type canvas_item;

uniform int frame_count = 37;
uniform int columns = 7;
uniform int rows = 6;
uniform float fps = 12.0;

void fragment() {
	int frame = int(floor(mod(TIME * fps, float(frame_count))));
	int col = frame % columns;
	int row = frame / columns;
	float cell_w = 1.0 / float(columns);
	float cell_h = 1.0 / float(rows);
	vec2 uv = vec2(
		float(col) * cell_w + UV.x * cell_w,
		float(row) * cell_h + UV.y * cell_h
	);
	COLOR = texture(TEXTURE, uv);
}

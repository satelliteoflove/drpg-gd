extends Control

signal closed

const TILE_SIZE: int = 12
const WALL_THICKNESS: int = 2
const LEGEND_WIDTH: int = 150

const COLOR_FLOOR := Color(0.2, 0.2, 0.25)
const COLOR_WALL := Color(0.6, 0.55, 0.4)
const COLOR_DOOR := Color(0.5, 0.35, 0.15)
const COLOR_STAIRS_UP := Color(0.2, 0.6, 0.2)
const COLOR_STAIRS_DOWN := Color(0.6, 0.2, 0.2)
const COLOR_PLAYER := Color(1.0, 1.0, 0.0)
const COLOR_UNDISCOVERED := Color(0.05, 0.05, 0.05)
const COLOR_BACKGROUND := Color(0.0, 0.0, 0.0, 0.85)
const COLOR_LEGEND_BG := Color(0.1, 0.1, 0.1, 0.9)
const COLOR_TEXT := Color(0.8, 0.8, 0.8)

var dungeon_data: DungeonData = null
var player_position: Vector2i = Vector2i.ZERO
var player_facing: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	if dungeon_data == null:
		return

	var screen_size := get_viewport_rect().size
	var map_area_width := screen_size.x - LEGEND_WIDTH

	draw_rect(Rect2(Vector2.ZERO, screen_size), COLOR_BACKGROUND)

	var map_width_tiles := dungeon_data.width
	var map_height_tiles := dungeon_data.height
	var map_pixel_width := map_width_tiles * TILE_SIZE
	var map_pixel_height := map_height_tiles * TILE_SIZE

	var offset_x := (map_area_width - map_pixel_width) / 2.0
	var offset_y := (screen_size.y - map_pixel_height) / 2.0

	for y in range(dungeon_data.height):
		for x in range(dungeon_data.width):
			var tile: DungeonTile = dungeon_data.get_tile(x, y)
			if tile == null:
				continue

			var tile_pos := Vector2(offset_x + x * TILE_SIZE, offset_y + y * TILE_SIZE)
			var tile_rect := Rect2(tile_pos, Vector2(TILE_SIZE, TILE_SIZE))

			if not tile.discovered:
				draw_rect(tile_rect, COLOR_UNDISCOVERED)
				continue

			if not tile.is_walkable():
				draw_rect(tile_rect, COLOR_UNDISCOVERED)
				continue

			var floor_color := COLOR_FLOOR
			match tile.special:
				DungeonTile.SpecialType.STAIRS_UP:
					floor_color = COLOR_STAIRS_UP
				DungeonTile.SpecialType.STAIRS_DOWN:
					floor_color = COLOR_STAIRS_DOWN

			draw_rect(tile_rect, floor_color)

			_draw_walls(tile, tile_pos)

	_draw_player(offset_x, offset_y)
	_draw_legend(screen_size)


func _draw_walls(tile: DungeonTile, tile_pos: Vector2) -> void:
	if tile.north_wall != DungeonTile.WallType.NONE:
		var wall_color := _get_wall_color(tile.north_wall)
		var wall_rect := Rect2(tile_pos, Vector2(TILE_SIZE, WALL_THICKNESS))
		draw_rect(wall_rect, wall_color)

	if tile.south_wall != DungeonTile.WallType.NONE:
		var wall_color := _get_wall_color(tile.south_wall)
		var wall_rect := Rect2(
			tile_pos + Vector2(0, TILE_SIZE - WALL_THICKNESS),
			Vector2(TILE_SIZE, WALL_THICKNESS)
		)
		draw_rect(wall_rect, wall_color)

	if tile.west_wall != DungeonTile.WallType.NONE:
		var wall_color := _get_wall_color(tile.west_wall)
		var wall_rect := Rect2(tile_pos, Vector2(WALL_THICKNESS, TILE_SIZE))
		draw_rect(wall_rect, wall_color)

	if tile.east_wall != DungeonTile.WallType.NONE:
		var wall_color := _get_wall_color(tile.east_wall)
		var wall_rect := Rect2(
			tile_pos + Vector2(TILE_SIZE - WALL_THICKNESS, 0),
			Vector2(WALL_THICKNESS, TILE_SIZE)
		)
		draw_rect(wall_rect, wall_color)


func _get_wall_color(wall_type: DungeonTile.WallType) -> Color:
	match wall_type:
		DungeonTile.WallType.DOOR:
			return COLOR_DOOR
		_:
			return COLOR_WALL


func _draw_player(offset_x: float, offset_y: float) -> void:
	var center := Vector2(
		offset_x + player_position.x * TILE_SIZE + TILE_SIZE / 2.0,
		offset_y + player_position.y * TILE_SIZE + TILE_SIZE / 2.0
	)

	var triangle_size := TILE_SIZE * 0.35
	var points: PackedVector2Array = []

	match player_facing:
		0:
			points.append(center + Vector2(0, -triangle_size))
			points.append(center + Vector2(-triangle_size, triangle_size))
			points.append(center + Vector2(triangle_size, triangle_size))
		1:
			points.append(center + Vector2(triangle_size, 0))
			points.append(center + Vector2(-triangle_size, -triangle_size))
			points.append(center + Vector2(-triangle_size, triangle_size))
		2:
			points.append(center + Vector2(0, triangle_size))
			points.append(center + Vector2(triangle_size, -triangle_size))
			points.append(center + Vector2(-triangle_size, -triangle_size))
		3:
			points.append(center + Vector2(-triangle_size, 0))
			points.append(center + Vector2(triangle_size, -triangle_size))
			points.append(center + Vector2(triangle_size, triangle_size))

	draw_polygon(points, PackedColorArray([COLOR_PLAYER]))


func _draw_legend(screen_size: Vector2) -> void:
	var legend_x := screen_size.x - LEGEND_WIDTH
	var legend_rect := Rect2(legend_x, 0, LEGEND_WIDTH, screen_size.y)
	draw_rect(legend_rect, COLOR_LEGEND_BG)

	var font := ThemeDB.fallback_font
	var font_size := 14
	var line_height := 24
	var padding := 10
	var y_pos := 30

	draw_string(font, Vector2(legend_x + padding, y_pos), "MAP LEGEND", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_TEXT)
	y_pos += line_height + 10

	var items := [
		{"color": COLOR_FLOOR, "label": "Floor"},
		{"color": COLOR_WALL, "label": "Wall"},
		{"color": COLOR_DOOR, "label": "Door"},
		{"color": COLOR_STAIRS_UP, "label": "Stairs Up"},
		{"color": COLOR_STAIRS_DOWN, "label": "Stairs Down"},
		{"color": COLOR_PLAYER, "label": "You"},
	]

	for item in items:
		draw_rect(Rect2(legend_x + padding, y_pos - 10, 12, 12), item.color)
		draw_string(font, Vector2(legend_x + padding + 20, y_pos), item.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_TEXT)
		y_pos += line_height

	y_pos = int(screen_size.y) - 40
	draw_string(font, Vector2(legend_x + padding, y_pos), "N/Esc: Close", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_TEXT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map") or event.is_action_pressed("menu_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func update_map(data: DungeonData, pos: Vector2i, facing: int) -> void:
	dungeon_data = data
	player_position = pos
	player_facing = facing
	queue_redraw()

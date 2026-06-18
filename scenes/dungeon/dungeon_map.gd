extends Control

signal closed

const TILE_SIZE: int = 12
const WALL_THICKNESS: int = 2
const LEGEND_WIDTH: int = 210

const COLOR_FLOOR := Color(0.2, 0.2, 0.25)
const COLOR_WALL := Color(0.6, 0.55, 0.4)
const COLOR_DOOR := Color(0.5, 0.35, 0.15)
const COLOR_DOOR_OPEN := Color(0.5, 0.35, 0.15, 0.4)
const COLOR_DOOR_LOCKED := Color(0.7, 0.15, 0.15)
const COLOR_STAIRS_UP := Color(0.2, 0.6, 0.2)
const COLOR_STAIRS_DOWN := Color(0.6, 0.2, 0.2)
const COLOR_PLAYER := Color(1.0, 1.0, 0.0)
const COLOR_UNDISCOVERED := Color(0.05, 0.05, 0.05)
const COLOR_BACKGROUND := Color(0.04, 0.035, 0.06, 0.93)
const COLOR_LEGEND_BG := Color(0.14, 0.13, 0.17, 0.96)
const COLOR_TEXT := Color(0.88, 0.86, 0.82)
const COLOR_TITLE := Color(0.87, 0.74, 0.47)
const COLOR_ENEMY_LOS := Color(0.9, 0.2, 0.2)
const COLOR_ENEMY_SPOTTED := Color(0.7, 0.4, 0.4)
const COLOR_ENEMY_REVEALED := Color(0.5, 0.3, 0.3, 0.7)
const COLOR_ZONE_CLEARED := Color(0.2, 0.4, 0.2, 0.3)
const COLOR_ZONE_SAFE := Color(0.2, 0.6, 0.2, 0.25)
const COLOR_ZONE_NORMAL := Color(0.4, 0.4, 0.5, 0.25)
const COLOR_ZONE_LOW := Color(0.3, 0.5, 0.6, 0.25)
const COLOR_ZONE_HIGH := Color(0.6, 0.4, 0.2, 0.25)
const COLOR_ZONE_BOSS := Color(0.7, 0.2, 0.3, 0.25)

const COLOR_LEGEND_ZONE_SAFE := Color(0.2, 0.3, 0.22)
const COLOR_LEGEND_ZONE_NORMAL := Color(0.25, 0.25, 0.31)
const COLOR_LEGEND_ZONE_LOW := Color(0.23, 0.28, 0.34)
const COLOR_LEGEND_ZONE_HIGH := Color(0.3, 0.25, 0.2)
const COLOR_LEGEND_ZONE_BOSS := Color(0.33, 0.2, 0.24)

var dungeon_data: DungeonData = null
var player_position: Vector2i = Vector2i.ZERO
var player_facing: int = 0
var enemy_data: Dictionary = {}
var show_zones: bool = false
var reveal_button: Button = null
var show_enemies_button: Button = null
var show_zones_button: Button = null
var close_button: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_create_map_buttons()


func _create_map_buttons() -> void:
	reveal_button = _create_styled_button("[R] Reveal Map")
	reveal_button.pressed.connect(_on_reveal_pressed)

	show_enemies_button = _create_styled_button("[E] Show Enemies")
	show_enemies_button.pressed.connect(_on_show_enemies_pressed)

	show_zones_button = _create_styled_button("[Z] Show Zones")
	show_zones_button.pressed.connect(_on_show_zones_pressed)

	close_button = _create_styled_button("[N] Close Map")
	close_button.pressed.connect(_on_close_pressed)

	_update_enemy_button_text()
	_update_zones_button_text()


# Buttons inherit the central Arcane-Tome theme; only sizing is set here.
func _create_styled_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(LEGEND_WIDTH - 24, 34)
	btn.clip_text = true
	btn.focus_mode = Control.FOCUS_NONE
	add_child(btn)
	return btn


func _on_close_pressed() -> void:
	closed.emit()


func _on_reveal_pressed() -> void:
	if dungeon_data == null:
		return
	for y in range(dungeon_data.height):
		for x in range(dungeon_data.width):
			var tile := dungeon_data.get_tile(x, y)
			if tile != null:
				tile.discovered = true
	queue_redraw()


func _on_show_enemies_pressed() -> void:
	if GameState.floor_tracker == null:
		return
	GameState.floor_tracker.toggle_debug_reveal()
	_update_enemy_button_text()
	queue_redraw()


func _update_enemy_button_text() -> void:
	if show_enemies_button == null:
		return
	if GameState.floor_tracker != null and GameState.floor_tracker.is_revealed():
		show_enemies_button.text = "[E] Hide Enemies"
	else:
		show_enemies_button.text = "[E] Show Enemies"


func _on_show_zones_pressed() -> void:
	show_zones = not show_zones
	_update_zones_button_text()
	queue_redraw()


func _update_zones_button_text() -> void:
	if show_zones_button == null:
		return
	if show_zones:
		show_zones_button.text = "[Z] Hide Zones"
	else:
		show_zones_button.text = "[Z] Show Zones"


func _draw() -> void:
	if dungeon_data == null:
		return

	var screen_size := get_viewport_rect().size
	var map_area_width := screen_size.x - LEGEND_WIDTH

	draw_rect(Rect2(Vector2.ZERO, screen_size), COLOR_BACKGROUND)
	_draw_title(map_area_width)

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

	_draw_zone_overlays(offset_x, offset_y)
	_draw_enemies(offset_x, offset_y)
	_draw_player(offset_x, offset_y)
	_draw_legend(screen_size)


func _draw_title(map_area_width: float) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var title := "FLOOR %d" % GameState.current_floor
	var fsize := 26
	var dims := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var pos := Vector2(map_area_width * 0.5 - dims.x * 0.5, 38)
	draw_string(font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, COLOR_TITLE)


func _draw_walls(tile: DungeonTile, tile_pos: Vector2) -> void:
	if tile.north_wall != DungeonTile.WallType.NONE:
		var wall_color := _get_wall_color(tile, "north")
		var wall_rect := Rect2(tile_pos, Vector2(TILE_SIZE, WALL_THICKNESS))
		draw_rect(wall_rect, wall_color)

	if tile.south_wall != DungeonTile.WallType.NONE:
		var wall_color := _get_wall_color(tile, "south")
		var wall_rect := Rect2(
			tile_pos + Vector2(0, TILE_SIZE - WALL_THICKNESS),
			Vector2(TILE_SIZE, WALL_THICKNESS)
		)
		draw_rect(wall_rect, wall_color)

	if tile.west_wall != DungeonTile.WallType.NONE:
		var wall_color := _get_wall_color(tile, "west")
		var wall_rect := Rect2(tile_pos, Vector2(WALL_THICKNESS, TILE_SIZE))
		draw_rect(wall_rect, wall_color)

	if tile.east_wall != DungeonTile.WallType.NONE:
		var wall_color := _get_wall_color(tile, "east")
		var wall_rect := Rect2(
			tile_pos + Vector2(TILE_SIZE - WALL_THICKNESS, 0),
			Vector2(WALL_THICKNESS, TILE_SIZE)
		)
		draw_rect(wall_rect, wall_color)


func _get_wall_color(tile: DungeonTile, direction: String) -> Color:
	var wall_type := tile.get_wall_type(direction)
	if wall_type == DungeonTile.WallType.DOOR:
		if tile.is_door_locked(direction):
			return COLOR_DOOR_LOCKED
		if tile.is_door_open(direction):
			return COLOR_DOOR_OPEN
		return COLOR_DOOR
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
	draw_line(Vector2(legend_x, 0), Vector2(legend_x, screen_size.y), UIColors.TITLE_GOLD_DIM, 1.0)

	var font := get_theme_default_font()
	var font_size := 14
	var line_height := 24
	var padding := 12
	var y_pos := 32

	draw_string(font, Vector2(legend_x + padding, y_pos), "MAP LEGEND", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_TITLE)
	y_pos += line_height + 10

	var items := [
		{"color": COLOR_FLOOR, "label": "Floor"},
		{"color": COLOR_WALL, "label": "Wall"},
		{"color": COLOR_DOOR, "label": "Door (Closed)"},
		{"color": COLOR_DOOR_OPEN, "label": "Door (Open)"},
		{"color": COLOR_DOOR_LOCKED, "label": "Door (Locked)"},
		{"color": COLOR_STAIRS_UP, "label": "Stairs Up"},
		{"color": COLOR_STAIRS_DOWN, "label": "Stairs Down"},
		{"color": COLOR_PLAYER, "label": "You"},
		{"color": COLOR_ENEMY_LOS, "label": "Enemy (Visible)"},
		{"color": COLOR_ENEMY_SPOTTED, "label": "Enemy (Tracked)"},
		{"color": COLOR_LEGEND_ZONE_SAFE, "label": "Zone: Safe"},
		{"color": COLOR_LEGEND_ZONE_LOW, "label": "Zone: Low"},
		{"color": COLOR_LEGEND_ZONE_NORMAL, "label": "Zone: Normal"},
		{"color": COLOR_LEGEND_ZONE_HIGH, "label": "Zone: High"},
		{"color": COLOR_LEGEND_ZONE_BOSS, "label": "Zone: Boss"},
	]

	for item in items:
		draw_rect(Rect2(legend_x + padding, y_pos - 10, 12, 12), item.color)
		draw_string(font, Vector2(legend_x + padding + 20, y_pos), item.label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_TEXT)
		y_pos += line_height

	var button_spacing := 40
	var bottom_y := int(screen_size.y) - padding - 36

	if close_button:
		close_button.position = Vector2(legend_x + padding, bottom_y)
	if show_zones_button:
		show_zones_button.position = Vector2(legend_x + padding, bottom_y - button_spacing)
	if show_enemies_button:
		show_enemies_button.position = Vector2(legend_x + padding, bottom_y - button_spacing * 2)
	if reveal_button:
		reveal_button.position = Vector2(legend_x + padding, bottom_y - button_spacing * 3)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_map") or event.is_action_pressed("menu_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R or event.unicode == 114 or event.unicode == 82:
			_on_reveal_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E or event.unicode == 101 or event.unicode == 69:
			_on_show_enemies_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z or event.unicode == 122 or event.unicode == 90:
			_on_show_zones_pressed()
			get_viewport().set_input_as_handled()


func update_map(data: DungeonData, pos: Vector2i, facing: int, p_enemy_data: Dictionary = {}) -> void:
	dungeon_data = data
	player_position = pos
	player_facing = facing
	enemy_data = p_enemy_data
	queue_redraw()


func _draw_zone_overlays(offset_x: float, offset_y: float) -> void:
	if dungeon_data == null:
		return

	var cleared_zones: Array = enemy_data.get("cleared_zones", [])

	for zone in dungeon_data.zones:
		var is_cleared := zone.id in cleared_zones
		var should_draw := is_cleared or show_zones

		if not should_draw:
			continue

		var zone_color: Color
		if is_cleared:
			zone_color = COLOR_ZONE_CLEARED
		else:
			zone_color = _get_zone_color(zone.zone_type)

		for pos in zone.tile_positions:
			var tile := dungeon_data.get_tile(pos.x, pos.y)
			if tile == null or not tile.discovered:
				continue

			var tile_pos := Vector2(offset_x + pos.x * TILE_SIZE, offset_y + pos.y * TILE_SIZE)
			var tile_rect := Rect2(tile_pos, Vector2(TILE_SIZE, TILE_SIZE))
			draw_rect(tile_rect, zone_color)


func _get_zone_color(zone_type: EncounterZone.ZoneType) -> Color:
	match zone_type:
		EncounterZone.ZoneType.SAFE:
			return COLOR_ZONE_SAFE
		EncounterZone.ZoneType.LOW_SPAWN:
			return COLOR_ZONE_LOW
		EncounterZone.ZoneType.HIGH_SPAWN:
			return COLOR_ZONE_HIGH
		EncounterZone.ZoneType.BOSS:
			return COLOR_ZONE_BOSS
		_:
			return COLOR_ZONE_NORMAL


func _draw_enemies(offset_x: float, offset_y: float) -> void:
	var groups: Array = enemy_data.get("groups", [])
	var is_revealed := GameState.floor_tracker != null and GameState.floor_tracker.is_revealed()

	for group_data in groups:
		var pos: Vector2i = group_data.get("position", Vector2i.ZERO)
		var is_spotted: bool = group_data.get("spotted", false)

		var has_los := _check_los_to_position(pos)
		var should_draw := has_los or is_spotted or is_revealed
		if not should_draw:
			continue

		var tile_pos := Vector2(offset_x + pos.x * TILE_SIZE, offset_y + pos.y * TILE_SIZE)
		var center := tile_pos + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
		var radius := TILE_SIZE * 0.35

		var color: Color
		if has_los:
			color = COLOR_ENEMY_LOS
		elif is_spotted:
			color = COLOR_ENEMY_SPOTTED
		else:
			color = COLOR_ENEMY_REVEALED

		if has_los or is_revealed:
			draw_circle(center, radius, color)
		else:
			_draw_circle_outline(center, radius, color)


func _draw_circle_outline(center: Vector2, radius: float, color: Color) -> void:
	var points := 12
	for i in range(points):
		var angle1 := float(i) / points * TAU
		var angle2 := float(i + 1) / points * TAU
		var p1 := center + Vector2(cos(angle1), sin(angle1)) * radius
		var p2 := center + Vector2(cos(angle2), sin(angle2)) * radius
		draw_line(p1, p2, color, 2.0)


func _check_los_to_position(target: Vector2i) -> bool:
	if dungeon_data == null:
		return false

	var los := LOSCalculator.new()
	return los.has_line_of_sight(dungeon_data, player_position, target)

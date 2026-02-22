extends Node3D

const PartyMenuScene = preload("res://scenes/common/party_menu.tscn")
const DungeonMapScene = preload("res://scenes/dungeon/dungeon_map.tscn")
const CombatScene = preload("res://scenes/combat/combat.tscn")
const EnemySpriteScene = preload("res://scenes/dungeon/enemy_sprite_3d.tscn")
var menu_open: bool = false
var map_open: bool = false
var combat_open: bool = false
var party_menu: Control = null
var dungeon_map: Control = null
var combat_ui: Control = null
var _simulation_logging_enabled: bool = false

const CELL_SIZE: float = 2.0
const CAMERA_HEIGHT: float = 1.6
const WALL_HEIGHT: float = 2.5
const CEILING_Y: float = 2.5

const TORCH_BASE_ENERGY: float = 1.0
const TORCH_FLICKER_INTENSITY: float = 0.08
const TORCH_FLICKER_SPEED: float = 8.0

const MOVE_DURATION: float = 0.30
const TURN_DURATION: float = 0.24

enum Facing { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }

enum FloorMeshItem { FLOOR = 0, STAIRS_UP = 1, STAIRS_DOWN = 2 }
enum CeilingMeshItem { CEILING = 0 }
enum WallMeshItem { WALL = 0, DOOR_CLOSED = 1 }

var grid_position: Vector2i = Vector2i.ZERO
var previous_grid_position: Vector2i = Vector2i.ZERO
var facing: Facing = Facing.NORTH
var dungeon_data: DungeonData = null
var is_moving: bool = false
var move_tween: Tween = null
var enemy_manager: EnemyManager = null
var enemy_sprites: Dictionary = {}
var _enemy_container: Node3D = null

@onready var floor_grid: GridMap = $FloorGridMap
@onready var ceiling_grid: GridMap = $CeilingGridMap
@onready var north_wall_grid: GridMap = $NorthWallGridMap
@onready var south_wall_grid: GridMap = $SouthWallGridMap
@onready var east_wall_grid: GridMap = $EastWallGridMap
@onready var west_wall_grid: GridMap = $WestWallGridMap
@onready var camera: Camera3D = $Camera3D
@onready var player_light: OmniLight3D = $Camera3D/PlayerLight
@onready var floor_label: Label = $UI/TopBar/FloorLabel

var _flicker_time: float = 0.0
var _message_label: Label = null
var _informed_locked_pos: Vector2i = Vector2i(-1, -1)
var _informed_locked_dir: String = ""
var _message_tween: Tween = null

var _floor_material: StandardMaterial3D = null
var _wall_material: StandardMaterial3D = null
var _ceiling_material: StandardMaterial3D = null
var _debug_material_index: int = 0

@onready var menu_overlay: CanvasLayer = $MenuOverlay
@onready var map_overlay: CanvasLayer = $MapOverlay
@onready var combat_overlay: CanvasLayer = $CombatOverlay


func _ready() -> void:
	Engine.max_fps = 30

	_setup_grid_maps()
	_load_or_generate_dungeon()
	_render_dungeon()
	_spawn_player()
	_initialize_enemy_system()
	_update_ui()

	_setup_message_label()
	$UI/BottomBar/TownButton.pressed.connect(_on_town_pressed)
	$UI/BottomBar/MenuButton.pressed.connect(_on_menu_pressed)


func _process(delta: float) -> void:
	_flicker_time += delta * TORCH_FLICKER_SPEED
	var flicker := sin(_flicker_time) * 0.5 + sin(_flicker_time * 2.3) * 0.3 + sin(_flicker_time * 4.1) * 0.2
	player_light.light_energy = TORCH_BASE_ENERGY + flicker * TORCH_FLICKER_INTENSITY


func _create_material_from_texture(diffuse_path: String, normal_path: String, uv_scale: Vector3, tint: Color = Color.WHITE, normal_strength: float = 1.0, roughness_path: String = "", roughness_value: float = 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()

	var diffuse_texture := load(diffuse_path) as Texture2D
	if diffuse_texture:
		material.albedo_texture = diffuse_texture

	if tint != Color.WHITE:
		material.albedo_color = tint

	var normal_texture := load(normal_path) as Texture2D
	if normal_texture:
		material.normal_enabled = true
		material.normal_texture = normal_texture
		material.normal_scale = normal_strength

	if roughness_path != "":
		var roughness_texture := load(roughness_path) as Texture2D
		if roughness_texture:
			material.roughness_texture = roughness_texture
			material.roughness = 1.0
	else:
		material.roughness = roughness_value

	material.uv1_scale = uv_scale
	material.uv1_triplanar = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	return material


func _setup_grid_maps() -> void:
	var floor_material := _create_material_from_texture(
		"res://textures/stone_brick_wall/diffuse.jpg",
		"res://textures/stone_brick_wall/normal.jpg",
		Vector3(0.5, 0.5, 0.5),
		Color.WHITE,
		0.6,
		"",
		0.85
	)

	var stairs_up_material := _create_material_from_texture(
		"res://textures/stone_brick_wall/diffuse.jpg",
		"res://textures/stone_brick_wall/normal.jpg",
		Vector3(0.5, 0.5, 0.5),
		Color(0.7, 0.9, 0.7),
		0.8,
		"",
		0.85
	)

	var stairs_down_material := _create_material_from_texture(
		"res://textures/stone_brick_wall/diffuse.jpg",
		"res://textures/stone_brick_wall/normal.jpg",
		Vector3(0.5, 0.5, 0.5),
		Color(0.9, 0.7, 0.7),
		0.8,
		"",
		0.85
	)

	var ceiling_material := _create_material_from_texture(
		"res://textures/stone_brick_wall/diffuse.jpg",
		"res://textures/stone_brick_wall/normal.jpg",
		Vector3(0.5, 0.5, 0.5),
		Color(0.6, 0.6, 0.65),
		0.7,
		"",
		0.9
	)

	var wall_material := _create_material_from_texture(
		"res://textures/stone_brick_wall/diffuse.jpg",
		"res://textures/stone_brick_wall/normal.jpg",
		Vector3(0.5, 0.5, 0.5),
		Color.WHITE,
		0.8,
		"",
		0.85
	)

	var door_material := _create_material_from_texture(
		"res://textures/door/diffuse.png",
		"res://textures/door/normal.png",
		Vector3(1.0, 1.0, 1.0),
		Color.WHITE,
		0.8,
		"",
		0.85
	)

	_floor_material = floor_material
	_wall_material = wall_material
	_ceiling_material = ceiling_material

	floor_grid.mesh_library = _create_floor_library(floor_material, stairs_up_material, stairs_down_material)
	floor_grid.cell_size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)

	ceiling_grid.mesh_library = _create_ceiling_library(ceiling_material)
	ceiling_grid.cell_size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)

	north_wall_grid.mesh_library = _create_wall_library(wall_material, door_material, Vector3(0, WALL_HEIGHT / 2.0, -CELL_SIZE / 2.0), false)
	north_wall_grid.cell_size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)

	south_wall_grid.mesh_library = _create_wall_library(wall_material, door_material, Vector3(0, WALL_HEIGHT / 2.0, CELL_SIZE / 2.0), false)
	south_wall_grid.cell_size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)

	east_wall_grid.mesh_library = _create_wall_library(wall_material, door_material, Vector3(CELL_SIZE / 2.0, WALL_HEIGHT / 2.0, 0), true)
	east_wall_grid.cell_size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)

	west_wall_grid.mesh_library = _create_wall_library(wall_material, door_material, Vector3(-CELL_SIZE / 2.0, WALL_HEIGHT / 2.0, 0), true)
	west_wall_grid.cell_size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)


func _create_floor_library(floor_mat: StandardMaterial3D, up_mat: StandardMaterial3D, down_mat: StandardMaterial3D) -> MeshLibrary:
	var library := MeshLibrary.new()

	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(CELL_SIZE, 0.1, CELL_SIZE)
	floor_mesh.material = floor_mat
	library.create_item(FloorMeshItem.FLOOR)
	library.set_item_mesh(FloorMeshItem.FLOOR, floor_mesh)

	var stairs_up_mesh := BoxMesh.new()
	stairs_up_mesh.size = Vector3(CELL_SIZE, 0.1, CELL_SIZE)
	stairs_up_mesh.material = up_mat
	library.create_item(FloorMeshItem.STAIRS_UP)
	library.set_item_mesh(FloorMeshItem.STAIRS_UP, stairs_up_mesh)

	var stairs_down_mesh := BoxMesh.new()
	stairs_down_mesh.size = Vector3(CELL_SIZE, 0.1, CELL_SIZE)
	stairs_down_mesh.material = down_mat
	library.create_item(FloorMeshItem.STAIRS_DOWN)
	library.set_item_mesh(FloorMeshItem.STAIRS_DOWN, stairs_down_mesh)

	return library


func _create_ceiling_library(material: StandardMaterial3D) -> MeshLibrary:
	var library := MeshLibrary.new()

	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE, 0.1, CELL_SIZE)
	mesh.material = material

	library.create_item(CeilingMeshItem.CEILING)
	library.set_item_mesh(CeilingMeshItem.CEILING, mesh)
	library.set_item_mesh_transform(CeilingMeshItem.CEILING, Transform3D(Basis(), Vector3(0, CEILING_Y, 0)))

	return library


func _create_wall_library(material: StandardMaterial3D, door_mat: StandardMaterial3D, offset: Vector3, rotated: bool) -> MeshLibrary:
	var library := MeshLibrary.new()

	var mesh := BoxMesh.new()
	if rotated:
		mesh.size = Vector3(0.1, WALL_HEIGHT, CELL_SIZE)
	else:
		mesh.size = Vector3(CELL_SIZE, WALL_HEIGHT, 0.1)
	mesh.material = material

	library.create_item(WallMeshItem.WALL)
	library.set_item_mesh(WallMeshItem.WALL, mesh)
	library.set_item_mesh_transform(WallMeshItem.WALL, Transform3D(Basis(), offset))

	var door_mesh := BoxMesh.new()
	if rotated:
		door_mesh.size = Vector3(0.1, WALL_HEIGHT, CELL_SIZE)
	else:
		door_mesh.size = Vector3(CELL_SIZE, WALL_HEIGHT, 0.1)
	door_mesh.material = door_mat

	library.create_item(WallMeshItem.DOOR_CLOSED)
	library.set_item_mesh(WallMeshItem.DOOR_CLOSED, door_mesh)
	library.set_item_mesh_transform(WallMeshItem.DOOR_CLOSED, Transform3D(Basis(), offset))

	return library


func _load_or_generate_dungeon() -> void:
	var cached: DungeonData = GameState.get_dungeon_floor(GameState.current_floor)
	if cached != null:
		dungeon_data = cached
		print("Loaded floor ", GameState.current_floor, " from cache")
	else:
		var generator := DungeonGenerator.new()
		dungeon_data = generator.generate(31, 31, GameState.current_floor)
		GameState.store_dungeon_floor(GameState.current_floor, dungeon_data)
		print("Generated floor ", GameState.current_floor, ": ", dungeon_data.rooms.size(), " rooms")


func _render_dungeon() -> void:
	_clear_all_grids()

	for y in range(dungeon_data.height):
		for x in range(dungeon_data.width):
			var tile: DungeonTile = dungeon_data.get_tile(x, y)
			if tile and tile.is_walkable():
				_render_tile(x, y, tile)


func _clear_all_grids() -> void:
	floor_grid.clear()
	ceiling_grid.clear()
	north_wall_grid.clear()
	south_wall_grid.clear()
	east_wall_grid.clear()
	west_wall_grid.clear()


func _render_tile(x: int, y: int, tile: DungeonTile) -> void:
	var cell := Vector3i(x, 0, y)

	var floor_item: int = FloorMeshItem.FLOOR
	match tile.special:
		DungeonTile.SpecialType.STAIRS_UP:
			floor_item = FloorMeshItem.STAIRS_UP
		DungeonTile.SpecialType.STAIRS_DOWN:
			floor_item = FloorMeshItem.STAIRS_DOWN

	floor_grid.set_cell_item(cell, floor_item)
	ceiling_grid.set_cell_item(cell, CeilingMeshItem.CEILING)

	_render_wall(north_wall_grid, cell, tile.north_wall, tile.is_door_open("north"))
	_render_wall(south_wall_grid, cell, tile.south_wall, tile.is_door_open("south"))
	_render_wall(east_wall_grid, cell, tile.east_wall, tile.is_door_open("east"))
	_render_wall(west_wall_grid, cell, tile.west_wall, tile.is_door_open("west"))


func _render_wall(grid: GridMap, cell: Vector3i, wall_type: DungeonTile.WallType, door_open: bool) -> void:
	match wall_type:
		DungeonTile.WallType.SOLID:
			grid.set_cell_item(cell, WallMeshItem.WALL)
		DungeonTile.WallType.DOOR:
			if door_open:
				grid.set_cell_item(cell, -1)
			else:
				grid.set_cell_item(cell, WallMeshItem.DOOR_CLOSED)
		_:
			pass


func _get_wall_grid(direction: String) -> GridMap:
	match direction:
		"north": return north_wall_grid
		"south": return south_wall_grid
		"east": return east_wall_grid
		"west": return west_wall_grid
	return null


func _update_door_visual(x: int, y: int, direction: String) -> void:
	var tile := dungeon_data.get_tile(x, y)
	if tile == null:
		return
	var grid := _get_wall_grid(direction)
	if grid == null:
		return
	var cell := Vector3i(x, 0, y)
	var wall_type := tile.get_wall_type(direction)
	_render_wall(grid, cell, wall_type, tile.is_door_open(direction))


func _update_enemy_door_visuals() -> void:
	if enemy_manager == null:
		return
	for d in enemy_manager.changed_doors:
		_update_door_visual(d.x, d.y, d.direction)


func _spawn_player() -> void:
	if GameState.dungeon_spawn_at_stairs_up:
		grid_position = dungeon_data.stairs_up_pos
		facing = Facing.SOUTH
	else:
		grid_position = dungeon_data.stairs_down_pos
		facing = Facing.NORTH

	_update_camera_transform()
	_mark_current_tile_discovered()


func _initialize_enemy_system() -> void:
	_enemy_container = Node3D.new()
	_enemy_container.name = "EnemyContainer"
	add_child(_enemy_container)

	if GameState.floor_tracker == null:
		GameState.floor_tracker = FloorTracker.new()
	GameState.floor_tracker.set_floor(GameState.current_floor)

	enemy_manager = EnemyManager.new()
	enemy_manager.initialize(dungeon_data, GameState.floor_tracker)
	enemy_manager.combat_triggered.connect(_on_enemy_combat_triggered)
	enemy_manager.enemy_group_spawned.connect(_on_enemy_spawned)
	enemy_manager.enemy_group_defeated.connect(_on_enemy_defeated)
	enemy_manager.zone_cleared.connect(_on_zone_cleared)

	if dungeon_data.enemy_groups.is_empty():
		enemy_manager.spawn_initial_enemies()
	else:
		for group in dungeon_data.enemy_groups:
			enemy_manager.enemy_groups.append(group)

	_create_enemy_sprites()
	_rebuild_group_lookup()
	_update_enemy_sprites()


func _create_enemy_sprites() -> void:
	for group in enemy_manager.enemy_groups:
		_create_sprite_for_group(group)


func _create_sprite_for_group(group: EnemyGroup) -> void:
	if enemy_sprites.has(group.id):
		return
	var sprite := EnemySpriteScene.instantiate()
	sprite.setup(group)
	_enemy_container.add_child(sprite)
	enemy_sprites[group.id] = sprite


var _los_cache: LOSCalculator = LOSCalculator.new()
var _group_lookup: Dictionary = {}


func _rebuild_group_lookup() -> void:
	_group_lookup.clear()
	for group in enemy_manager.enemy_groups:
		_group_lookup[group.id] = group


func _update_enemy_sprites() -> void:
	var player_pos := grid_position
	var is_revealed := GameState.floor_tracker.is_revealed()

	for group_id in enemy_sprites:
		var sprite: Sprite3D = enemy_sprites[group_id]
		var group: EnemyGroup = _group_lookup.get(group_id)

		if group == null or not group.is_alive():
			sprite.visible = false
			continue

		sprite.update_world_position()

		var dist: int = abs(group.grid_position.x - player_pos.x) + abs(group.grid_position.y - player_pos.y)

		var has_los := false
		if dist <= 10:
			has_los = _los_cache.has_line_of_sight(dungeon_data, player_pos, group.grid_position)

		if has_los or GameState.floor_tracker.is_spotted(group_id) or is_revealed:
			sprite.visible = true
			sprite.update_visibility(dist, is_revealed)

			if group.state == EnemyGroup.State.CHASE:
				sprite.set_chase_indicator(true)
			else:
				sprite.set_chase_indicator(false)
		else:
			sprite.visible = false


func _on_enemy_combat_triggered(group: EnemyGroup) -> void:
	var encounter := _create_encounter_from_group(group)
	_open_combat(encounter)


func _on_enemy_spawned(group: EnemyGroup) -> void:
	_create_sprite_for_group(group)
	_group_lookup[group.id] = group


func _on_enemy_defeated(group: EnemyGroup) -> void:
	_group_lookup.erase(group.id)
	if enemy_sprites.has(group.id):
		var sprite: Sprite3D = enemy_sprites[group.id]
		sprite.queue_free()
		enemy_sprites.erase(group.id)


func _on_zone_cleared(_zone: EncounterZone) -> void:
	print("The area grows quiet...")


func _create_encounter_from_group(group: EnemyGroup) -> Dictionary:
	var enemies: Array[Monster] = []
	var is_boss := group.ai_type == EnemyGroup.AIType.BOSS
	var positions: Array[Vector2i]
	if is_boss:
		positions = _get_boss_formation_positions(group.monsters.size())
	else:
		positions = _get_formation_positions(group.monsters.size())

	for i in range(group.monsters.size()):
		var monster := group.monsters[i].duplicate_for_combat()
		monster.grid_position = positions[i]
		monster.init_combat()
		enemies.append(monster)

	var encounter := {"enemies": enemies, "enemy_group": group}
	if is_boss:
		encounter["is_boss"] = true
	return encounter


func _update_ui() -> void:
	floor_label.text = "Floor " + str(GameState.current_floor)


func _input(event: InputEvent) -> void:
	if combat_open:
		return

	if map_open and (event.is_action_pressed("menu_cancel") or event.is_action_pressed("toggle_map")):
		_close_map()
		get_viewport().set_input_as_handled()
		return

	if menu_open and event.is_action_pressed("menu_cancel"):
		_close_menu()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if menu_open or map_open or combat_open or is_moving:
		return

	if event.is_action_pressed("strafe_left"):
		_strafe_left()
	elif event.is_action_pressed("strafe_right"):
		_strafe_right()
	elif event.is_action_pressed("menu_up"):
		_move_forward()
	elif event.is_action_pressed("menu_down"):
		_move_backward()
	elif event.is_action_pressed("menu_left"):
		_turn_left()
	elif event.is_action_pressed("menu_right"):
		_turn_right()
	elif event.is_action_pressed("menu_confirm"):
		_interact()
	elif event.is_action_pressed("menu_cancel") or event.is_action_pressed("go_to_menu"):
		_open_menu()
	elif event.is_action_pressed("toggle_map"):
		_open_map()
	elif event.is_action_pressed("go_to_town"):
		_on_town_pressed()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_G:
		_debug_add_gold()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_K:
		_debug_add_key()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_S and event.shift_pressed:
		_run_single_simulation()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_B and event.shift_pressed:
		_run_batch_simulation()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_L and event.shift_pressed:
		_toggle_ai_logging()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB and event.shift_pressed:
		_cycle_debug_material()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_EQUAL:
		_adjust_material_normal(0.05)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_MINUS:
		_adjust_material_normal(-0.05)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_BRACKETRIGHT:
		_adjust_material_roughness(0.05)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_BRACKETLEFT:
		_adjust_material_roughness(-0.05)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if event.shift_pressed:
			_debug_teleport_floor(GameState.current_floor + 1)
		elif event.ctrl_pressed and GameState.current_floor > 1:
			_debug_teleport_floor(GameState.current_floor - 1)


func _get_debug_material() -> StandardMaterial3D:
	match _debug_material_index:
		0: return _floor_material
		1: return _wall_material
		2: return _ceiling_material
	return _floor_material


func _get_debug_material_name() -> String:
	match _debug_material_index:
		0: return "Floor"
		1: return "Wall"
		2: return "Ceiling"
	return "Floor"


func _cycle_debug_material() -> void:
	_debug_material_index = (_debug_material_index + 1) % 3
	var mat := _get_debug_material()
	print("[Debug] Selected: %s (normal=%.2f, roughness=%.2f)" % [_get_debug_material_name(), mat.normal_scale, mat.roughness])


func _adjust_material_normal(delta: float) -> void:
	var mat := _get_debug_material()
	mat.normal_scale = clampf(mat.normal_scale + delta, 0.0, 2.0)
	print("[Debug] %s normal_scale = %.2f" % [_get_debug_material_name(), mat.normal_scale])


func _adjust_material_roughness(delta: float) -> void:
	var mat := _get_debug_material()
	mat.roughness = clampf(mat.roughness + delta, 0.0, 1.0)
	print("[Debug] %s roughness = %.2f" % [_get_debug_material_name(), mat.roughness])


func _debug_teleport_floor(target_floor: int) -> void:
	print("[Debug] Teleporting to floor %d" % target_floor)
	SceneManager.go_to_dungeon(target_floor, true)



func _move_forward() -> void:
	var direction: Vector2i = _get_facing_vector()
	var new_pos: Vector2i = grid_position + direction

	if _can_move_to(grid_position, new_pos):
		previous_grid_position = grid_position
		grid_position = new_pos
		_animate_move_to(new_pos)


func _move_backward() -> void:
	var direction: Vector2i = _get_facing_vector()
	var new_pos: Vector2i = grid_position - direction

	if _can_move_to(grid_position, new_pos):
		previous_grid_position = grid_position
		grid_position = new_pos
		_animate_move_to(new_pos)


func _strafe_left() -> void:
	var direction: Vector2i = _get_strafe_vector(-1)
	var new_pos: Vector2i = grid_position + direction

	if _can_move_to(grid_position, new_pos):
		previous_grid_position = grid_position
		grid_position = new_pos
		_animate_move_to(new_pos)


func _strafe_right() -> void:
	var direction: Vector2i = _get_strafe_vector(1)
	var new_pos: Vector2i = grid_position + direction

	if _can_move_to(grid_position, new_pos):
		previous_grid_position = grid_position
		grid_position = new_pos
		_animate_move_to(new_pos)


func _animate_move_to(target_grid: Vector2i) -> void:
	is_moving = true

	var target_pos := Vector3(
		target_grid.x * CELL_SIZE + CELL_SIZE / 2.0,
		CAMERA_HEIGHT,
		target_grid.y * CELL_SIZE + CELL_SIZE / 2.0
	)

	if move_tween:
		move_tween.kill()

	move_tween = create_tween()
	move_tween.set_ease(Tween.EASE_OUT)
	move_tween.set_trans(Tween.TRANS_SINE)
	move_tween.tween_property(camera, "position", target_pos, MOVE_DURATION)
	move_tween.tween_callback(_on_move_complete)


func _can_move_to(from: Vector2i, to: Vector2i) -> bool:
	if not dungeon_data.is_walkable(to.x, to.y):
		return false

	var from_tile: DungeonTile = dungeon_data.get_tile(from.x, from.y)
	if from_tile == null:
		return false

	var dx: int = to.x - from.x
	var dy: int = to.y - from.y

	var dir := ""
	if dy < 0: dir = "north"
	elif dy > 0: dir = "south"
	elif dx < 0: dir = "west"
	elif dx > 0: dir = "east"

	if dir != "" and _is_wall_blocking(from_tile, dir):
		return false

	var to_tile: DungeonTile = dungeon_data.get_tile(to.x, to.y)
	if to_tile != null and dir != "":
		var opposite: String = DungeonData.OPPOSITE_DIR[dir]
		if _is_wall_blocking(to_tile, opposite):
			return false

	return true


func _is_wall_blocking(tile: DungeonTile, direction: String) -> bool:
	var wall_type := tile.get_wall_type(direction)
	if wall_type == DungeonTile.WallType.SOLID:
		return true
	if wall_type == DungeonTile.WallType.DOOR and not tile.is_door_open(direction):
		return true
	return false


func _check_special_tile() -> void:
	var tile: DungeonTile = dungeon_data.get_tile(grid_position.x, grid_position.y)
	if tile == null:
		return

	if tile.special == DungeonTile.SpecialType.STAIRS_DOWN:
		_descend_stairs()
	elif tile.special == DungeonTile.SpecialType.STAIRS_UP:
		_ascend_stairs()


func _descend_stairs() -> void:
	var next_floor := GameState.current_floor + 1
	print("Descending to floor ", next_floor)
	SceneManager.go_to_dungeon(next_floor, true)


func _ascend_stairs() -> void:
	if GameState.current_floor <= 1:
		print("Returning to town...")
		SceneManager.go_to_town()
	else:
		var prev_floor := GameState.current_floor - 1
		print("Ascending to floor ", prev_floor)
		SceneManager.go_to_dungeon(prev_floor, false)


func _turn_left() -> void:
	var old_facing := facing
	facing = ((facing - 1 + 4) % 4) as Facing
	_animate_turn(old_facing, -1)


func _turn_right() -> void:
	var old_facing := facing
	facing = ((facing + 1) % 4) as Facing
	_animate_turn(old_facing, 1)


func _animate_turn(from_facing: Facing, direction: int) -> void:
	is_moving = true

	var _from_rotation := -from_facing * 90.0
	var to_rotation := -facing * 90.0

	if direction > 0 and from_facing == Facing.WEST and facing == Facing.NORTH:
		to_rotation = -360.0
	elif direction < 0 and from_facing == Facing.NORTH and facing == Facing.WEST:
		to_rotation = 90.0

	if move_tween:
		move_tween.kill()

	move_tween = create_tween()
	move_tween.set_ease(Tween.EASE_OUT)
	move_tween.set_trans(Tween.TRANS_SINE)
	move_tween.tween_property(camera, "rotation_degrees:y", to_rotation, TURN_DURATION)
	move_tween.tween_callback(_on_turn_complete)


func _get_facing_vector() -> Vector2i:
	match facing:
		Facing.NORTH:
			return Vector2i(0, -1)
		Facing.EAST:
			return Vector2i(1, 0)
		Facing.SOUTH:
			return Vector2i(0, 1)
		Facing.WEST:
			return Vector2i(-1, 0)
	return Vector2i.ZERO


func _get_strafe_vector(direction: int) -> Vector2i:
	match facing:
		Facing.NORTH:
			return Vector2i(direction, 0)
		Facing.EAST:
			return Vector2i(0, direction)
		Facing.SOUTH:
			return Vector2i(-direction, 0)
		Facing.WEST:
			return Vector2i(0, -direction)
	return Vector2i.ZERO


func _update_camera_transform() -> void:
	camera.position = Vector3(
		grid_position.x * CELL_SIZE + CELL_SIZE / 2.0,
		CAMERA_HEIGHT,
		grid_position.y * CELL_SIZE + CELL_SIZE / 2.0
	)
	camera.rotation_degrees.y = -facing * 90.0


func _on_move_complete() -> void:
	is_moving = false
	_mark_current_tile_discovered()
	_close_doors_behind()
	_check_special_tile()
	_process_enemy_turn()
	_update_enemy_door_visuals()
	_check_held_movement()


func _on_turn_complete() -> void:
	is_moving = false
	camera.rotation_degrees.y = -facing * 90.0
	_check_held_movement()


func _check_held_movement() -> void:
	if menu_open or map_open or combat_open:
		return

	if Input.is_action_pressed("strafe_left"):
		_strafe_left()
	elif Input.is_action_pressed("strafe_right"):
		_strafe_right()
	elif Input.is_action_pressed("menu_up"):
		_move_forward()
	elif Input.is_action_pressed("menu_down"):
		_move_backward()
	elif Input.is_action_pressed("menu_left"):
		_turn_left()
	elif Input.is_action_pressed("menu_right"):
		_turn_right()


func _on_town_pressed() -> void:
	SceneManager.go_to_town()


func _process_enemy_turn() -> void:
	if enemy_manager == null:
		return

	var combat_group := enemy_manager.on_player_move(grid_position, facing)
	_rebuild_group_lookup()
	_update_enemy_sprites()

	if combat_group != null:
		return


func _check_random_encounter() -> void:
	if randf() < GameState.encounter_chance:
		var encounter := _generate_encounter()
		_open_combat(encounter)


func _force_combat() -> void:
	var encounter := _generate_encounter()
	_open_combat(encounter)


func _open_combat(encounter: Dictionary) -> void:
	if combat_open:
		return
	combat_open = true
	combat_overlay.visible = true

	GameState.start_combat(encounter)
	combat_ui = CombatScene.instantiate()
	combat_ui.combat_closed.connect(_on_combat_closed)
	combat_overlay.add_child(combat_ui)


func _on_combat_closed(victory: bool) -> void:
	var encounter := GameState.current_encounter
	_close_combat()

	if victory and encounter.has("enemy_group"):
		var group: EnemyGroup = encounter.enemy_group
		if enemy_manager != null:
			enemy_manager.remove_defeated_group(group)

	if not victory:
		var all_dead := true
		if GameState.party:
			for character in GameState.party.members:
				if not character.is_dead:
					all_dead = false
					break
		if all_dead:
			SceneManager.go_to_town()
		else:
			grid_position = previous_grid_position
			_update_camera_transform()
			_update_enemy_sprites()


func _close_combat() -> void:
	if not combat_open:
		return
	combat_open = false
	combat_overlay.visible = false
	if combat_ui:
		combat_ui.queue_free()
		combat_ui = null


func _debug_add_gold() -> void:
	if GameState.party:
		GameState.party.gold += 1000
		print("[DEBUG] Added 1000 gold. Total: %d" % GameState.party.gold)


func _debug_add_key() -> void:
	if GameState.party:
		var key := ShopItems.get_item("dungeon_key")
		if key:
			GameState.party.inventory.add_item(key.duplicate(true) as Item)
			_show_dungeon_message("DEBUG: Added Dungeon Key")
			print("[DEBUG] Added Dungeon Key. Count: %d" % GameState.party.inventory.get_item_count("dungeon_key"))


func _generate_encounter() -> Dictionary:
	var enemy_count := _roll_enemy_count()
	var enemies: Array[Monster] = []
	var positions := _get_formation_positions(enemy_count)

	var available_monsters := MonsterDatabase.get_monsters_for_floor(GameState.current_floor)
	if available_monsters.is_empty():
		available_monsters = ["slime"]

	for i in range(enemy_count):
		var monster_id: String = available_monsters[randi() % available_monsters.size()]
		var enemy := MonsterDatabase.get_monster(monster_id)
		if enemy == null:
			enemy = MonsterDatabase.get_monster("slime")
		if enemy != null:
			enemy.grid_position = positions[i]
			enemy.init_combat()
			enemies.append(enemy)

	return {"enemies": enemies}


func _roll_enemy_count() -> int:
	var roll := randf()
	if roll < 0.4:
		return 1
	elif roll < 0.7:
		return 2
	elif roll < 0.9:
		return 3
	elif roll < 0.97:
		return 4
	else:
		return 5


func _get_formation_positions(count: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []

	match count:
		1:
			positions = [Vector2i(1, 0)]
		2:
			positions = [Vector2i(0, 0), Vector2i(2, 0)]
		3:
			positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
		4:
			positions = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)]
		5:
			positions = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(2, 1)]
		_:
			for i in range(mini(count, 9)):
				var col := i % 3
				var row := i / 3
				positions.append(Vector2i(col, row))

	return positions


func _get_boss_formation_positions(count: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	match count:
		1:
			positions = [Vector2i(1, 1)]
		2:
			positions = [Vector2i(1, 1), Vector2i(0, 0)]
		3:
			positions = [Vector2i(1, 1), Vector2i(0, 0), Vector2i(2, 0)]
		_:
			positions = [Vector2i(1, 1), Vector2i(0, 0), Vector2i(2, 0)]
			for i in range(3, count):
				var col := (i - 3) % 3
				var row := (i - 3) / 3 + 2
				positions.append(Vector2i(col, row))
	return positions


func _on_menu_pressed() -> void:
	_open_menu()


func _open_menu() -> void:
	if menu_open:
		return

	menu_open = true
	menu_overlay.visible = true

	party_menu = PartyMenuScene.instantiate()
	party_menu.closed.connect(_close_menu)
	menu_overlay.add_child(party_menu)


func _close_menu() -> void:
	if not menu_open:
		return

	menu_open = false
	menu_overlay.visible = false

	if party_menu:
		party_menu.queue_free()
		party_menu = null


func _open_map() -> void:
	if map_open:
		return

	map_open = true
	map_overlay.visible = true

	var map_enemy_data := {}
	if enemy_manager != null:
		map_enemy_data = enemy_manager.get_minimap_data()

	dungeon_map = DungeonMapScene.instantiate()
	dungeon_map.closed.connect(_close_map)
	dungeon_map.update_map(dungeon_data, grid_position, facing, map_enemy_data)
	map_overlay.add_child(dungeon_map)


func _close_map() -> void:
	if not map_open:
		return

	map_open = false
	map_overlay.visible = false

	if dungeon_map:
		dungeon_map.queue_free()
		dungeon_map = null


func _mark_current_tile_discovered() -> void:
	var tile: DungeonTile = dungeon_data.get_tile(grid_position.x, grid_position.y)
	if tile != null:
		tile.discovered = true


func _setup_message_label() -> void:
	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.anchors_preset = Control.PRESET_CENTER_BOTTOM
	_message_label.anchor_left = 0.5
	_message_label.anchor_right = 0.5
	_message_label.anchor_top = 1.0
	_message_label.anchor_bottom = 1.0
	_message_label.offset_left = -200
	_message_label.offset_right = 200
	_message_label.offset_top = -80
	_message_label.offset_bottom = -50
	_message_label.add_theme_font_size_override("font_size", 18)
	_message_label.modulate.a = 0.0
	$UI.add_child(_message_label)


func _show_dungeon_message(text: String) -> void:
	_message_label.text = text
	_message_label.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.5)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.5)


func _get_facing_direction_string() -> String:
	match facing:
		Facing.NORTH: return "north"
		Facing.EAST: return "east"
		Facing.SOUTH: return "south"
		Facing.WEST: return "west"
	return "north"


func _interact() -> void:
	var dir := _get_facing_direction_string()
	var tile := dungeon_data.get_tile(grid_position.x, grid_position.y)
	if tile == null:
		return

	if tile.get_wall_type(dir) != DungeonTile.WallType.DOOR:
		return

	if tile.is_door_open(dir):
		return

	if tile.is_door_locked(dir):
		if _informed_locked_pos != grid_position or _informed_locked_dir != dir:
			_informed_locked_pos = grid_position
			_informed_locked_dir = dir
			_show_dungeon_message("The door is locked.")
			return
		_try_unlock_door(dir)
	else:
		_open_door_and_step(grid_position.x, grid_position.y, dir, "You open the door.")


func _open_door_and_step(x: int, y: int, direction: String, message: String) -> void:
	dungeon_data.sync_door_open(x, y, direction, true)
	_update_door_visual(x, y, direction)
	var offset: Vector2i = DungeonData.DIR_OFFSET[direction]
	_update_door_visual(x + offset.x, y + offset.y, DungeonData.OPPOSITE_DIR[direction])
	_show_dungeon_message(message)
	_move_forward()


func _close_doors_behind() -> void:
	if previous_grid_position == grid_position:
		return

	var dx := grid_position.x - previous_grid_position.x
	var dy := grid_position.y - previous_grid_position.y

	var move_dir := ""
	if dy < 0: move_dir = "north"
	elif dy > 0: move_dir = "south"
	elif dx > 0: move_dir = "east"
	elif dx < 0: move_dir = "west"

	if move_dir == "":
		return

	var prev_tile := dungeon_data.get_tile(previous_grid_position.x, previous_grid_position.y)
	if prev_tile == null:
		return

	if prev_tile.get_wall_type(move_dir) == DungeonTile.WallType.DOOR and prev_tile.is_door_open(move_dir):
		dungeon_data.sync_door_open(previous_grid_position.x, previous_grid_position.y, move_dir, false)
		_update_door_visual(previous_grid_position.x, previous_grid_position.y, move_dir)
		_update_door_visual(grid_position.x, grid_position.y, DungeonData.OPPOSITE_DIR[move_dir])


func _try_unlock_door(direction: String) -> void:
	if GameState.party == null:
		_show_dungeon_message("The door is locked.")
		return

	# TODO: lockpicking is just a dice roll right now - replace with a mini-game
	if GameState.party.has_living_thief():
		var thief := GameState.party.get_living_thief()
		var pick_chance := 0.25 + (thief.agility * 0.02) + (thief.level * 0.03)
		pick_chance = clampf(pick_chance, 0.10, 0.95)
		if randf() < pick_chance:
			dungeon_data.sync_door_locked(grid_position.x, grid_position.y, direction, false)
			_informed_locked_pos = Vector2i(-1, -1)
			_informed_locked_dir = ""
			_open_door_and_step(grid_position.x, grid_position.y, direction, "%s picks the lock!" % thief.get_display_name())
		else:
			_show_dungeon_message("%s fails to pick the lock." % thief.get_display_name())
		return

	if GameState.party.inventory.has_item("dungeon_key"):
		GameState.party.inventory.remove_item("dungeon_key", 1)
		dungeon_data.sync_door_locked(grid_position.x, grid_position.y, direction, false)
		_informed_locked_pos = Vector2i(-1, -1)
		_informed_locked_dir = ""
		_open_door_and_step(grid_position.x, grid_position.y, direction, "You use a Dungeon Key.")
		return

	_show_dungeon_message("The door is locked.")


func _run_single_simulation() -> void:
	if GameState.party == null:
		print("[Simulation] No party available")
		return

	var encounter := _generate_encounter()
	var enemies: Array[Monster] = encounter.enemies
	var seed_value := Time.get_ticks_msec()

	var simulator := CombatSimulator.new()
	simulator.setup(GameState.party, enemies, seed_value)

	if _simulation_logging_enabled:
		simulator.ai_log = AIDecisionLog.new()

	var result := simulator.run()

	print("[Simulation] Single combat result:")
	print(JSON.stringify(result, "\t"))

	if _simulation_logging_enabled and simulator.ai_log != null:
		print("[Simulation] AI Decision Log:")
		print(simulator.ai_log.to_json())


func _run_batch_simulation() -> void:
	if GameState.party == null:
		print("[Simulation] No party available")
		return

	var base_encounter := _generate_encounter()
	var enemies: Array[Monster] = base_encounter.enemies

	var batch := BatchSimulator.new()
	batch.batch_progress.connect(_on_batch_progress)

	print("[Simulation] Running 100 combat simulations...")
	var result := batch.run_batch(GameState.party, enemies, 100, Time.get_ticks_msec())

	print("[Simulation] Batch results:")
	print("  Win rate: %.1f%%" % result.win_rate)
	print("  Avg turns: %.1f" % result.avg_turns)
	print("  Avg HP remaining (victories): %.1f%%" % result.avg_hp_remaining_on_victory)
	if result.most_common_cause_of_defeat != "":
		print("  Most common defeat cause: %s" % result.most_common_cause_of_defeat)


func _on_batch_progress(current: int, total: int) -> void:
	if current % 10 == 0:
		print("[Simulation] Progress: %d/%d" % [current, total])


func _toggle_ai_logging() -> void:
	_simulation_logging_enabled = not _simulation_logging_enabled
	var status := "ENABLED - Shift+S will include AI decision log" if _simulation_logging_enabled else "DISABLED"
	print("[Simulation] AI decision logging: %s" % status)

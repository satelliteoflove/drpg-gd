extends Node3D

const PartyMenuScene = preload("res://scenes/common/party_menu.tscn")
const DungeonMapScene = preload("res://scenes/dungeon/dungeon_map.tscn")
const CombatScene = preload("res://scenes/combat/combat.tscn")
const EnemySpriteScene = preload("res://scenes/dungeon/enemy_sprite_3d.tscn")
const VignetteShader = preload("res://shaders/dungeon_vignette.gdshader")

var menu_open: bool = false
var map_open: bool = false
var combat_open: bool = false
var event_open: bool = false
var party_menu: Control = null
var _chat_log: PartyChatLog = null
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
const TORCH_LOW_WARNING: int = 20

const SFX_FOOTSTEPS := [
	"res://audio/sfx/footstep_1.wav",
	"res://audio/sfx/footstep_2.wav",
	"res://audio/sfx/footstep_3.wav",
]
const SFX_TURN := "res://audio/sfx/turn.wav"
const SFX_STAIRS := "res://audio/sfx/stairs.wav"
const SFX_TORCH_LIGHT := "res://audio/sfx/torch_light.wav"
const SFX_TORCH_LOW := "res://audio/sfx/torch_low.wav"
const SFX_ENCOUNTER := "res://audio/sfx/encounter.wav"
const SFX_TORCH_LOOP := "res://audio/sfx/torch_loop.wav"

enum Facing { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }

enum FloorMeshItem { FLOOR = 0, STAIRS_UP = 1, STAIRS_DOWN = 2, SHRINE = 3, INSCRIPTION = 4 }
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

var movement: DungeonMovement = null
var interaction: DungeonInteraction = null
var event_handler: DungeonEventHandler = null

@onready var floor_grid: GridMap = $FloorGridMap
@onready var ceiling_grid: GridMap = $CeilingGridMap
@onready var north_wall_grid: GridMap = $NorthWallGridMap
@onready var south_wall_grid: GridMap = $SouthWallGridMap
@onready var east_wall_grid: GridMap = $EastWallGridMap
@onready var west_wall_grid: GridMap = $WestWallGridMap
@onready var camera: Camera3D = $Camera3D
@onready var player_light: OmniLight3D = $Camera3D/PlayerLight

# Dungeon HUD (built in code in _build_hud so it shares the Arcane-Tome theme).
var _hud_root: Control = null
var floor_label: Label = null
var time_label: Label = null
var _compass: CompassRose = null
var _vitals_strip: PartyVitalsStrip = null

var _flicker_time: float = 0.0
var _message_label: Label = null
var _informed_locked_pos: Vector2i = Vector2i(-1, -1)
var _informed_locked_dir: String = ""
var _message_tween: Tween = null

var _floor_material: StandardMaterial3D = null
var _wall_material: StandardMaterial3D = null
var _ceiling_material: StandardMaterial3D = null
var _debug_material_index: int = 0

var _theme: FloorTheme = null
var _vignette_rect: ColorRect = null
var _vignette_mat: ShaderMaterial = null
var _world_env: WorldEnvironment = null
var _light_ctl: DungeonLightController = null
var _light_target: Dictionary = {}
var _last_light_source: int = -1

# --- Music jukebox (debug A/B audition; Shift+. = next, Shift+, = prev) ------
# Cycles every audio file in JUKEBOX_DIR through the music player so candidate
# tracks can be compared by ear in-situ (with the biome's ambient bed + fog
# mood). Debug-only; the chosen tracks get wired into FloorThemes afterward.
const JUKEBOX_DIR := "res://audio/music/candidates/"
var _jukebox_tracks: Array[String] = []
var _jukebox_idx: int = -1
var _jukebox_label: Label = null
var light_label: Label = null
var _decoration_container: Node3D = null
var _braziers: Array = []
var _torch_audio: AudioStreamPlayer = null

@onready var menu_overlay: CanvasLayer = $MenuOverlay
@onready var map_overlay: CanvasLayer = $MapOverlay
@onready var combat_overlay: CanvasLayer = $CombatOverlay


func _ready() -> void:
	Engine.max_fps = 30

	movement = DungeonMovement.new()
	movement.init(self)
	interaction = DungeonInteraction.new()
	interaction.init(self)
	event_handler = DungeonEventHandler.new()
	event_handler.init(self)

	_load_or_generate_dungeon()
	_resolve_theme()
	_setup_grid_maps()
	_setup_environment()
	_render_dungeon()
	_build_decorations()
	_spawn_player()
	_initialize_enemy_system()
	_setup_vignette()
	_build_hud()
	_init_light()
	_start_dungeon_audio()
	_update_ui()
	GameState.floor_tracker.step_taken.connect(_on_step_taken)

	_setup_message_label()
	_setup_chat_log()
	GameState.party_member_died.connect(event_handler.on_party_member_died_in_dungeon)


func _process(delta: float) -> void:
	if _light_target.is_empty():
		return
	_flicker_time += delta * TORCH_FLICKER_SPEED
	var flicker := sin(_flicker_time) * 0.5 + sin(_flicker_time * 2.3) * 0.3 + sin(_flicker_time * 4.1) * 0.2
	var target_energy: float = float(_light_target["energy"]) + flicker * float(_light_target["flicker"])
	var k := clampf(delta * 5.0, 0.0, 1.0)
	player_light.light_energy = lerpf(player_light.light_energy, target_energy, k)
	player_light.omni_range = lerpf(player_light.omni_range, float(_light_target["range"]), k)
	player_light.light_color = player_light.light_color.lerp(_light_target["color"], k)
	var ke := clampf(delta * 3.0, 0.0, 1.0)
	if _world_env and _world_env.environment:
		var env := _world_env.environment
		env.fog_density = lerpf(env.fog_density, float(_light_target["fog"]), ke)
	if _vignette_mat:
		var cur: float = _vignette_mat.get_shader_parameter("strength")
		_vignette_mat.set_shader_parameter("strength", lerpf(cur, float(_light_target["vignette"]), ke))


# --- Dungeon HUD ------------------------------------------------------------
# Built in code so the exploration overlay shares the Arcane-Tome theme. A
# top-left almanac (floor + day/time), a top-centre compass, top-right nav
# buttons, and a bottom party-vitals band.

func _build_hud() -> void:
	_hud_root = Control.new()
	_hud_root.name = "HUDRoot"
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_hud_root)

	_build_almanac()
	_build_compass()
	_build_nav_buttons()
	_build_vitals_strip()


func _build_almanac() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = 10
	panel.offset_top = 10
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)

	floor_label = Label.new()
	floor_label.theme_type_variation = &"SubheaderLabel"
	floor_label.add_theme_color_override("font_color", UIColors.TITLE_GOLD)
	floor_label.text = "Floor 1"
	col.add_child(floor_label)

	time_label = Label.new()
	time_label.theme_type_variation = &"MutedLabel"
	time_label.text = "Day 1"
	col.add_child(time_label)

	light_label = Label.new()
	light_label.theme_type_variation = &"MutedLabel"
	light_label.text = "Torch"
	col.add_child(light_label)


func _build_compass() -> void:
	_compass = CompassRose.new()
	_compass.custom_minimum_size = Vector2(78, 78)
	_compass.anchor_left = 0.5
	_compass.anchor_right = 0.5
	_compass.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_compass.offset_left = -39
	_compass.offset_right = 39
	_compass.offset_top = 8
	_compass.offset_bottom = 86
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_compass)
	_compass.set_facing(int(facing))


func _build_nav_buttons() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = 10
	panel.offset_right = -10
	_hud_root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var menu_btn := Button.new()
	menu_btn.text = "Menu (M)"
	menu_btn.focus_mode = Control.FOCUS_NONE
	menu_btn.pressed.connect(_on_menu_pressed)
	row.add_child(menu_btn)

	var town_btn := Button.new()
	town_btn.text = "Town (T)"
	town_btn.focus_mode = Control.FOCUS_NONE
	town_btn.pressed.connect(_on_town_pressed)
	row.add_child(town_btn)


func _build_vitals_strip() -> void:
	_vitals_strip = PartyVitalsStrip.new()
	_vitals_strip.anchor_left = 0.0
	_vitals_strip.anchor_right = 1.0
	_vitals_strip.anchor_top = 1.0
	_vitals_strip.anchor_bottom = 1.0
	_vitals_strip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_vitals_strip.offset_left = 8
	_vitals_strip.offset_right = -8
	_vitals_strip.offset_top = -72
	_vitals_strip.offset_bottom = -6
	_hud_root.add_child(_vitals_strip)


func _refresh_compass() -> void:
	if _compass:
		_compass.set_facing(int(facing))


func _make_surface_material(tint: Color, roughness_value: float, tex: Dictionary = {}) -> StandardMaterial3D:
	# `tex` is a per-surface PBR set (see FloorTheme.floor/wall/ceiling_textures);
	# defaults to the floor set so existing callers keep working.
	if tex.is_empty():
		tex = _theme.floor_textures()
	var material := StandardMaterial3D.new()

	var albedo := load(tex["albedo"]) as Texture2D if tex["albedo"] != "" else null
	if albedo:
		material.albedo_texture = albedo
	material.albedo_color = tint

	var normal_tex := load(tex["normal"]) as Texture2D if tex["normal"] != "" else null
	if normal_tex:
		material.normal_enabled = true
		material.normal_texture = normal_tex
		material.normal_scale = tex["normal_strength"]

	if tex["ao"] != "":
		var ao_tex := load(tex["ao"]) as Texture2D
		if ao_tex:
			material.ao_enabled = true
			material.ao_texture = ao_tex
			material.ao_light_affect = 0.8

	if tex["roughness"] != "":
		var rough_tex := load(tex["roughness"]) as Texture2D
		if rough_tex:
			material.roughness_texture = rough_tex
			material.roughness = 1.0
		else:
			material.roughness = roughness_value
	else:
		material.roughness = roughness_value

	material.uv1_scale = tex["uv_scale"]
	material.uv1_triplanar = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Matte: rock/moss/brick are non-specular. A low specular kills the unbelievable
	# "wet glossy" highlight that otherwise blooms on walls near a torch (and stops
	# SSR from mirroring on them — puddles keep their own glossy material).
	material.metallic_specular = 0.1
	material.roughness = maxf(material.roughness, 0.85) if tex["roughness"] == "" else material.roughness

	return material


func _make_door_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()

	var albedo := load(_theme.door_albedo) as Texture2D
	if albedo:
		material.albedo_texture = albedo
	material.albedo_color = _theme.door_tint

	var normal_tex := load(_theme.door_normal) as Texture2D
	if normal_tex:
		material.normal_enabled = true
		material.normal_texture = normal_tex
		material.normal_scale = 0.8

	material.roughness = 0.85
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material


func _setup_grid_maps() -> void:
	var floor_tex := _theme.floor_textures()
	var floor_material := _make_surface_material(_theme.floor_tint, _theme.floor_roughness, floor_tex)
	var stairs_up_material := _make_surface_material(_theme.stairs_up_tint, _theme.floor_roughness, floor_tex)
	var stairs_down_material := _make_surface_material(_theme.stairs_down_tint, _theme.floor_roughness, floor_tex)
	var ceiling_material := _make_surface_material(_theme.ceiling_tint, _theme.ceiling_roughness, _theme.ceiling_textures())
	var wall_material := _make_surface_material(_theme.wall_tint, _theme.wall_roughness, _theme.wall_textures())
	var door_material := _make_door_material()

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

	var shrine_mat := StandardMaterial3D.new()
	shrine_mat.albedo_color = _theme.shrine_color
	var shrine_mesh := BoxMesh.new()
	shrine_mesh.size = Vector3(CELL_SIZE, 0.1, CELL_SIZE)
	shrine_mesh.material = shrine_mat
	library.create_item(FloorMeshItem.SHRINE)
	library.set_item_mesh(FloorMeshItem.SHRINE, shrine_mesh)

	var inscription_mat := StandardMaterial3D.new()
	inscription_mat.albedo_color = _theme.inscription_color
	var inscription_mesh := BoxMesh.new()
	inscription_mesh.size = Vector3(CELL_SIZE, 0.1, CELL_SIZE)
	inscription_mesh.material = inscription_mat
	library.create_item(FloorMeshItem.INSCRIPTION)
	library.set_item_mesh(FloorMeshItem.INSCRIPTION, inscription_mesh)

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
		print_debug("Loaded floor ", GameState.current_floor, " from cache")
	else:
		var generator := DungeonGenerator.new()
		dungeon_data = generator.generate(31, 31, GameState.current_floor)
		GameState.store_dungeon_floor(GameState.current_floor, dungeon_data)
		print_debug("Generated floor ", GameState.current_floor, ": ", dungeon_data.rooms.size(), " rooms")


func _resolve_theme() -> void:
	_theme = dungeon_data.theme
	if _theme == null:
		_theme = FloorThemes.get_theme(GameState.current_floor)
		dungeon_data.theme = _theme


# Apply the theme's atmosphere to the shared WorldEnvironment + background. Fog
# density here is the "lit" baseline; the light controller (D2) drives it darker
# when the party loses its light source.
func _setup_environment() -> void:
	var world_env: WorldEnvironment = $WorldEnvironment
	if world_env == null or world_env.environment == null:
		return
	_world_env = world_env
	var env := world_env.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = _theme.bg_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _theme.ambient_color
	env.ambient_light_energy = _theme.ambient_energy
	env.fog_enabled = true
	env.fog_light_color = _theme.fog_color
	env.fog_light_energy = 1.0
	env.fog_density = _theme.fog_density_lit

	_apply_modern_rendering(env)


# Modern rendering pass: filmic tonemap (bright torchlight rolls off instead of
# clipping), SSAO contact shadows in the masonry, glow so flames/fungi/light-spell
# bloom in the dark, SSR so wet floors + puddles catch reflections, and light
# volumetric fog for torch god-rays. Tuned for a dark dungeon-crawler.
func _apply_modern_rendering(env: Environment) -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0

	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = 2.4
	env.ssao_detail = 1.0
	env.ssao_power = 1.6

	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3

	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.85
	for i in range(7):
		env.set_glow_level(i, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.5)

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = _theme.fog_color
	env.volumetric_fog_emission = Color(0, 0, 0)
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_length = 28.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.0


# Scatter code-built props (braziers, pillars, rubble, cobwebs, theme accents)
# keyed off the theme. Visual only — movement still keys off the wall data.
func _build_decorations() -> void:
	_decoration_container = Node3D.new()
	_decoration_container.name = "DecorationContainer"
	add_child(_decoration_container)
	var decorator := DungeonDecorator.new()
	_braziers = decorator.decorate(_decoration_container, dungeon_data, _theme)


# A radial darkening drawn over the 3D view (behind the HUD). Strength is set to
# the theme's "lit" value here; D2 deepens it as the light fails.
func _setup_vignette() -> void:
	_vignette_rect = ColorRect.new()
	_vignette_rect.name = "Vignette"
	_vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = VignetteShader
	_vignette_mat.set_shader_parameter("edge_color", _theme.vignette_color)
	_vignette_mat.set_shader_parameter("strength", _theme.vignette_strength_lit)
	_vignette_rect.material = _vignette_mat
	$UI.add_child(_vignette_rect)
	$UI.move_child(_vignette_rect, 0)


# --- Light / darkness model -------------------------------------------------
# The party sees nothing without a light source. A lit torch burns down over a
# step budget and auto-relights from inventory; the Light spell overrides it
# (brighter, steadier, longer) and pauses the torch while it lasts.

func _init_light() -> void:
	_light_ctl = DungeonLightController.new()
	_last_light_source = -1
	# The torch casts real shadows so walls, doorways, and props throw dramatic
	# moving shadows as the party advances — a big part of the modern look.
	player_light.shadow_enabled = true
	player_light.shadow_blur = 1.5
	player_light.light_specular = 0.4
	_refresh_light_state(false)
	_snap_light()


# Jump the live light/fog/vignette straight to the current target (used on entry
# so we don't visibly lerp up from the scene defaults).
func _snap_light() -> void:
	if _light_target.is_empty():
		return
	player_light.light_energy = float(_light_target["energy"])
	player_light.omni_range = float(_light_target["range"])
	player_light.light_color = _light_target["color"]
	if _world_env and _world_env.environment:
		_world_env.environment.fog_density = float(_light_target["fog"])
	if _vignette_mat:
		_vignette_mat.set_shader_parameter("strength", float(_light_target["vignette"]))


# Recompute the active light source. With burn=true (a real step) a lit torch
# loses a step and auto-relights from inventory when spent; a Light spell shields
# the torch entirely.
func _refresh_light_state(burn: bool) -> void:
	var party := GameState.party
	if party == null:
		return
	if not _light_ctl.has_light_spell(party):
		if burn and party.torch_steps_remaining > 0:
			party.torch_steps_remaining -= 1
			if party.torch_steps_remaining == TORCH_LOW_WARNING:
				_show_dungeon_message("Your torch is burning low.")
				AudioManager.play_sfx_path(SFX_TORCH_LOW)
		if party.torch_steps_remaining <= 0:
			_attempt_relight(burn)
	var source := _light_ctl.get_source(party)
	if source != _last_light_source:
		_announce_light_change(_last_light_source, source)
		_last_light_source = source
	_apply_light_target(source)
	_refresh_light_ui()
	_update_torch_audio()


func _attempt_relight(announce: bool) -> void:
	var party := GameState.party
	if party.inventory.has_item("torch"):
		party.inventory.remove_item("torch", 1)
		var item := ShopItems.get_item("torch")
		party.torch_steps_remaining = item.burn_duration if item else 150
		AudioManager.play_sfx_path(SFX_TORCH_LIGHT)
		if announce and _last_light_source == DungeonLightController.Source.TORCH:
			_show_dungeon_message("You light a fresh torch.")


func _apply_light_target(source: int) -> void:
	_light_target = _light_ctl.target_for(source, _theme)


func _announce_light_change(old_source: int, new_source: int) -> void:
	if old_source == -1:
		return
	match new_source:
		DungeonLightController.Source.SPELL:
			_show_dungeon_message("A radiant light blooms, banishing the dark.")
		DungeonLightController.Source.TORCH:
			if old_source == DungeonLightController.Source.DARK:
				_show_dungeon_message("You strike a torch. Warm light returns.")
			else:
				_show_dungeon_message("The light fades, but your torch still burns.")
		DungeonLightController.Source.DARK:
			_show_dungeon_message("Your last light dies. Darkness swallows you.")


func _refresh_light_ui() -> void:
	if light_label == null:
		return
	var party := GameState.party
	var source := _light_ctl.get_source(party)
	match source:
		DungeonLightController.Source.SPELL:
			light_label.text = "Light  %d" % _light_spell_steps(party)
			light_label.add_theme_color_override("font_color", UIColors.MP_BLUE)
		DungeonLightController.Source.TORCH:
			light_label.text = "Torch  %d" % party.torch_steps_remaining
			var low := party.torch_steps_remaining <= TORCH_LOW_WARNING
			light_label.add_theme_color_override("font_color", UIColors.DANGER if low else UIColors.TITLE_GOLD)
		_:
			light_label.text = "In Darkness"
			light_label.add_theme_color_override("font_color", UIColors.DANGER)


func _light_spell_steps(party: Party) -> int:
	if party == null:
		return 0
	var best := 0
	for m in party.get_members():
		if not m.is_dead:
			var d := m.get_status_duration(CharacterEnums.StatusEffect.LIGHT)
			if d > best:
				best = d
	return best


# --- Audio ------------------------------------------------------------------

func _start_dungeon_audio() -> void:
	if _theme.ambient_bed != "" and ResourceLoader.exists(_theme.ambient_bed):
		AudioManager.play_ambient(load(_theme.ambient_bed))
	if _theme.music != "" and ResourceLoader.exists(_theme.music):
		AudioManager.crossfade_music(load(_theme.music), 2.0)
	_torch_audio = AudioStreamPlayer.new()
	_torch_audio.bus = "SFX"
	_torch_audio.volume_db = linear_to_db(0.3)
	if ResourceLoader.exists(SFX_TORCH_LOOP):
		var crackle := load(SFX_TORCH_LOOP)
		if crackle is AudioStreamWAV:
			var w := crackle as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = w.data.size() / 2
		_torch_audio.stream = crackle
	add_child(_torch_audio)
	_update_torch_audio()


# Crackle loops only while a real torch is the active light source.
func _update_torch_audio() -> void:
	if _torch_audio == null or _torch_audio.stream == null:
		return
	var lit := _last_light_source == DungeonLightController.Source.TORCH
	if lit and not _torch_audio.playing:
		_torch_audio.play()
	elif not lit and _torch_audio.playing:
		_torch_audio.stop()


func _play_footstep() -> void:
	var idx := randi() % SFX_FOOTSTEPS.size()
	AudioManager.play_sfx_path(SFX_FOOTSTEPS[idx], randf_range(0.95, 1.08), 0.85)


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
		DungeonTile.SpecialType.SHRINE:
			floor_item = FloorMeshItem.SHRINE
		DungeonTile.SpecialType.INSCRIPTION:
			floor_item = FloorMeshItem.INSCRIPTION
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

	previous_grid_position = grid_position
	movement.update_camera_transform()
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
			var light_tiles := player_light.omni_range / CELL_SIZE
			sprite.update_visibility(dist, light_tiles, is_revealed)

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
	print_debug("The area grows quiet...")


func _create_encounter_from_group(group: EnemyGroup) -> Dictionary:
	var enemies: Array[Monster] = []
	var is_boss := group.ai_type == EnemyGroup.AIType.BOSS
	var positions: Array[Vector2i]
	if is_boss:
		positions = EncounterGenerator.get_boss_formation_positions(group.monsters.size())
	else:
		positions = EncounterGenerator.get_formation_positions(group.monsters.size())

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
	var pending_days: int = GameState.floor_tracker.accumulated_steps / FloorTracker.STEPS_PER_DAY
	var current_day: int = GameState.game_day + pending_days
	var hours: int = (GameState.floor_tracker.accumulated_steps % FloorTracker.STEPS_PER_DAY) * 24 / FloorTracker.STEPS_PER_DAY
	time_label.text = "%s  %dh" % [GameCalendar.format_short(current_day), hours]
	if _vitals_strip:
		_vitals_strip.refresh()


func _on_step_taken(_total_steps: int) -> void:
	_tick_exploration_effects()
	_refresh_light_state(true)
	_update_ui()


func _tick_exploration_effects() -> void:
	if GameState.party == null:
		return
	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		var messages := StatusEffectSystem.tick_effects(member, "exploration")
		for msg in messages:
			_show_dungeon_message(msg)


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
	if menu_open or map_open or combat_open or event_open or is_moving:
		return

	if event is InputEventKey and event.pressed and _handle_debug_keys(event as InputEventKey):
		return

	if event.is_action_pressed("strafe_left"):
		movement.strafe_left()
	elif event.is_action_pressed("strafe_right"):
		movement.strafe_right()
	elif event.is_action_pressed("menu_up"):
		movement.move_forward()
	elif event.is_action_pressed("menu_down"):
		movement.move_backward()
	elif event.is_action_pressed("menu_left"):
		movement.turn_left()
	elif event.is_action_pressed("menu_right"):
		movement.turn_right()
	elif event.is_action_pressed("menu_confirm"):
		interaction.interact()
	elif event.is_action_pressed("menu_cancel") or event.is_action_pressed("go_to_menu"):
		_open_menu()
	elif event.is_action_pressed("toggle_map"):
		_open_map()
	elif event.is_action_pressed("go_to_town"):
		_on_town_pressed()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_X:
		_force_combat()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_G:
		_debug_add_gold()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_K:
		_debug_add_key()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_EQUAL:
		_adjust_material_normal(0.05)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_MINUS:
		_adjust_material_normal(-0.05)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_BRACKETRIGHT:
		_adjust_material_roughness(0.05)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_BRACKETLEFT:
		_adjust_material_roughness(-0.05)


func _handle_debug_keys(event: InputEventKey) -> bool:
	if not event.shift_pressed and not event.ctrl_pressed:
		return false

	if event.keycode == KEY_C and event.shift_pressed:
		GameState.show_combat_math = not GameState.show_combat_math
		_show_dungeon_message("Combat math: %s" % ("ON" if GameState.show_combat_math else "OFF"))
		return true
	elif event.keycode == KEY_X and event.shift_pressed:
		_debug_level_party(1)
		return true
	elif event.keycode == KEY_X and event.ctrl_pressed:
		_debug_level_party(5)
		return true
	elif event.keycode == KEY_F and event.shift_pressed:
		_debug_teleport_floor(GameState.current_floor + 1)
		return true
	elif event.keycode == KEY_F and event.ctrl_pressed and GameState.current_floor > 1:
		_debug_teleport_floor(GameState.current_floor - 1)
		return true
	elif event.keycode == KEY_S and event.shift_pressed:
		_run_single_simulation()
		return true
	elif event.keycode == KEY_B and event.shift_pressed:
		_run_batch_simulation()
		return true
	elif event.keycode == KEY_L and event.ctrl_pressed and not event.shift_pressed:
		_toggle_ai_logging()
		return true
	elif event.is_action_pressed("debug_force_micro_event"):
		event_handler.debug_force_micro_event()
		return true
	elif event.keycode == KEY_V and event.ctrl_pressed:
		GameState.debug_verbose = not GameState.debug_verbose
		_show_dungeon_message("Verbose debug: %s" % ("ON" if GameState.debug_verbose else "OFF"))
		return true
	elif event.keycode == KEY_TAB and event.shift_pressed:
		_cycle_debug_material()
		return true
	elif event.keycode == KEY_L and event.ctrl_pressed and event.shift_pressed:
		LLMManager.toggle_debug_fallback()
		var state := "ON (forcing fallback)" if LLMManager.debug_force_fallback else "OFF (LLM active)"
		_show_dungeon_message("LLM fallback: %s" % state)
		return true
	elif event.keycode == KEY_PERIOD and event.shift_pressed:
		_jukebox_step(1)
		return true
	elif event.keycode == KEY_COMMA and event.shift_pressed:
		_jukebox_step(-1)
		return true

	return false


# --- Music jukebox ----------------------------------------------------------

func _jukebox_step(dir: int) -> void:
	if _jukebox_tracks.is_empty():
		_scan_jukebox()
	if _jukebox_tracks.is_empty():
		_show_jukebox_label("no candidates in %s" % JUKEBOX_DIR)
		return
	_jukebox_idx = wrapi(_jukebox_idx + dir, 0, _jukebox_tracks.size())
	var path: String = _jukebox_tracks[_jukebox_idx]
	var stream: AudioStream = load(path)
	if stream:
		AudioManager.crossfade_music(stream, 0.8)
	_show_jukebox_label("%d/%d  %s" % [_jukebox_idx + 1, _jukebox_tracks.size(), path.get_file()])


func _scan_jukebox() -> void:
	_jukebox_tracks.clear()
	var dir := DirAccess.open(JUKEBOX_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var lower := fname.to_lower()
			if lower.ends_with(".ogg") or lower.ends_with(".wav") or lower.ends_with(".mp3"):
				_jukebox_tracks.append(JUKEBOX_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	_jukebox_tracks.sort()


func _show_jukebox_label(text: String) -> void:
	if _jukebox_label == null:
		_jukebox_label = Label.new()
		_jukebox_label.name = "JukeboxLabel"
		_jukebox_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
		_jukebox_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_jukebox_label.add_theme_constant_override("outline_size", 6)
		_jukebox_label.add_theme_font_size_override("font_size", 18)
		_jukebox_label.position = Vector2(24, 132)
		$UI.add_child(_jukebox_label)
	_jukebox_label.text = "♪ Jukebox  " + text


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
	print_debug("[Debug] Selected: %s (normal=%.2f, roughness=%.2f)" % [_get_debug_material_name(), mat.normal_scale, mat.roughness])


func _adjust_material_normal(delta: float) -> void:
	var mat := _get_debug_material()
	mat.normal_scale = clampf(mat.normal_scale + delta, 0.0, 2.0)
	print_debug("[Debug] %s normal_scale = %.2f" % [_get_debug_material_name(), mat.normal_scale])


func _adjust_material_roughness(delta: float) -> void:
	var mat := _get_debug_material()
	mat.roughness = clampf(mat.roughness + delta, 0.0, 1.0)
	print_debug("[Debug] %s roughness = %.2f" % [_get_debug_material_name(), mat.roughness])


func _debug_teleport_floor(target_floor: int) -> void:
	print_debug("[Debug] Teleporting to floor %d" % target_floor)
	SceneManager.go_to_dungeon(target_floor, true)


func _check_special_tile() -> void:
	var tile: DungeonTile = dungeon_data.get_tile(grid_position.x, grid_position.y)
	if tile == null:
		return

	if tile.special == DungeonTile.SpecialType.STAIRS_DOWN:
		_descend_stairs()
	elif tile.special == DungeonTile.SpecialType.STAIRS_UP:
		_ascend_stairs()
	elif tile.special == DungeonTile.SpecialType.SHRINE or tile.special == DungeonTile.SpecialType.INSCRIPTION:
		event_handler.check_narrative_tile(tile)


func _descend_stairs() -> void:
	AudioManager.play_sfx_path(SFX_STAIRS)
	var next_floor := GameState.current_floor + 1
	var event_context := {
		"party": GameState.get_party_members(),
		"floor": GameState.current_floor,
		"day": GameState.game_day,
		"is_boss": false,
		"dead_count": _count_dead(),
	}
	var event_result := EventManager.check_for_event("floor_transition", event_context)
	if not event_result.is_empty():
		event_handler.show_floor_event(event_result, next_floor, true)
		return
	MicroEventSystem.try_micro_event("floor_descent", GameState.get_party_members(), func(data: Dictionary) -> void:
		if not data.is_empty():
			event_handler.show_micro_event(data, next_floor, true)
		else:
			print_debug("Descending to floor ", next_floor)
			SceneManager.go_to_dungeon(next_floor, true)
	)


func _ascend_stairs() -> void:
	AudioManager.play_sfx_path(SFX_STAIRS)
	if GameState.current_floor <= 1:
		print_debug("Returning to town...")
		SceneManager.go_to_town()
	else:
		var prev_floor := GameState.current_floor - 1
		print_debug("Ascending to floor ", prev_floor)
		SceneManager.go_to_dungeon(prev_floor, false)


func _count_dead() -> int:
	var count := 0
	for c in GameState.get_party_members():
		if c.is_dead:
			count += 1
	return count


func _on_move_complete() -> void:
	is_moving = false
	camera.position.y = CAMERA_HEIGHT
	_play_footstep()
	_mark_current_tile_discovered()
	interaction.close_doors_behind()
	_check_special_tile()
	_process_enemy_turn()
	_update_enemy_door_visuals()
	event_handler.try_exploration_micro_event()
	_check_held_movement()


func _on_turn_complete() -> void:
	is_moving = false
	camera.rotation_degrees.y = -facing * 90.0
	_refresh_compass()
	AudioManager.play_sfx_path(SFX_TURN, randf_range(0.95, 1.05), 0.55)
	_check_held_movement()


func _check_held_movement() -> void:
	if menu_open or map_open or combat_open or event_open:
		return

	if Input.is_action_pressed("strafe_left"):
		movement.strafe_left()
	elif Input.is_action_pressed("strafe_right"):
		movement.strafe_right()
	elif Input.is_action_pressed("menu_up"):
		movement.move_forward()
	elif Input.is_action_pressed("menu_down"):
		movement.move_backward()
	elif Input.is_action_pressed("menu_left"):
		movement.turn_left()
	elif Input.is_action_pressed("menu_right"):
		movement.turn_right()


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
		var encounter := EncounterGenerator.generate_encounter()
		_open_combat(encounter)


func _force_combat() -> void:
	var encounter := EncounterGenerator.generate_encounter()
	_open_combat(encounter)


func _open_combat(encounter: Dictionary) -> void:
	if combat_open:
		return
	combat_open = true
	combat_overlay.visible = true
	if _hud_root:
		_hud_root.visible = false

	AudioManager.play_sfx_path(SFX_ENCOUNTER)
	AudioManager.stop_ambient(0.3)
	if _torch_audio:
		_torch_audio.stop()

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
			movement.update_camera_transform()
			_update_enemy_sprites()


func _close_combat() -> void:
	if not combat_open:
		return
	combat_open = false
	combat_overlay.visible = false
	if _hud_root:
		_hud_root.visible = true
	if _vitals_strip:
		_vitals_strip.refresh()
	if _theme and _theme.ambient_bed != "" and ResourceLoader.exists(_theme.ambient_bed):
		AudioManager.play_ambient(load(_theme.ambient_bed))
	_update_torch_audio()
	if combat_ui:
		combat_ui.queue_free()
		combat_ui = null


func _debug_add_gold() -> void:
	if GameState.party:
		GameState.party.gold += 1000
		print_debug("[DEBUG] Added 1000 gold. Total: %d" % GameState.party.gold)


func _debug_level_party(levels: int) -> void:
	if GameState.party == null:
		return
	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		for i in range(levels):
			member.level += 1
			member._recalculate_derived_stats()
			SpellLearning.try_learn_spells_on_level_up(member)
		var learnable := SpellLearning.get_learnable_spells(member)
		for spell in learnable:
			if not member.known_spells.has(spell.id):
				member.known_spells.append(spell.id)
		member.current_hp = member.max_hp
		member.current_mp = member.max_mp
		member.pending_level_up = false
	print_debug("[DEBUG] Party leveled up by %d. All members now:" % levels)
	for member in GameState.party.get_members():
		print_debug("  %s: Level %d, HP %d/%d, MP %d/%d" % [
			member.get_display_name(), member.level,
			member.current_hp, member.max_hp,
			member.current_mp, member.max_mp])


func _debug_add_key() -> void:
	if GameState.party:
		var key := ShopItems.get_item("dungeon_key")
		if key:
			GameState.party.inventory.add_item(key.duplicate(true) as Item)
			_show_dungeon_message("DEBUG: Added Dungeon Key")
			print_debug("[DEBUG] Added Dungeon Key. Count: %d" % GameState.party.inventory.get_item_count("dungeon_key"))


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


func _get_facing_direction_string() -> String:
	match facing:
		Facing.NORTH: return "north"
		Facing.EAST: return "east"
		Facing.SOUTH: return "south"
		Facing.WEST: return "west"
	return "north"


func _setup_chat_log() -> void:
	_chat_log = PartyChatLog.new()
	_chat_log.anchor_left = 0.15
	_chat_log.anchor_right = 0.85
	_chat_log.anchor_top = 1.0
	_chat_log.anchor_bottom = 1.0
	_chat_log.offset_top = -198
	_chat_log.offset_bottom = -82
	_chat_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chat_log.add_theme_font_size_override("normal_font_size", 13)
	_chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_chat_log)


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
	_message_label.offset_top = -150
	_message_label.offset_bottom = -120
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


func _run_single_simulation() -> void:
	if GameState.party == null:
		print_debug("[Simulation] No party available")
		return

	var encounter := EncounterGenerator.generate_encounter()
	var enemies: Array[Monster] = encounter.enemies
	var seed_value := Time.get_ticks_msec()

	var simulator := CombatSimulator.new()
	simulator.setup(GameState.party, enemies, seed_value)

	if _simulation_logging_enabled:
		simulator.ai_log = AIDecisionLog.new()

	var result := simulator.run()

	print_debug("[Simulation] Single combat result:")
	print_debug(JSON.stringify(result, "\t"))

	if _simulation_logging_enabled and simulator.ai_log != null:
		print_debug("[Simulation] AI Decision Log:")
		print_debug(simulator.ai_log.to_json())


func _run_batch_simulation() -> void:
	if GameState.party == null:
		print_debug("[Simulation] No party available")
		return

	var base_encounter := EncounterGenerator.generate_encounter()
	var enemies: Array[Monster] = base_encounter.enemies

	var batch := BatchSimulator.new()
	batch.batch_progress.connect(_on_batch_progress)

	print_debug("[Simulation] Running 100 combat simulations...")
	var result := batch.run_batch(GameState.party, enemies, 100, Time.get_ticks_msec())

	print_debug("[Simulation] Batch results:")
	print_debug("  Win rate: %.1f%%" % result.win_rate)
	print_debug("  Avg turns: %.1f" % result.avg_turns)
	print_debug("  Avg HP remaining (victories): %.1f%%" % result.avg_hp_remaining_on_victory)
	if result.most_common_cause_of_defeat != "":
		print_debug("  Most common defeat cause: %s" % result.most_common_cause_of_defeat)


func _on_batch_progress(current: int, total: int) -> void:
	if current % 10 == 0:
		print_debug("[Simulation] Progress: %d/%d" % [current, total])


func _toggle_ai_logging() -> void:
	_simulation_logging_enabled = not _simulation_logging_enabled
	var status := "ENABLED - Shift+S will include AI decision log" if _simulation_logging_enabled else "DISABLED"
	print_debug("[Simulation] AI decision logging: %s" % status)

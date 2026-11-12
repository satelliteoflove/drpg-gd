class_name FloorThemes
extends RefCounted

## The look and sound of each dungeon. A dungeon keeps one theme from its top
## floor to its master (Dungeon.theme_id), and the theme darkens and its fog
## thickens on the way down. Add a theme by writing a builder and listing it
## in _build().

const STONE_DIR := "res://textures/stone_brick_wall/"
const PAVING_DIR := "res://textures/paving_stones/PavingStones128_1K-JPG_"
const BRICKS_DIR := "res://textures/bricks/Bricks031_1K-JPG_"
const GROUND_DIR := "res://textures/Ground068/Ground068_1K-JPG_"
const ROCK_DIR := "res://textures/Rock064/Rock064_1K-JPG_"

const DEFAULT := &"stone_catacombs"
## How far the deepest floor's look moves from the top floor's.
const DEEP_TINT := 0.84
const DEEP_AMBIENT := 0.85
const DEEP_FOG := 1.15
const DEEP_VIGNETTE := 0.06

static var _cache: Dictionary = {}


## The theme [param theme_id] as it looks on [param floor] of a dungeon
## [param depth] floors deep.
static func get_theme(theme_id: StringName, floor: int = 1, depth: int = 8) -> FloorTheme:
	var deep := clampf(float(floor - 1) / float(depth - 1), 0.0, 1.0) if depth > 1 else 1.0
	var key := "%s@%.3f" % [theme_id, deep]
	if not _cache.has(key):
		_cache[key] = _at_depth(_build(theme_id), deep)
	return _cache[key]


static func _build(key: StringName) -> FloorTheme:
	match key:
		&"ashen_halls":
			return _ashen_halls()
		&"drowned_vaults":
			return _drowned_vaults()
		&"mossy_caverns":
			return _mossy_caverns()
		&"profane_crypt":
			return _profane_crypt()
		_:
			return _stone_catacombs()


## Darkens [param t] and thickens its fog by [param deep], from 0 on a
## dungeon's top floor to 1 on its deepest.
static func _at_depth(t: FloorTheme, deep: float) -> FloorTheme:
	var tint := lerpf(1.0, DEEP_TINT, deep)
	for surface in ["floor_tint", "wall_tint", "ceiling_tint", "door_tint", "prop_tint"]:
		var c: Color = t.get(surface)
		t.set(surface, Color(c.r * tint, c.g * tint, c.b * tint, c.a))
	t.ambient_energy *= lerpf(1.0, DEEP_AMBIENT, deep)
	t.fog_density_lit *= lerpf(1.0, DEEP_FOG, deep)
	t.fog_density_dark *= lerpf(1.0, DEEP_FOG, deep)
	t.vignette_strength_lit = minf(t.vignette_strength_lit + DEEP_VIGNETTE * deep, 1.0)
	return t


# --- The Drake's Deep: cold worked stone -----------------------------------
static func _stone_catacombs() -> FloorTheme:
	var t := FloorTheme.new()
	t.id = &"stone_catacombs"
	t.display_name = "Stone Catacombs"

	# Floor = flagstone paving (full PBR); walls = worked brick. Distinct surface
	# sets so the floor never reads as one texture wrapped over every face. uv 0.45
	# (a non-tile-divisor) drifts the repeat off the 2 m grid.
	t.albedo_path = PAVING_DIR + "Color.jpg"
	t.normal_path = PAVING_DIR + "NormalGL.jpg"
	t.ao_path = PAVING_DIR + "AmbientOcclusion.jpg"
	t.roughness_path = PAVING_DIR + "Roughness.jpg"
	t.uv_scale = Vector3(0.45, 0.45, 0.45)
	t.normal_strength = 1.0
	# Vendored CC0 worked stone-brick walls over the paving floor (distinct surfaces,
	# both reliable photoscan sets).
	t.wall_albedo_path = STONE_DIR + "diffuse.jpg"
	t.wall_normal_path = STONE_DIR + "normal.jpg"
	t.wall_ao_path = ""
	t.wall_roughness_path = ""
	t.wall_uv_scale = Vector3(0.37, 0.37, 0.37)

	t.floor_tint = Color(0.78, 0.78, 0.82)
	t.wall_tint = Color(0.86, 0.86, 0.9)
	t.ceiling_tint = Color(0.5, 0.5, 0.58)
	t.floor_roughness = 0.88
	t.wall_roughness = 0.84
	t.ceiling_roughness = 0.92
	t.door_tint = Color(0.85, 0.78, 0.66)

	t.ambient_color = Color(0.05, 0.055, 0.075)
	t.ambient_energy = 0.37
	t.bg_color = Color(0.035, 0.04, 0.06)
	t.torch_color = Color(1.0, 0.93, 0.8)
	t.light_spell_color = Color(0.82, 0.9, 1.0)
	t.fog_color = Color(0.15, 0.18, 0.27)
	t.fog_density_lit = 0.092
	t.fog_density_dark = 0.32
	t.vignette_color = Color(0.0, 0.0, 0.01)
	t.vignette_strength_lit = 0.34
	t.vignette_strength_dark = 0.82

	t.brazier_chance = 0.045
	t.brazier_color = Color(1.0, 0.62, 0.28)
	t.prop_set = PackedStringArray(["rubble", "cobweb"])
	t.prop_chance = 0.12
	t.prop_tint = Color(0.82, 0.82, 0.86)
	t.footstep_set = &"stone"
	t.ambient_bed = "res://audio/ambient/ambient_catacombs.wav"
	t.music = "res://audio/music/music_catacombs.wav"
	return t


# --- The Ashen Halls: burnt brick, smoke and ember light --------------------
static func _ashen_halls() -> FloorTheme:
	var t := FloorTheme.new()
	t.id = &"ashen_halls"
	t.display_name = "Ashen Halls"

	# Brick over flagstone. The wall tint leans cool to take some red out of the
	# brick, and the warmth comes from the smoke and the ember-red braziers.
	t.albedo_path = PAVING_DIR + "Color.jpg"
	t.normal_path = PAVING_DIR + "NormalGL.jpg"
	t.ao_path = PAVING_DIR + "AmbientOcclusion.jpg"
	t.roughness_path = PAVING_DIR + "Roughness.jpg"
	t.uv_scale = Vector3(0.45, 0.45, 0.45)
	t.normal_strength = 1.0
	t.wall_albedo_path = BRICKS_DIR + "Color.jpg"
	t.wall_normal_path = BRICKS_DIR + "NormalGL.jpg"
	t.wall_ao_path = BRICKS_DIR + "AmbientOcclusion.jpg"
	t.wall_roughness_path = BRICKS_DIR + "Roughness.jpg"
	t.wall_uv_scale = Vector3(0.36, 0.36, 0.36)

	t.floor_tint = Color(0.62, 0.58, 0.55)
	t.wall_tint = Color(0.72, 0.75, 0.74)
	t.ceiling_tint = Color(0.3, 0.28, 0.27)
	t.floor_roughness = 0.92
	t.wall_roughness = 0.9
	t.ceiling_roughness = 0.95
	t.door_tint = Color(0.42, 0.36, 0.32)

	t.ambient_color = Color(0.075, 0.05, 0.035)
	t.ambient_energy = 0.36
	t.bg_color = Color(0.05, 0.032, 0.022)
	t.torch_color = Color(1.0, 0.84, 0.62)
	t.light_spell_color = Color(1.0, 0.92, 0.8)
	t.fog_color = Color(0.24, 0.15, 0.09)
	t.fog_density_lit = 0.1
	t.fog_density_dark = 0.34
	t.vignette_color = Color(0.03, 0.01, 0.0)
	t.vignette_strength_lit = 0.4
	t.vignette_strength_dark = 0.86

	t.brazier_chance = 0.09
	t.brazier_color = Color(1.0, 0.4, 0.14)
	t.prop_set = PackedStringArray(["rubble", "bones"])
	t.prop_chance = 0.16
	t.prop_tint = Color(0.5, 0.5, 0.5)
	t.footstep_set = &"stone"
	t.ambient_bed = "res://audio/ambient/ambient_crypt.wav"
	# Not yet chosen by ear: a candidate from the audition pool.
	t.music = "res://audio/music/candidates/cat_loopable_dungeon_jaggedstone.ogg"
	return t


# --- The Drowned Vaults: flooded stonework, cold light on wet floors --------
static func _drowned_vaults() -> FloorTheme:
	var t := FloorTheme.new()
	t.id = &"drowned_vaults"
	t.display_name = "Drowned Vaults"

	# The same worked stone as the catacombs, under water for an age: a wet
	# floor that catches the light, blue-green stone, pale corpse-light in the
	# braziers.
	t.albedo_path = PAVING_DIR + "Color.jpg"
	t.normal_path = PAVING_DIR + "NormalGL.jpg"
	t.ao_path = PAVING_DIR + "AmbientOcclusion.jpg"
	t.roughness_path = ""
	t.uv_scale = Vector3(0.45, 0.45, 0.45)
	t.normal_strength = 0.8
	t.wall_albedo_path = STONE_DIR + "diffuse.jpg"
	t.wall_normal_path = STONE_DIR + "normal.jpg"
	t.wall_uv_scale = Vector3(0.37, 0.37, 0.37)

	t.floor_tint = Color(0.5, 0.76, 0.84)
	t.wall_tint = Color(0.72, 0.95, 1.0)
	t.ceiling_tint = Color(0.3, 0.44, 0.5)
	t.floor_roughness = 0.2
	t.floor_wet = true
	t.wall_roughness = 0.84
	t.ceiling_roughness = 0.9
	t.door_tint = Color(0.45, 0.58, 0.6)

	t.ambient_color = Color(0.03, 0.06, 0.085)
	t.ambient_energy = 0.4
	t.bg_color = Color(0.02, 0.04, 0.06)
	t.torch_color = Color(0.96, 0.95, 0.88)
	t.light_spell_color = Color(0.72, 0.9, 1.0)
	t.fog_color = Color(0.07, 0.17, 0.28)
	t.fog_density_lit = 0.11
	t.fog_density_dark = 0.36
	t.vignette_color = Color(0.0, 0.01, 0.03)
	t.vignette_strength_lit = 0.42
	t.vignette_strength_dark = 0.88

	t.brazier_chance = 0.02
	t.brazier_color = Color(0.5, 0.92, 0.86)
	t.prop_set = PackedStringArray(["puddle", "rubble"])
	t.prop_chance = 0.2
	t.prop_tint = Color(0.5, 0.66, 0.72)
	t.footstep_set = &"wet"
	t.ambient_bed = "res://audio/ambient/ambient_caverns.wav"
	# Not yet chosen by ear: a candidate from the audition pool.
	t.music = "res://audio/music/candidates/cav_dark_cavern_wortmann.ogg"
	return t


# --- The Verdant Dark: damp living caverns, moss and standing water --------
static func _mossy_caverns() -> FloorTheme:
	var t := FloorTheme.new()
	t.id = &"mossy_caverns"
	t.display_name = "Mossy Caverns"

	# Real CC0 photoscan PBR (ambientCG): mossy rock walls over mossy ground. The
	# textures already carry their own moss colour, so tints stay near-neutral
	# (over-tinting green is what made the noise-generated set read as flat marble).
	t.albedo_path = GROUND_DIR + "Color.jpg"
	t.normal_path = GROUND_DIR + "NormalGL.jpg"
	t.ao_path = GROUND_DIR + "AmbientOcclusion.jpg"
	t.roughness_path = GROUND_DIR + "Roughness.jpg"
	t.uv_scale = Vector3(0.45, 0.45, 0.45)
	t.normal_strength = 1.2
	t.wall_albedo_path = ROCK_DIR + "Color.jpg"
	t.wall_normal_path = ROCK_DIR + "NormalGL.jpg"
	t.wall_ao_path = ROCK_DIR + "AmbientOcclusion.jpg"
	t.wall_roughness_path = ROCK_DIR + "Roughness.jpg"
	t.wall_uv_scale = Vector3(0.4, 0.4, 0.4)

	# Near-neutral, but pull the red channel down so the rusty ambientCG ground
	# reads as damp earth/moss rather than orange rust.
	t.floor_tint = Color(0.58, 0.82, 0.72)
	t.wall_tint = Color(0.88, 0.94, 0.82)
	t.ceiling_tint = Color(0.38, 0.46, 0.42)
	t.floor_roughness = 0.78
	t.wall_roughness = 0.82
	t.ceiling_roughness = 0.9
	t.door_tint = Color(0.6, 0.62, 0.5)

	t.ambient_color = Color(0.04, 0.07, 0.055)
	t.ambient_energy = 0.39
	t.bg_color = Color(0.03, 0.05, 0.04)
	t.torch_color = Color(1.0, 0.9, 0.74)
	t.light_spell_color = Color(0.78, 0.95, 0.92)
	t.fog_color = Color(0.1, 0.19, 0.14)
	t.fog_density_lit = 0.1
	t.fog_density_dark = 0.34
	t.vignette_color = Color(0.0, 0.02, 0.01)
	t.vignette_strength_lit = 0.40
	t.vignette_strength_dark = 0.86

	t.brazier_chance = 0.03
	t.brazier_color = Color(1.0, 0.66, 0.32)
	t.prop_set = PackedStringArray(["rubble", "fungi", "puddle"])
	t.prop_chance = 0.15
	t.prop_tint = Color(0.62, 0.72, 0.58)
	t.footstep_set = &"wet"
	t.ambient_bed = "res://audio/ambient/ambient_caverns.wav"
	t.music = "res://audio/music/music_caverns.wav"
	return t


# --- The Heart Below: the profane crypt, old blood and bone ----------------
static func _profane_crypt() -> FloorTheme:
	var t := FloorTheme.new()
	t.id = &"profane_crypt"
	t.display_name = "Profane Crypt"

	# Floor = paving; walls = brick (Bricks031). Oppressive deep-red tint sets the
	# crypt apart from the caverns despite the shared brick wall set.
	t.albedo_path = PAVING_DIR + "Color.jpg"
	t.normal_path = PAVING_DIR + "NormalGL.jpg"
	t.ao_path = PAVING_DIR + "AmbientOcclusion.jpg"
	t.roughness_path = PAVING_DIR + "Roughness.jpg"
	t.uv_scale = Vector3(0.45, 0.45, 0.45)
	t.normal_strength = 1.0
	t.wall_albedo_path = BRICKS_DIR + "Color.jpg"
	t.wall_normal_path = BRICKS_DIR + "NormalGL.jpg"
	t.wall_ao_path = BRICKS_DIR + "AmbientOcclusion.jpg"
	t.wall_roughness_path = BRICKS_DIR + "Roughness.jpg"
	t.wall_uv_scale = Vector3(0.36, 0.36, 0.36)

	t.floor_tint = Color(0.5, 0.4, 0.42)
	t.wall_tint = Color(0.6, 0.42, 0.42)
	t.ceiling_tint = Color(0.26, 0.2, 0.22)
	t.floor_roughness = 0.82
	t.wall_roughness = 0.8
	t.ceiling_roughness = 0.9
	t.door_tint = Color(0.55, 0.4, 0.38)

	t.ambient_color = Color(0.06, 0.03, 0.035)
	t.ambient_energy = 0.33
	t.bg_color = Color(0.05, 0.025, 0.03)
	t.torch_color = Color(1.0, 0.78, 0.62)
	t.light_spell_color = Color(0.95, 0.82, 0.92)
	t.fog_color = Color(0.19, 0.085, 0.12)
	t.fog_density_lit = 0.095
	t.fog_density_dark = 0.36
	t.vignette_color = Color(0.02, 0.0, 0.005)
	t.vignette_strength_lit = 0.45
	t.vignette_strength_dark = 0.9

	t.brazier_chance = 0.05
	t.brazier_color = Color(1.0, 0.5, 0.32)
	t.prop_set = PackedStringArray(["bones", "cobweb", "rubble"])
	t.prop_chance = 0.16
	t.prop_tint = Color(0.6, 0.5, 0.5)
	t.footstep_set = &"stone"
	t.ambient_bed = "res://audio/ambient/ambient_crypt.wav"
	t.music = "res://audio/music/music_crypt.wav"
	return t

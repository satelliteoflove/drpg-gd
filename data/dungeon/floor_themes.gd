class_name FloorThemes
extends RefCounted

## Maps a floor number to its FloorTheme. Themes are built once and cached. The
## three shipped biomes are drawn from the three PBR texture sets already in the
## repo; the band thresholds line up with the monster/boss progression in
## MonsterDatabase (bosses on 2/4/6/8). Add a biome by writing a builder and
## extending get_theme().

const STONE_DIR := "res://textures/stone_brick_wall/"
const PAVING_DIR := "res://textures/paving_stones/PavingStones128_1K-JPG_"
const BRICKS_DIR := "res://textures/bricks/Bricks031_1K-JPG_"

static var _cache: Dictionary = {}


static func get_theme(floor: int) -> FloorTheme:
	var key := _band_key(floor)
	if not _cache.has(key):
		_cache[key] = _build(key)
	return _cache[key]


static func _band_key(floor: int) -> StringName:
	if floor <= 3:
		return &"stone_catacombs"
	elif floor <= 6:
		return &"mossy_caverns"
	return &"profane_crypt"


static func _build(key: StringName) -> FloorTheme:
	match key:
		&"mossy_caverns":
			return _mossy_caverns()
		&"profane_crypt":
			return _profane_crypt()
		_:
			return _stone_catacombs()


# --- Floors 1-3: cold worked stone, the shallow catacombs ------------------
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


# --- Floors 4-6: damp living caverns, moss and standing water -------------
static func _mossy_caverns() -> FloorTheme:
	var t := FloorTheme.new()
	t.id = &"mossy_caverns"
	t.display_name = "Mossy Caverns"

	# Real CC0 photoscan PBR (ambientCG): mossy rock walls over mossy ground. The
	# textures already carry their own moss colour, so tints stay near-neutral
	# (over-tinting green is what made the noise-generated set read as flat marble).
	t.albedo_path = "res://textures/Ground068/Ground068_1K-JPG_Color.jpg"
	t.normal_path = "res://textures/Ground068/Ground068_1K-JPG_NormalGL.jpg"
	t.ao_path = "res://textures/Ground068/Ground068_1K-JPG_AmbientOcclusion.jpg"
	t.roughness_path = "res://textures/Ground068/Ground068_1K-JPG_Roughness.jpg"
	t.uv_scale = Vector3(0.45, 0.45, 0.45)
	t.normal_strength = 1.2
	t.wall_albedo_path = "res://textures/Rock064/Rock064_1K-JPG_Color.jpg"
	t.wall_normal_path = "res://textures/Rock064/Rock064_1K-JPG_NormalGL.jpg"
	t.wall_ao_path = "res://textures/Rock064/Rock064_1K-JPG_AmbientOcclusion.jpg"
	t.wall_roughness_path = "res://textures/Rock064/Rock064_1K-JPG_Roughness.jpg"
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


# --- Floors 7+: the profane crypt, old blood and bone ----------------------
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

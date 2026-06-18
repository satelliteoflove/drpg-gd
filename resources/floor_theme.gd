class_name FloorTheme
extends Resource

## A floor's complete sensory identity — the surface texture set + tints, the
## atmosphere (ambient, fog, torch colour, vignette), the decoration mix, and the
## soundscape. One theme covers a band of floors (see FloorThemes). Adding a new
## biome is pure data: fill one of these out and register it.
##
## Only the surfaces + atmosphere are consumed in D1; the decoration and audio
## fields are read by later phases (props, generated sound) — they carry sane
## defaults so nothing breaks before then.

@export var id: StringName = &"stone_catacombs"
@export var display_name: String = "Stone Catacombs"

# --- Surfaces -------------------------------------------------------------
# One PBR texture set shared by floor/wall/ceiling, differentiated by tint and
# per-surface roughness. Paths may be "" (a map the set doesn't ship).
@export var albedo_path: String = "res://textures/stone_brick_wall/diffuse.jpg"
@export var normal_path: String = "res://textures/stone_brick_wall/normal.jpg"
@export var ao_path: String = ""
@export var roughness_path: String = ""
@export var uv_scale: Vector3 = Vector3(0.5, 0.5, 0.5)
@export var normal_strength: float = 0.8

@export var floor_tint: Color = Color.WHITE
@export var wall_tint: Color = Color.WHITE
@export var ceiling_tint: Color = Color(0.6, 0.6, 0.65)
@export var floor_roughness: float = 0.85
@export var wall_roughness: float = 0.85
@export var ceiling_roughness: float = 0.9

# Optional per-surface texture overrides. The primary set above is the FLOOR set;
# walls and the ceiling fall back to it when these are left blank. Giving walls
# their own set (e.g. brick over a flagstone floor) is what stops a floor from
# reading as the same tile stamped on every surface. uv_scale of ZERO means
# "reuse the floor uv_scale".
@export_group("Wall texture override")
@export var wall_albedo_path: String = ""
@export var wall_normal_path: String = ""
@export var wall_ao_path: String = ""
@export var wall_roughness_path: String = ""
@export var wall_uv_scale: Vector3 = Vector3.ZERO
@export_group("Ceiling texture override")
@export var ceiling_albedo_path: String = ""
@export var ceiling_normal_path: String = ""
@export var ceiling_ao_path: String = ""
@export var ceiling_roughness_path: String = ""
@export var ceiling_uv_scale: Vector3 = Vector3.ZERO
@export_group("")

# Stairs reuse the floor set, retinted so they read at a glance.
@export var stairs_up_tint: Color = Color(0.7, 0.9, 0.7)
@export var stairs_down_tint: Color = Color(0.95, 0.7, 0.65)
@export var shrine_color: Color = Color(0.6, 0.5, 0.2)
@export var inscription_color: Color = Color(0.3, 0.4, 0.5)

# Doors (own set, theme-tinted).
@export var door_albedo: String = "res://textures/door/diffuse.png"
@export var door_normal: String = "res://textures/door/normal.png"
@export var door_tint: Color = Color.WHITE

# --- Atmosphere -----------------------------------------------------------
@export var ambient_color: Color = Color(0.05, 0.05, 0.08)
@export var ambient_energy: float = 0.3
@export var bg_color: Color = Color(0.02, 0.02, 0.03)
# Player torch colour tint (the light controller multiplies its base by this).
@export var torch_color: Color = Color(1.0, 0.95, 0.85)
@export var light_spell_color: Color = Color(0.82, 0.9, 1.0)

# Built-in exponential fog. Density is the real "can't see far" enforcer; the
# light controller lerps between the dark/lit values by current light strength.
@export var fog_color: Color = Color(0.04, 0.04, 0.06)
@export var fog_density_lit: float = 0.035
@export var fog_density_dark: float = 0.22
@export var vignette_color: Color = Color(0.0, 0.0, 0.0)
@export var vignette_strength_lit: float = 0.45
@export var vignette_strength_dark: float = 0.85

# --- Decoration (D3) ------------------------------------------------------
# Per-walkable-tile chance for a wall brazier; prop_set names drive scatter.
@export var brazier_chance: float = 0.05
@export var brazier_color: Color = Color(1.0, 0.6, 0.25)
@export var prop_set: PackedStringArray = PackedStringArray(["rubble", "pillar"])
@export var prop_chance: float = 0.10
@export var prop_tint: Color = Color.WHITE

# --- Audio (D4) -----------------------------------------------------------
@export var ambient_bed: String = ""
@export var music: String = ""
@export var footstep_set: StringName = &"stone"


# --- Resolved texture sets (one dict per surface) --------------------------
# Returned to the material builder so each surface can carry its own PBR set.
# Walls/ceiling fall back to the floor set when no override is given.

func floor_textures() -> Dictionary:
	return {
		"albedo": albedo_path, "normal": normal_path, "ao": ao_path,
		"roughness": roughness_path, "uv_scale": uv_scale,
		"normal_strength": normal_strength,
	}


func wall_textures() -> Dictionary:
	if wall_albedo_path == "":
		return floor_textures()
	return {
		"albedo": wall_albedo_path, "normal": wall_normal_path, "ao": wall_ao_path,
		"roughness": wall_roughness_path,
		"uv_scale": wall_uv_scale if wall_uv_scale != Vector3.ZERO else uv_scale,
		"normal_strength": normal_strength,
	}


func ceiling_textures() -> Dictionary:
	if ceiling_albedo_path == "":
		return floor_textures()
	return {
		"albedo": ceiling_albedo_path, "normal": ceiling_normal_path,
		"ao": ceiling_ao_path, "roughness": ceiling_roughness_path,
		"uv_scale": ceiling_uv_scale if ceiling_uv_scale != Vector3.ZERO else uv_scale,
		"normal_strength": normal_strength,
	}

class_name DungeonDecorator
extends RefCounted

## Scatters code-built decoration into the dungeon to sell the fiction: wall
## braziers (their own light pools), pillars in great halls, floor rubble, corner
## cobwebs, and theme accents (bone piles in the crypt, glowing fungi / puddles in
## the caverns). Placement is deterministic (seeded by the floor's seed) and
## capped so a floor looks the same each visit and the node/light count stays
## bounded. Props are visual only — movement still keys off the wall data.

const CELL := 2.0
const WALL_OFFSET := CELL * 0.5 - 0.08
# World-space Y of the floor surface (see _tile_center): cell-center offset (1.0)
# plus half the 0.1 m floor slab.
const FLOOR_Y := CELL * 0.5 + 0.05

const MAX_BRAZIERS := 16
const MAX_FLOOR_PROPS := 30
const MAX_COBWEBS := 22

# Real CC0 mushroom mesh (Kenney Nature Kit) for the cavern fungi. Single variant
# at a fixed scale — the multi-mesh "group" variants broke AABB auto-scaling.
const FUNGI_MODEL := "res://models/nature/mushroom_tan.glb"
const FUNGI_NATIVE_H := 0.154  # AABB height of the model at scale 1 (measured)

var _rng := RandomNumberGenerator.new()
var _dir_off := {0: Vector2i(0, -1), 1: Vector2i(1, 0), 2: Vector2i(0, 1), 3: Vector2i(-1, 0)}
var _dir_name := {0: "north", 1: "east", 2: "south", 3: "west"}

var _rubble_mat: StandardMaterial3D = null
var _cobweb_mat: StandardMaterial3D = null
var _bone_mat: StandardMaterial3D = null
var _socket_mat: StandardMaterial3D = null
var _puddle_mat: StandardMaterial3D = null


## Populates `container` and returns the array of WallTorch nodes (so the dungeon
## can manage their lights if needed).
func decorate(container: Node3D, dungeon_data: DungeonData, theme: FloorTheme) -> Array:
	_rng.seed = dungeon_data.seed_value ^ 0x5EED1A
	_build_materials(theme)
	var braziers: Array = []
	_place_braziers(container, dungeon_data, theme, braziers)
	_place_floor_clutter(container, dungeon_data, theme)
	_place_cobwebs(container, dungeon_data, theme)
	return braziers


# --- Placement --------------------------------------------------------------

func _place_braziers(container: Node3D, dd: DungeonData, theme: FloorTheme, out_braziers: Array) -> void:
	var candidates: Array = []
	for y in range(dd.height):
		for x in range(dd.width):
			var tile := dd.get_tile(x, y)
			if tile == null or not tile.is_walkable():
				continue
			for f in [0, 1, 2, 3]:
				if tile.get_wall_type(_dir_name[f]) == DungeonTile.WallType.SOLID:
					candidates.append({"pos": Vector2i(x, y), "dir": f})
	_shuffle(candidates)
	var target: int = clampi(int(candidates.size() * theme.brazier_chance), 6, MAX_BRAZIERS)
	target = mini(target, candidates.size())
	for i in range(target):
		var c: Dictionary = candidates[i]
		var off: Vector2i = _dir_off[c.dir]
		var torch := WallTorch.new()
		torch.position = _tile_center(c.pos.x, c.pos.y, 1.6) + Vector3(off.x, 0, off.y) * WALL_OFFSET
		container.add_child(torch)
		torch.setup(theme.brazier_color)
		out_braziers.append(torch)


func _place_floor_clutter(container: Node3D, dd: DungeonData, theme: FloorTheme) -> void:
	var types: Array = []
	for t in ["rubble", "bones", "fungi", "puddle"]:
		if t in theme.prop_set:
			types.append(t)
	if types.is_empty():
		return
	var candidates: Array = []
	for y in range(dd.height):
		for x in range(dd.width):
			var tile := dd.get_tile(x, y)
			if tile == null or not tile.is_walkable():
				continue
			if tile.special != DungeonTile.SpecialType.NONE:
				continue
			candidates.append(Vector2i(x, y))
	_shuffle(candidates)
	var target: int = clampi(int(candidates.size() * theme.prop_chance), 0, MAX_FLOOR_PROPS)
	target = mini(target, candidates.size())
	for i in range(target):
		var pos2: Vector2i = candidates[i]
		var kind: String = types[_rng.randi() % types.size()]
		var node := _make_floor_prop(kind)
		if node == null:
			continue
		var ox := _rng.randf_range(-0.45, 0.45)
		var oz := _rng.randf_range(-0.45, 0.45)
		node.position = _tile_center(pos2.x, pos2.y, 0.05) + Vector3(ox, 0, oz)
		node.rotation.y = _rng.randf_range(0.0, TAU)
		container.add_child(node)


func _place_cobwebs(container: Node3D, dd: DungeonData, theme: FloorTheme) -> void:
	if not ("cobweb" in theme.prop_set):
		return
	var candidates: Array = []
	for y in range(dd.height):
		for x in range(dd.width):
			var tile := dd.get_tile(x, y)
			if tile == null or not tile.is_walkable():
				continue
			var pair := _corner_dirs(tile)
			if pair.is_empty():
				continue
			candidates.append({"pos": Vector2i(x, y), "dirs": pair})
	_shuffle(candidates)
	var target: int = clampi(int(candidates.size() * 0.3), 0, MAX_COBWEBS)
	target = mini(target, candidates.size())
	for i in range(target):
		var c: Dictionary = candidates[i]
		var d1: Vector2i = _dir_off[c.dirs[0]]
		var d2: Vector2i = _dir_off[c.dirs[1]]
		var corner := Vector3(d1.x + d2.x, 0, d1.y + d2.y).normalized()
		var web := _make_cobweb()
		web.position = _tile_center(c.pos.x, c.pos.y, 2.05) + corner * (CELL * 0.4)
		web.rotation = Vector3(deg_to_rad(40), atan2(-corner.x, -corner.z), 0.0)
		container.add_child(web)


# --- Prop builders ----------------------------------------------------------

func _make_floor_prop(kind: String) -> Node3D:
	match kind:
		"bones":
			return _make_bones()
		"fungi":
			return _make_fungi()
		"puddle":
			return _make_puddle()
		_:
			return _make_rubble()


func _make_rubble() -> Node3D:
	var n := Node3D.new()
	for i in range(_rng.randi_range(2, 4)):
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(_rng.randf_range(0.15, 0.4), _rng.randf_range(0.1, 0.3), _rng.randf_range(0.15, 0.4))
		b.mesh = bm
		b.material_override = _rubble_mat
		b.position = Vector3(_rng.randf_range(-0.25, 0.25), bm.size.y * 0.5, _rng.randf_range(-0.25, 0.25))
		b.rotation.y = _rng.randf_range(0.0, TAU)
		n.add_child(b)
	return n


func _make_bones() -> Node3D:
	var n := Node3D.new()
	# Long bones: capsules (rounded ends) laid flat read as bones far better than
	# thin boxes did.
	for i in range(_rng.randi_range(2, 3)):
		var b := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.026
		cap.height = _rng.randf_range(0.22, 0.36)
		cap.radial_segments = 6
		cap.rings = 2
		b.mesh = cap
		b.material_override = _bone_mat
		b.position = Vector3(_rng.randf_range(-0.22, 0.22), 0.026, _rng.randf_range(-0.22, 0.22))
		# Capsules stand up by default — tip flat onto the floor, random yaw.
		b.rotation = Vector3(deg_to_rad(90), _rng.randf_range(0.0, TAU), 0.0)
		n.add_child(b)
	# Skull: a slightly egg-shaped cranium + a small jaw + two dark eye sockets.
	var skull := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.075
	sm.height = 0.15
	sm.radial_segments = 12
	sm.rings = 7
	skull.mesh = sm
	skull.material_override = _bone_mat
	skull.scale = Vector3(1.0, 0.95, 1.12)
	var syaw := _rng.randf_range(0.0, TAU)
	skull.position = Vector3(_rng.randf_range(-0.14, 0.14), 0.07, _rng.randf_range(-0.14, 0.14))
	skull.rotation.y = syaw
	n.add_child(skull)
	var jaw := MeshInstance3D.new()
	var jm := BoxMesh.new()
	jm.size = Vector3(0.09, 0.03, 0.06)
	jaw.mesh = jm
	jaw.material_override = _bone_mat
	jaw.position = Vector3(0, -0.055, 0.04)
	skull.add_child(jaw)
	for sx in [-0.032, 0.032]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.02
		em.height = 0.04
		eye.mesh = em
		eye.material_override = _socket_mat
		eye.scale = Vector3(1.0, 1.0, 0.5)
		eye.position = Vector3(sx, 0.01, 0.066)
		skull.add_child(eye)
	return n


func _make_fungi() -> Node3D:
	var n := Node3D.new()
	var scene := load(FUNGI_MODEL) as PackedScene
	if scene == null:
		return n
	# A small patch of 2-4 mushrooms, each scaled from the model's measured native
	# height to ~0.4-0.7 m (a clear small mushroom you'd step around). Fixed scale,
	# not the recursive AABB auto-scale that mis-sized multi-mesh variants to nothing.
	for i in range(_rng.randi_range(2, 4)):
		var model := scene.instantiate() as Node3D
		var s := _rng.randf_range(0.4, 0.7) / FUNGI_NATIVE_H
		model.scale = Vector3(s, s, s)
		model.position = Vector3(_rng.randf_range(-0.45, 0.45), 0.0, _rng.randf_range(-0.45, 0.45))
		model.rotation.y = _rng.randf_range(0.0, TAU)
		# Keep the model's own texture (tan cap / pale stem) — overpainting it with a
		# flat emissive colour threw away the detail we sourced a real model for. The
		# bioluminescence comes from the glow light below catching the caps instead.
		n.add_child(model)
	# Soft warm amber glow that matches the mushrooms' own tan skin (a violet light
	# turned the pale stems magenta and blew out the cap tops). Seated just ABOVE the
	# caps and dim, so it lights them naturally instead of over-exposing surfaces it
	# sits inside. Shadow + distance-fade keep it in its own room (same as braziers).
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.72, 0.4)
	glow.light_energy = 0.45
	glow.omni_range = 2.8
	glow.omni_attenuation = 1.8
	glow.position = Vector3(0, 0.6, 0)
	glow.shadow_enabled = true
	glow.distance_fade_enabled = true
	glow.distance_fade_shadow = 8.0
	glow.distance_fade_begin = 13.0
	glow.distance_fade_length = 4.0
	n.add_child(glow)
	return n


func _make_puddle() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(_rng.randf_range(0.8, 1.4), _rng.randf_range(0.8, 1.4))
	m.mesh = q
	m.material_override = _puddle_mat
	return m


func _make_cobweb() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(_rng.randf_range(0.4, 0.7), _rng.randf_range(0.4, 0.7))
	m.mesh = q
	m.material_override = _cobweb_mat
	return m


# --- Helpers ----------------------------------------------------------------

func _build_materials(theme: FloorTheme) -> void:
	# Rubble = broken chunks of the local environment, so it wears the theme's own
	# WALL texture set (fallen stone / brick / rock) — cohesive with the room and free
	# (reuses the per-surface PBR system, no new assets). The tint keeps it reading
	# against the dim, torch-warmed floor.
	_rubble_mat = StandardMaterial3D.new()
	_rubble_mat.albedo_color = theme.prop_tint.lightened(0.05)
	_rubble_mat.roughness = 1.0
	_apply_pbr(_rubble_mat, theme.wall_textures())

	# Real spiderweb texture (generated, alpha-cut threads) instead of a blank
	# translucent quad. Unshaded so the pale threads stay visible in the gloom.
	_cobweb_mat = StandardMaterial3D.new()
	_cobweb_mat.albedo_color = Color(0.85, 0.85, 0.9, 0.85)
	_cobweb_mat.albedo_texture = load("res://textures/props/cobweb.png")
	_cobweb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cobweb_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cobweb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cobweb_mat.roughness = 1.0

	_bone_mat = StandardMaterial3D.new()
	_bone_mat.albedo_color = Color(0.82, 0.79, 0.69)
	_bone_mat.roughness = 0.8

	# Recessed eye sockets — near-black matte so they read as dark holes in the skull.
	_socket_mat = StandardMaterial3D.new()
	_socket_mat.albedo_color = Color(0.03, 0.03, 0.035)
	_socket_mat.roughness = 1.0

	# Wet, reflective water: dark albedo + low (but not mirror-sharp) roughness so it
	# catches a blurred sheen of the torchlit walls (via SSR) and reads as standing
	# water rather than a perfect mirror or a black hole.
	_puddle_mat = StandardMaterial3D.new()
	_puddle_mat.albedo_color = Color(0.04, 0.05, 0.06, 1.0)
	_puddle_mat.metallic = 0.3
	_puddle_mat.metallic_specular = 0.9
	_puddle_mat.roughness = 0.12
	_puddle_mat.rim_enabled = true
	_puddle_mat.rim = 0.4


## Applies a resolved PBR texture dict (from FloorTheme.*_textures()) onto a
## material. Paths may be "" (the set doesn't ship that map) and are skipped.
func _apply_pbr(mat: StandardMaterial3D, tex: Dictionary) -> void:
	if tex.get("albedo", "") != "":
		mat.albedo_texture = load(tex["albedo"])
	if tex.get("normal", "") != "":
		mat.normal_enabled = true
		mat.normal_texture = load(tex["normal"])
	if tex.get("roughness", "") != "":
		mat.roughness_texture = load(tex["roughness"])
	if tex.get("ao", "") != "":
		mat.ao_enabled = true
		mat.ao_texture = load(tex["ao"])


func _tile_center(x: int, y: int, h: float) -> Vector3:
	# The floor GridMap uses cell_center_y with a 2 m cell, so a floor cell's
	# surface sits at world y = CELL*0.5 + half the 0.1 m floor slab = 1.05, NOT
	# y=0. Props are positioned by height-ABOVE-floor (h); without this offset every
	# floor prop spawned ~1 m UNDER the floor slab — the long-hunted "invisible
	# decoration" bug (fungi, rubble, bones all buried; only their glow leaked up).
	return Vector3(x * CELL + CELL * 0.5, FLOOR_Y + h, y * CELL + CELL * 0.5)


func _corner_dirs(tile: DungeonTile) -> Array:
	var v := -1
	if tile.get_wall_type("north") == DungeonTile.WallType.SOLID:
		v = 0
	elif tile.get_wall_type("south") == DungeonTile.WallType.SOLID:
		v = 2
	var h := -1
	if tile.get_wall_type("east") == DungeonTile.WallType.SOLID:
		h = 1
	elif tile.get_wall_type("west") == DungeonTile.WallType.SOLID:
		h = 3
	if v >= 0 and h >= 0:
		return [v, h]
	return []


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

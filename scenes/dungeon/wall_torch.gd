class_name WallTorch
extends Node3D

## A code-built wall brazier: a dark bracket, an emissive flame, and a warm,
## flickering OmniLight. Scattered on dungeon walls by DungeonDecorator, these
## cast their own pools of light independent of the party's torch — so in the
## dark you glimpse a lit alcove up ahead and walk toward it. The flame stays
## visible at distance (a glowing point in the murk); the light pool reads once
## you are near.

const FLICKER_SPEED := 9.0

var _light: OmniLight3D = null
var _flame: MeshInstance3D = null
var _flicker_t := 0.0
var _base_energy := 1.7


func setup(color: Color) -> void:
	var bracket := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(0.07, 0.5, 0.07)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.08, 0.06, 0.05)
	bmat.roughness = 0.95
	bracket.mesh = bmesh
	bracket.material_override = bmat
	add_child(bracket)

	_flame = MeshInstance3D.new()
	var fmesh := SphereMesh.new()
	fmesh.radius = 0.085
	fmesh.height = 0.24
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = color
	fmat.emission_enabled = true
	fmat.emission = color
	fmat.emission_energy_multiplier = 4.0
	_flame.mesh = fmesh
	_flame.material_override = fmat
	_flame.position = Vector3(0, 0.3, 0)
	add_child(_flame)

	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = 5.5
	_light.omni_attenuation = 1.3
	_light.light_energy = _base_energy
	_light.position = Vector3(0, 0.32, 0)
	# Cast shadows so the brazier's glow doesn't bleed through the thin walls into
	# the next room. Distance-fade the shadow (and then the light) so only the few
	# braziers near the party actually render a shadow map — bounds the cost of
	# having ~16 of them on a floor.
	_light.shadow_enabled = true
	_light.shadow_blur = 2.0
	# Don't crush everything the brazier can't directly reach to pure black. At
	# depth, braziers are ambiance — not a torch substitute — so the shadow should
	# read as mood, letting the ambient fill it, not as a hard black cliff.
	_light.shadow_opacity = 0.5
	_light.light_specular = 0.2
	_light.distance_fade_enabled = true
	_light.distance_fade_shadow = 9.0
	_light.distance_fade_begin = 16.0
	_light.distance_fade_length = 5.0
	add_child(_light)


func _process(delta: float) -> void:
	if _light == null:
		return
	_flicker_t += delta * FLICKER_SPEED
	var f := sin(_flicker_t) * 0.5 + sin(_flicker_t * 2.7) * 0.3 + sin(_flicker_t * 5.3) * 0.2
	_light.light_energy = _base_energy + f * 0.3
	_flame.scale = Vector3.ONE * (1.0 + f * 0.12)

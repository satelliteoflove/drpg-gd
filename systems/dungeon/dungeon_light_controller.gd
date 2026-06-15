class_name DungeonLightController
extends RefCounted

## Resolves the party's current light source and the lighting target it implies.
## Priority: an active Light SPELL (bright, cool, steady, long reach) beats a lit
## TORCH (warm, flickering, mid reach) beats DARKNESS (a near-blind ember, heavy
## fog). dungeon.gd lerps the player light / fog / vignette toward these targets
## and handles the per-step torch burn + auto-relight.

enum Source { DARK, TORCH, SPELL }

const TORCH_ENERGY := 1.15
const TORCH_RANGE := 9.0
const TORCH_FLICKER := 0.09

const SPELL_ENERGY := 1.75
const SPELL_RANGE := 14.0
const SPELL_FLICKER := 0.02

const DARK_ENERGY := 0.16
const DARK_RANGE := 2.8
const DARK_FLICKER := 0.05


func has_light_spell(party: Party) -> bool:
	if party == null:
		return false
	for m in party.get_members():
		if not m.is_dead and m.has_status(CharacterEnums.StatusEffect.LIGHT):
			return true
	return false


func get_source(party: Party) -> int:
	if has_light_spell(party):
		return Source.SPELL
	if party != null and party.torch_steps_remaining > 0:
		return Source.TORCH
	return Source.DARK


## Returns the lighting target for a source under a theme:
## { energy, range, color, fog, flicker, vignette }.
func target_for(source: int, theme: FloorTheme) -> Dictionary:
	match source:
		Source.SPELL:
			return {
				"energy": SPELL_ENERGY,
				"range": SPELL_RANGE,
				"color": theme.light_spell_color,
				"fog": theme.fog_density_lit * 0.6,
				"flicker": SPELL_FLICKER,
				"vignette": theme.vignette_strength_lit * 0.7,
			}
		Source.TORCH:
			return {
				"energy": TORCH_ENERGY,
				"range": TORCH_RANGE,
				"color": theme.torch_color,
				"fog": theme.fog_density_lit,
				"flicker": TORCH_FLICKER,
				"vignette": theme.vignette_strength_lit,
			}
		_:
			return {
				"energy": DARK_ENERGY,
				"range": DARK_RANGE,
				"color": theme.torch_color.darkened(0.45),
				"fog": theme.fog_density_dark,
				"flicker": DARK_FLICKER,
				"vignette": theme.vignette_strength_dark,
			}

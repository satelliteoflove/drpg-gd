class_name SpellDatabase
extends RefCounted

const CharEnum = preload("res://resources/character_enums.gd")

static var _spells: Dictionary = {}
static var _initialized: bool = false


static func get_spell(spell_id: String) -> Spell:
	_ensure_initialized()
	return _spells.get(spell_id, null)


static func get_all_spells() -> Array[Spell]:
	_ensure_initialized()
	var result: Array[Spell] = []
	for spell in _spells.values():
		result.append(spell)
	return result


static func get_spells_by_school(school: CharEnum.SpellSchool) -> Array[Spell]:
	_ensure_initialized()
	var result: Array[Spell] = []
	for spell in _spells.values():
		if spell.school == school:
			result.append(spell)
	return result


static func get_spells_by_level(school: CharEnum.SpellSchool, level: int) -> Array[Spell]:
	_ensure_initialized()
	var result: Array[Spell] = []
	for spell in _spells.values():
		if spell.school == school and spell.level == level:
			result.append(spell)
	return result


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_create_mage_spells()
	_create_priest_spells()
	_create_alchemist_spells()
	_create_psionic_spells()


static func _create_mage_spells() -> void:
	var spell: Spell

	spell = Spell.create("m1_fire_bolt", "Fire Bolt", "", CharEnum.SpellSchool.MAGE, 1, CharEnum.SpellTargetType.SINGLE_ENEMY, "Hurls a small fireball at one enemy.")
	spell.add_damage_effect(CharEnum.Element.FIRE, "1d8", 0)
	_spells["m1_fire_bolt"] = spell

	spell = Spell.create("m1_sleep", "Sleep", "", CharEnum.SpellSchool.MAGE, 1, CharEnum.SpellTargetType.SPLASH, "Puts enemies to sleep in an area.")
	spell.add_status_effect(CharEnum.StatusEffect.ASLEEP, "3+1d3", CharEnum.SaveType.MENTAL, 0)
	_spells["m1_sleep"] = spell

	spell = Spell.create("m1_mapping", "Mapping", "", CharEnum.SpellSchool.MAGE, 1, CharEnum.SpellTargetType.SELF, "Reveals your position in the dungeon.")
	spell.set_in_combat(false).set_out_of_combat(true)
	_spells["m1_mapping"] = spell

	spell = Spell.create("m2_fire_wave", "Fire Wave", "", CharEnum.SpellSchool.MAGE, 2, CharEnum.SpellTargetType.ROW, "A wave of fire sweeps across a row of enemies.")
	spell.add_damage_effect(CharEnum.Element.FIRE, "2d6", 0)
	_spells["m2_fire_wave"] = spell

	spell = Spell.create("m2_fear", "Fear", "", CharEnum.SpellSchool.MAGE, 2, CharEnum.SpellTargetType.SINGLE_ENEMY, "Strikes terror into one enemy.")
	spell.add_status_effect(CharEnum.StatusEffect.AFRAID, "3+1d4", CharEnum.SaveType.MENTAL, 2)
	_spells["m2_fear"] = spell

	spell = Spell.create("m3_fireball", "Fireball", "", CharEnum.SpellSchool.MAGE, 3, CharEnum.SpellTargetType.SPLASH, "A fireball explodes among enemies.")
	spell.add_damage_effect(CharEnum.Element.FIRE, "3d8", 0)
	_spells["m3_fireball"] = spell

	spell = Spell.create("m3_silence", "Silence", "", CharEnum.SpellSchool.MAGE, 3, CharEnum.SpellTargetType.SPLASH, "Silences enemies in an area.")
	spell.add_status_effect(CharEnum.StatusEffect.SILENCED, "4+1d4", CharEnum.SaveType.MAGICAL, 2)
	_spells["m3_silence"] = spell

	spell = Spell.create("m4_freeze", "Freeze", "", CharEnum.SpellSchool.MAGE, 4, CharEnum.SpellTargetType.SINGLE_ENEMY, "A freezing blast strikes one enemy.")
	spell.add_damage_effect(CharEnum.Element.ICE, "4d8", 1)
	_spells["m4_freeze"] = spell

	spell = Spell.create("m4_firestorm", "Firestorm", "", CharEnum.SpellSchool.MAGE, 4, CharEnum.SpellTargetType.ALL_ENEMIES, "A storm of fire engulfs all enemies.")
	spell.add_damage_effect(CharEnum.Element.FIRE, "4d8", 0)
	_spells["m4_firestorm"] = spell

	spell = Spell.create("m5_blizzard", "Blizzard", "", CharEnum.SpellSchool.MAGE, 5, CharEnum.SpellTargetType.ALL_ENEMIES, "A blizzard strikes all enemies.")
	spell.add_damage_effect(CharEnum.Element.ICE, "5d8", 0)
	_spells["m5_blizzard"] = spell

	spell = Spell.create("m5_terror", "Terror", "", CharEnum.SpellSchool.MAGE, 5, CharEnum.SpellTargetType.SPLASH, "Strikes terror into enemies in an area.")
	spell.add_status_effect(CharEnum.StatusEffect.AFRAID, "4+1d4", CharEnum.SaveType.MENTAL, 4)
	_spells["m5_terror"] = spell

	spell = Spell.create("m6_disintegrate", "Disintegrate", "", CharEnum.SpellSchool.MAGE, 6, CharEnum.SpellTargetType.SINGLE_ENEMY, "Attempts to destroy one enemy instantly.")
	spell.effects.append(SpellEffect.create_instant_death(0))
	_spells["m6_disintegrate"] = spell

	spell = Spell.create("m6_suffocate", "Suffocate", "", CharEnum.SpellSchool.MAGE, 6, CharEnum.SpellTargetType.ALL_ENEMIES, "Removes air from around all enemies.")
	spell.add_damage_effect(CharEnum.Element.NONE, "6d6", 1)
	_spells["m6_suffocate"] = spell

	spell = Spell.create("m7_explosion", "Explosion", "", CharEnum.SpellSchool.MAGE, 7, CharEnum.SpellTargetType.ALL_ENEMIES, "A massive explosion devastates all enemies.")
	spell.add_damage_effect(CharEnum.Element.FIRE, "10d10", 2)
	_spells["m7_explosion"] = spell


static func _create_priest_spells() -> void:
	var spell: Spell

	spell = Spell.create("p1_heal", "Heal", "", CharEnum.SpellSchool.PRIEST, 1, CharEnum.SpellTargetType.SINGLE_ALLY, "Heals one ally for a small amount.")
	spell.add_healing_effect("1d8", 0)
	spell.set_out_of_combat(true)
	_spells["p1_heal"] = spell

	spell = Spell.create("p1_smite", "Smite", "", CharEnum.SpellSchool.PRIEST, 1, CharEnum.SpellTargetType.SINGLE_ENEMY, "Causes holy harm to one enemy.")
	spell.add_damage_effect(CharEnum.Element.HOLY, "1d8", 0)
	_spells["p1_smite"] = spell

	spell = Spell.create("p1_bless", "Bless", "", CharEnum.SpellSchool.PRIEST, 1, CharEnum.SpellTargetType.ALL_ALLIES, "Blesses the party with protection.")
	spell.add_buff_effect("evasion", 2, -1)
	_spells["p1_bless"] = spell

	spell = Spell.create("p2_divine_favor", "Divine Favor", "", CharEnum.SpellSchool.PRIEST, 2, CharEnum.SpellTargetType.ALL_ALLIES, "Grants divine blessing to the party.")
	spell.add_status_effect(CharEnum.StatusEffect.BLESSED, "", CharEnum.SaveType.MAGICAL, 0)
	_spells["p2_divine_favor"] = spell

	spell = Spell.create("p2_light", "Light", "", CharEnum.SpellSchool.PRIEST, 2, CharEnum.SpellTargetType.SELF, "Creates light to see in darkness.")
	spell.set_in_combat(false).set_out_of_combat(true)
	_spells["p2_light"] = spell

	spell = Spell.create("p3_purify", "Purify", "", CharEnum.SpellSchool.PRIEST, 3, CharEnum.SpellTargetType.SINGLE_ALLY, "Cures paralysis and sleep.")
	spell.add_cure_effect("paralysis")
	spell.add_cure_effect("mental")
	spell.set_out_of_combat(true)
	_spells["p3_purify"] = spell

	spell = Spell.create("p3_identify", "Identify", "", CharEnum.SpellSchool.PRIEST, 3, CharEnum.SpellTargetType.SELF, "Identifies monsters in combat.")
	_spells["p3_identify"] = spell

	spell = Spell.create("p4_greater_heal", "Greater Heal", "", CharEnum.SpellSchool.PRIEST, 4, CharEnum.SpellTargetType.SINGLE_ALLY, "Heals one ally for a moderate amount.")
	spell.add_healing_effect("2d8", 1)
	spell.set_out_of_combat(true)
	_spells["p4_greater_heal"] = spell

	spell = Spell.create("p4_greater_smite", "Greater Smite", "", CharEnum.SpellSchool.PRIEST, 4, CharEnum.SpellTargetType.SINGLE_ENEMY, "Causes significant holy harm to one enemy.")
	spell.add_damage_effect(CharEnum.Element.HOLY, "2d8", 1)
	_spells["p4_greater_smite"] = spell

	spell = Spell.create("p4_cure_poison", "Cure Poison", "", CharEnum.SpellSchool.PRIEST, 4, CharEnum.SpellTargetType.SINGLE_ALLY, "Removes poison from one ally.")
	spell.add_cure_effect("poison")
	spell.set_out_of_combat(true)
	_spells["p4_cure_poison"] = spell

	spell = Spell.create("p5_major_heal", "Major Heal", "", CharEnum.SpellSchool.PRIEST, 5, CharEnum.SpellTargetType.SINGLE_ALLY, "Heals one ally for a large amount.")
	spell.add_healing_effect("3d8", 2)
	spell.set_out_of_combat(true)
	_spells["p5_major_heal"] = spell

	spell = Spell.create("p5_major_smite", "Major Smite", "", CharEnum.SpellSchool.PRIEST, 5, CharEnum.SpellTargetType.SINGLE_ENEMY, "Causes great holy harm to one enemy.")
	spell.add_damage_effect(CharEnum.Element.HOLY, "3d8", 2)
	_spells["p5_major_smite"] = spell

	spell = Spell.create("p5_resurrect", "Resurrect", "", CharEnum.SpellSchool.PRIEST, 5, CharEnum.SpellTargetType.DEAD_ALLY, "Attempts to resurrect a dead ally.")
	spell.effects.append(SpellEffect.create_resurrection(0.75, 0.25))
	spell.set_out_of_combat(true)
	_spells["p5_resurrect"] = spell

	spell = Spell.create("p6_restoration", "Restoration", "", CharEnum.SpellSchool.PRIEST, 6, CharEnum.SpellTargetType.SINGLE_ALLY, "Fully heals one ally and cures all ailments.")
	spell.effects.append(SpellEffect.create_full_heal())
	spell.add_cure_effect("all")
	spell.set_out_of_combat(true)
	_spells["p6_restoration"] = spell

	spell = Spell.create("p6_holy_blades", "Holy Blades", "", CharEnum.SpellSchool.PRIEST, 6, CharEnum.SpellTargetType.ALL_ENEMIES, "Holy blades strike all enemies.")
	spell.add_damage_effect(CharEnum.Element.HOLY, "6d6", 1)
	_spells["p6_holy_blades"] = spell

	spell = Spell.create("p7_true_resurrect", "True Resurrect", "", CharEnum.SpellSchool.PRIEST, 7, CharEnum.SpellTargetType.DEAD_ALLY, "Resurrects a dead ally, even from ashes.")
	spell.effects.append(SpellEffect.create_resurrection(1.0, 0.5))
	spell.set_out_of_combat(true)
	_spells["p7_true_resurrect"] = spell

	spell = Spell.create("p7_divine_wrath", "Divine Wrath", "", CharEnum.SpellSchool.PRIEST, 7, CharEnum.SpellTargetType.ALL_ENEMIES, "Divine power smites all enemies.")
	spell.add_damage_effect(CharEnum.Element.HOLY, "12d6", 2)
	_spells["p7_divine_wrath"] = spell


static func _create_alchemist_spells() -> void:
	var spell: Spell

	spell = Spell.create("a1_alchemists_fire", "Alchemist's Fire", "", CharEnum.SpellSchool.ALCHEMIST, 1, CharEnum.SpellTargetType.SINGLE_ENEMY, "Hurls a flask of burning liquid at one enemy.")
	spell.add_damage_effect(CharEnum.Element.FIRE, "1d8", 0)
	_spells["a1_alchemists_fire"] = spell

	spell = Spell.create("a1_stoneskin_tonic", "Stoneskin Tonic", "", CharEnum.SpellSchool.ALCHEMIST, 1, CharEnum.SpellTargetType.SELF, "Hardens the caster's skin.")
	spell.add_buff_effect("defense", 4, -1)
	_spells["a1_stoneskin_tonic"] = spell

	spell = Spell.create("a2_phasing_elixir", "Phasing Elixir", "", CharEnum.SpellSchool.ALCHEMIST, 2, CharEnum.SpellTargetType.SINGLE_ALLY, "Makes one ally harder to hit.")
	spell.add_buff_effect("evasion", 4, -1)
	_spells["a2_phasing_elixir"] = spell

	spell = Spell.create("a2_poison_cloud", "Poison Cloud", "", CharEnum.SpellSchool.ALCHEMIST, 2, CharEnum.SpellTargetType.SPLASH, "A cloud of poison gas engulfs enemies.")
	spell.add_status_effect(CharEnum.StatusEffect.POISONED, "", CharEnum.SaveType.PHYSICAL, 2)
	_spells["a2_poison_cloud"] = spell

	spell = Spell.create("a3_bottled_lightning", "Bottled Lightning", "", CharEnum.SpellSchool.ALCHEMIST, 3, CharEnum.SpellTargetType.COLUMN, "Electrical discharge strikes enemies in a line.")
	spell.add_damage_effect(CharEnum.Element.LIGHTNING, "3d6", 0)
	_spells["a3_bottled_lightning"] = spell

	spell = Spell.create("a3_panic_philter", "Panic Philter", "", CharEnum.SpellSchool.ALCHEMIST, 3, CharEnum.SpellTargetType.SINGLE_ENEMY, "A fear-inducing compound strikes terror into one enemy.")
	spell.add_status_effect(CharEnum.StatusEffect.AFRAID, "3+1d4", CharEnum.SaveType.MENTAL, 2)
	_spells["a3_panic_philter"] = spell

	spell = Spell.create("a4_flash_freeze", "Flash Freeze", "", CharEnum.SpellSchool.ALCHEMIST, 4, CharEnum.SpellTargetType.SINGLE_ENEMY, "A cryogenic compound freezes one enemy.")
	spell.add_damage_effect(CharEnum.Element.ICE, "4d8", 1)
	_spells["a4_flash_freeze"] = spell

	spell = Spell.create("a4_paralysis_gas", "Paralysis Gas", "", CharEnum.SpellSchool.ALCHEMIST, 4, CharEnum.SpellTargetType.SPLASH, "A paralytic agent affects enemies in an area.")
	spell.add_status_effect(CharEnum.StatusEffect.PARALYZED, "3+1d3", CharEnum.SaveType.PHYSICAL, 4)
	_spells["a4_paralysis_gas"] = spell

	spell = Spell.create("a5_frost_bomb", "Frost Bomb", "", CharEnum.SpellSchool.ALCHEMIST, 5, CharEnum.SpellTargetType.ALL_ENEMIES, "An extreme cold reaction freezes all enemies.")
	spell.add_damage_effect(CharEnum.Element.ICE, "5d8", 0)
	_spells["a5_frost_bomb"] = spell

	spell = Spell.create("a5_ite_serum", "ite Serum", "", CharEnum.SpellSchool.ALCHEMIST, 5, CharEnum.SpellTargetType.SINGLE_ENEMY, "A calcium compound attempts to turn one enemy to stone.")
	spell.add_status_effect(CharEnum.StatusEffect.STONED, "", CharEnum.SaveType.MAGICAL, 4)
	_spells["a5_ite_serum"] = spell

	spell = Spell.create("a6_dissolving_acid", "Dissolving Acid", "", CharEnum.SpellSchool.ALCHEMIST, 6, CharEnum.SpellTargetType.SINGLE_ENEMY, "Molecular breakdown destroys one enemy.")
	spell.effects.append(SpellEffect.create_instant_death(0))
	_spells["a6_dissolving_acid"] = spell

	spell = Spell.create("a6_nullifying_solvent", "Nullifying Solvent", "", CharEnum.SpellSchool.ALCHEMIST, 6, CharEnum.SpellTargetType.ALL_ENEMIES, "Dissolves magical effects from all enemies.")
	spell.add_cure_effect("all")
	_spells["a6_nullifying_solvent"] = spell

	spell = Spell.create("a7_volatile_reaction", "Volatile Reaction", "", CharEnum.SpellSchool.ALCHEMIST, 7, CharEnum.SpellTargetType.ALL_ENEMIES, "A catastrophic chain reaction devastates all enemies.")
	spell.add_damage_effect(CharEnum.Element.FIRE, "10d10", 2)
	_spells["a7_volatile_reaction"] = spell


static func _create_psionic_spells() -> void:
	var spell: Spell

	spell = Spell.create("s1_psychic_shield", "Psychic Shield", "", CharEnum.SpellSchool.PSIONIC, 1, CharEnum.SpellTargetType.ALL_ALLIES, "Protects the party's minds.")
	spell.add_buff_effect("evasion", 2, -1)
	_spells["s1_psychic_shield"] = spell

	spell = Spell.create("s1_mind_bolt", "Mind Bolt", "", CharEnum.SpellSchool.PSIONIC, 1, CharEnum.SpellTargetType.SINGLE_ENEMY, "A bolt of psychic energy.")
	spell.add_damage_effect(CharEnum.Element.PSYCHIC, "1d8", 0)
	_spells["s1_mind_bolt"] = spell

	spell = Spell.create("s2_mental_block", "Mental Block", "", CharEnum.SpellSchool.PSIONIC, 2, CharEnum.SpellTargetType.SPLASH, "Silences the minds of enemies in an area.")
	spell.add_status_effect(CharEnum.StatusEffect.SILENCED, "4+1d4", CharEnum.SaveType.MENTAL, 2)
	_spells["s2_mental_block"] = spell

	spell = Spell.create("s2_blur_mind", "Blur Mind", "", CharEnum.SpellSchool.PSIONIC, 2, CharEnum.SpellTargetType.SINGLE_ALLY, "Makes one ally hard to perceive.")
	spell.add_buff_effect("evasion", 4, -1)
	_spells["s2_blur_mind"] = spell

	spell = Spell.create("s3_mind_cleanse", "Mind Cleanse", "", CharEnum.SpellSchool.PSIONIC, 3, CharEnum.SpellTargetType.SINGLE_ALLY, "Cures mental afflictions.")
	spell.add_cure_effect("mental")
	spell.set_out_of_combat(true)
	_spells["s3_mind_cleanse"] = spell

	spell = Spell.create("s3_psychic_surge", "Psychic Surge", "", CharEnum.SpellSchool.PSIONIC, 3, CharEnum.SpellTargetType.ALL_ALLIES, "Empowers the entire party mentally.")
	spell.add_status_effect(CharEnum.StatusEffect.BLESSED, "", CharEnum.SaveType.MAGICAL, 0)
	_spells["s3_psychic_surge"] = spell

	spell = Spell.create("s4_mind_lock", "Mind Lock", "", CharEnum.SpellSchool.PSIONIC, 4, CharEnum.SpellTargetType.SPLASH, "Freezes enemies in place via mental force.")
	spell.add_status_effect(CharEnum.StatusEffect.PARALYZED, "2+1d3", CharEnum.SaveType.MENTAL, 4)
	_spells["s4_mind_lock"] = spell

	spell = Spell.create("s4_pyrokinesis", "Pyrokinesis", "", CharEnum.SpellSchool.PSIONIC, 4, CharEnum.SpellTargetType.COLUMN, "A pillar of fire created by thought burns through enemies.")
	spell.add_damage_effect(CharEnum.Element.FIRE, "4d6", 1)
	_spells["s4_pyrokinesis"] = spell

	spell = Spell.create("s5_death_thought", "Death Thought", "", CharEnum.SpellSchool.PSIONIC, 5, CharEnum.SpellTargetType.SINGLE_ENEMY, "Attempts to kill one enemy with pure thought.")
	spell.effects.append(SpellEffect.create_instant_death(-2))
	_spells["s5_death_thought"] = spell

	spell = Spell.create("s5_teleport", "Teleport", "", CharEnum.SpellSchool.PSIONIC, 5, CharEnum.SpellTargetType.SELF, "Teleports the party to safety.")
	spell.set_in_combat(false).set_out_of_combat(true)
	_spells["s5_teleport"] = spell

	spell = Spell.create("s6_psychic_shards", "Psychic Shards", "", CharEnum.SpellSchool.PSIONIC, 6, CharEnum.SpellTargetType.ALL_ENEMIES, "Psychic blades strike all enemies.")
	spell.add_damage_effect(CharEnum.Element.PSYCHIC, "6d6", 1)
	_spells["s6_psychic_shards"] = spell

	spell = Spell.create("s6_mass_death", "Mass Death", "", CharEnum.SpellSchool.PSIONIC, 6, CharEnum.SpellTargetType.ALL_ENEMIES, "Attempts to kill all enemies with pure thought.")
	spell.effects.append(SpellEffect.create_instant_death(2))
	_spells["s6_mass_death"] = spell

	spell = Spell.create("s7_psychic_storm", "Psychic Storm", "", CharEnum.SpellSchool.PSIONIC, 7, CharEnum.SpellTargetType.ALL_ENEMIES, "A devastating psychic assault on all enemies.")
	spell.add_damage_effect(CharEnum.Element.PSYCHIC, "12d6", 2)
	_spells["s7_psychic_storm"] = spell

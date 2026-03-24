class_name SpellDatabase
extends RefCounted

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


static func get_spells_by_school(school: CharacterEnums.SpellSchool) -> Array[Spell]:
	_ensure_initialized()
	var result: Array[Spell] = []
	for spell in _spells.values():
		if spell.school == school:
			result.append(spell)
	return result


static func get_spells_by_level(school: CharacterEnums.SpellSchool, level: int) -> Array[Spell]:
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

	spell = Spell.create("m1_fire_bolt", "Fire Bolt", "", CharacterEnums.SpellSchool.MAGE, 1, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "Hurls a small fireball at one enemy.")
	spell.add_damage_effect(CharacterEnums.Element.FIRE, "1d8", 0)
	_spells["m1_fire_bolt"] = spell

	spell = Spell.create("m1_sleep", "Sleep", "", CharacterEnums.SpellSchool.MAGE, 1, CharacterEnums.SpellTargetType.SPLASH, "Puts enemies to sleep in an area.")
	spell.add_status_effect(CharacterEnums.StatusEffect.ASLEEP, "3+1d3", CharacterEnums.SaveType.MENTAL, 0)
	_spells["m1_sleep"] = spell

	spell = Spell.create("m1_mapping", "Mapping", "", CharacterEnums.SpellSchool.MAGE, 1, CharacterEnums.SpellTargetType.SELF, "Reveals your position in the dungeon.")
	spell.set_in_combat(false).set_out_of_combat(true)
	_spells["m1_mapping"] = spell

	spell = Spell.create("m2_fire_wave", "Fire Wave", "", CharacterEnums.SpellSchool.MAGE, 2, CharacterEnums.SpellTargetType.ROW, "A wave of fire sweeps across a row of enemies.")
	spell.add_damage_effect(CharacterEnums.Element.FIRE, "2d6", 0)
	_spells["m2_fire_wave"] = spell

	spell = Spell.create("m2_fear", "Fear", "", CharacterEnums.SpellSchool.MAGE, 2, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "Strikes terror into one enemy.")
	spell.add_status_effect(CharacterEnums.StatusEffect.AFRAID, "3+1d4", CharacterEnums.SaveType.MENTAL, 2)
	_spells["m2_fear"] = spell

	spell = Spell.create("m3_fireball", "Fireball", "", CharacterEnums.SpellSchool.MAGE, 3, CharacterEnums.SpellTargetType.SPLASH, "A fireball explodes among enemies.")
	spell.add_damage_effect(CharacterEnums.Element.FIRE, "3d8", 0)
	_spells["m3_fireball"] = spell

	spell = Spell.create("m3_curse", "Curse", "", CharacterEnums.SpellSchool.MAGE, 3, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "Places a dark curse on one enemy, reducing accuracy and evasion.")
	spell.add_status_effect(CharacterEnums.StatusEffect.CURSED, "", CharacterEnums.SaveType.MAGICAL, 3)
	_spells["m3_curse"] = spell

	spell = Spell.create("m3_dread", "Dread", "", CharacterEnums.SpellSchool.MAGE, 3, CharacterEnums.SpellTargetType.SPLASH, "A wave of dread washes over enemies in an area.")
	spell.add_status_effect(CharacterEnums.StatusEffect.AFRAID, "3+1d4", CharacterEnums.SaveType.MENTAL, 3)
	_spells["m3_dread"] = spell

	spell = Spell.create("m3_silence", "Silence", "", CharacterEnums.SpellSchool.MAGE, 3, CharacterEnums.SpellTargetType.SPLASH, "Silences enemies in an area.")
	spell.add_status_effect(CharacterEnums.StatusEffect.SILENCED, "4+1d4", CharacterEnums.SaveType.MAGICAL, 2)
	_spells["m3_silence"] = spell

	spell = Spell.create("m4_freeze", "Freeze", "", CharacterEnums.SpellSchool.MAGE, 4, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "A freezing blast strikes one enemy.")
	spell.add_damage_effect(CharacterEnums.Element.ICE, "4d8", 1)
	_spells["m4_freeze"] = spell

	spell = Spell.create("m4_firestorm", "Firestorm", "", CharacterEnums.SpellSchool.MAGE, 4, CharacterEnums.SpellTargetType.ALL_ENEMIES, "A storm of fire engulfs all enemies.")
	spell.add_damage_effect(CharacterEnums.Element.FIRE, "4d8", 0)
	_spells["m4_firestorm"] = spell

	spell = Spell.create("m5_blizzard", "Blizzard", "", CharacterEnums.SpellSchool.MAGE, 5, CharacterEnums.SpellTargetType.ALL_ENEMIES, "A blizzard strikes all enemies.")
	spell.add_damage_effect(CharacterEnums.Element.ICE, "5d8", 0)
	_spells["m5_blizzard"] = spell

	spell = Spell.create("m5_terror", "Terror", "", CharacterEnums.SpellSchool.MAGE, 5, CharacterEnums.SpellTargetType.SPLASH, "Strikes terror into enemies in an area.")
	spell.add_status_effect(CharacterEnums.StatusEffect.AFRAID, "4+1d4", CharacterEnums.SaveType.MENTAL, 4)
	_spells["m5_terror"] = spell

	spell = Spell.create("m6_disintegrate", "Disintegrate", "", CharacterEnums.SpellSchool.MAGE, 6, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "Attempts to destroy one enemy instantly.")
	spell.effects.append(SpellEffect.create_instant_death(0))
	_spells["m6_disintegrate"] = spell

	spell = Spell.create("m6_suffocate", "Suffocate", "", CharacterEnums.SpellSchool.MAGE, 6, CharacterEnums.SpellTargetType.ALL_ENEMIES, "Removes air from around all enemies.")
	spell.add_damage_effect(CharacterEnums.Element.NONE, "6d6", 1)
	_spells["m6_suffocate"] = spell

	spell = Spell.create("m7_explosion", "Explosion", "", CharacterEnums.SpellSchool.MAGE, 7, CharacterEnums.SpellTargetType.ALL_ENEMIES, "A massive explosion devastates all enemies.")
	spell.add_damage_effect(CharacterEnums.Element.FIRE, "10d10", 2)
	_spells["m7_explosion"] = spell


static func _create_priest_spells() -> void:
	var spell: Spell

	spell = Spell.create("p1_heal", "Heal", "", CharacterEnums.SpellSchool.PRIEST, 1, CharacterEnums.SpellTargetType.SINGLE_ALLY, "Heals one ally for a small amount.")
	spell.add_healing_effect("1d8", 0)
	spell.set_out_of_combat(true)
	_spells["p1_heal"] = spell

	spell = Spell.create("p1_smite", "Smite", "", CharacterEnums.SpellSchool.PRIEST, 1, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "Causes holy harm to one enemy.")
	spell.add_damage_effect(CharacterEnums.Element.HOLY, "1d8", 0)
	_spells["p1_smite"] = spell

	spell = Spell.create("p1_bless", "Bless", "", CharacterEnums.SpellSchool.PRIEST, 1, CharacterEnums.SpellTargetType.ALL_ALLIES, "Blesses the party with protection.")
	spell.add_buff_effect("evasion", 2, -1)
	_spells["p1_bless"] = spell

	spell = Spell.create("p2_divine_favor", "Divine Favor", "", CharacterEnums.SpellSchool.PRIEST, 2, CharacterEnums.SpellTargetType.ALL_ALLIES, "Grants divine blessing to the party.")
	spell.add_status_effect(CharacterEnums.StatusEffect.BLESSED, "5+1d6", CharacterEnums.SaveType.MAGICAL, 0)
	_spells["p2_divine_favor"] = spell

	spell = Spell.create("p2_light", "Light", "", CharacterEnums.SpellSchool.PRIEST, 2, CharacterEnums.SpellTargetType.SELF, "Creates light to see in darkness.")
	spell.set_in_combat(false).set_out_of_combat(true)
	_spells["p2_light"] = spell

	spell = Spell.create("p3_purify", "Purify", "", CharacterEnums.SpellSchool.PRIEST, 3, CharacterEnums.SpellTargetType.SINGLE_ALLY, "Cures paralysis and sleep.")
	spell.add_cure_effect("paralysis")
	spell.add_cure_effect("mental")
	spell.set_out_of_combat(true)
	_spells["p3_purify"] = spell

	spell = Spell.create("p3_identify", "Identify", "", CharacterEnums.SpellSchool.PRIEST, 3, CharacterEnums.SpellTargetType.SELF, "Identifies monsters in combat.")
	_spells["p3_identify"] = spell

	spell = Spell.create("p4_greater_heal", "Greater Heal", "", CharacterEnums.SpellSchool.PRIEST, 4, CharacterEnums.SpellTargetType.SINGLE_ALLY, "Heals one ally for a moderate amount.")
	spell.add_healing_effect("2d8", 1)
	spell.set_out_of_combat(true)
	_spells["p4_greater_heal"] = spell

	spell = Spell.create("p4_greater_smite", "Greater Smite", "", CharacterEnums.SpellSchool.PRIEST, 4, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "Causes significant holy harm to one enemy.")
	spell.add_damage_effect(CharacterEnums.Element.HOLY, "2d8", 1)
	_spells["p4_greater_smite"] = spell

	spell = Spell.create("p4_cure_poison", "Cure Poison", "", CharacterEnums.SpellSchool.PRIEST, 4, CharacterEnums.SpellTargetType.SINGLE_ALLY, "Removes poison from one ally.")
	spell.add_cure_effect("poison")
	spell.set_out_of_combat(true)
	_spells["p4_cure_poison"] = spell

	spell = Spell.create("p5_major_heal", "Major Heal", "", CharacterEnums.SpellSchool.PRIEST, 5, CharacterEnums.SpellTargetType.SINGLE_ALLY, "Heals one ally for a large amount.")
	spell.add_healing_effect("3d8", 2)
	spell.set_out_of_combat(true)
	_spells["p5_major_heal"] = spell

	spell = Spell.create("p5_major_smite", "Major Smite", "", CharacterEnums.SpellSchool.PRIEST, 5, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "Causes great holy harm to one enemy.")
	spell.add_damage_effect(CharacterEnums.Element.HOLY, "3d8", 2)
	_spells["p5_major_smite"] = spell

	spell = Spell.create("p5_resurrect", "Resurrect", "", CharacterEnums.SpellSchool.PRIEST, 5, CharacterEnums.SpellTargetType.DEAD_ALLY, "Attempts to resurrect a dead ally.")
	spell.effects.append(SpellEffect.create_resurrection(0.75, 0.25))
	spell.set_out_of_combat(true)
	_spells["p5_resurrect"] = spell

	spell = Spell.create("p6_restoration", "Restoration", "", CharacterEnums.SpellSchool.PRIEST, 6, CharacterEnums.SpellTargetType.SINGLE_ALLY, "Fully heals one ally and cures all ailments.")
	spell.effects.append(SpellEffect.create_full_heal())
	spell.add_cure_effect("all")
	spell.set_out_of_combat(true)
	_spells["p6_restoration"] = spell

	spell = Spell.create("p6_holy_blades", "Holy Blades", "", CharacterEnums.SpellSchool.PRIEST, 6, CharacterEnums.SpellTargetType.ALL_ENEMIES, "Holy blades strike all enemies.")
	spell.add_damage_effect(CharacterEnums.Element.HOLY, "6d6", 1)
	_spells["p6_holy_blades"] = spell

	spell = Spell.create("p7_true_resurrect", "True Resurrect", "", CharacterEnums.SpellSchool.PRIEST, 7, CharacterEnums.SpellTargetType.DEAD_ALLY, "Resurrects a dead ally, even from ashes.")
	spell.effects.append(SpellEffect.create_resurrection(1.0, 0.5))
	spell.set_out_of_combat(true)
	_spells["p7_true_resurrect"] = spell

	spell = Spell.create("p7_divine_wrath", "Divine Wrath", "", CharacterEnums.SpellSchool.PRIEST, 7, CharacterEnums.SpellTargetType.ALL_ENEMIES, "Divine power smites all enemies.")
	spell.add_damage_effect(CharacterEnums.Element.HOLY, "12d6", 2)
	_spells["p7_divine_wrath"] = spell


static func _create_alchemist_spells() -> void:
	var spell: Spell

	spell = Spell.create("a1_alchemists_fire", "Alchemist's Fire", "", CharacterEnums.SpellSchool.ALCHEMIST, 1, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "Hurls a flask of burning liquid at one enemy.")
	spell.add_damage_effect(CharacterEnums.Element.FIRE, "1d8", 0)
	_spells["a1_alchemists_fire"] = spell

	spell = Spell.create("a1_stoneskin_tonic", "Stoneskin Tonic", "", CharacterEnums.SpellSchool.ALCHEMIST, 1, CharacterEnums.SpellTargetType.SELF, "Hardens the caster's skin.")
	spell.add_buff_effect("defense", 4, -1)
	_spells["a1_stoneskin_tonic"] = spell

	spell = Spell.create("a2_phasing_elixir", "Phasing Elixir", "", CharacterEnums.SpellSchool.ALCHEMIST, 2, CharacterEnums.SpellTargetType.SINGLE_ALLY, "Makes one ally harder to hit.")
	spell.add_buff_effect("evasion", 4, -1)
	_spells["a2_phasing_elixir"] = spell

	spell = Spell.create("a2_poison_cloud", "Poison Cloud", "", CharacterEnums.SpellSchool.ALCHEMIST, 2, CharacterEnums.SpellTargetType.SPLASH, "A cloud of poison gas engulfs enemies.")
	spell.add_status_effect(CharacterEnums.StatusEffect.POISONED, "", CharacterEnums.SaveType.PHYSICAL, 2)
	_spells["a2_poison_cloud"] = spell

	spell = Spell.create("a2_rage_draught", "Rage Draught", "", CharacterEnums.SpellSchool.ALCHEMIST, 2, CharacterEnums.SpellTargetType.SINGLE_ALLY, "A volatile compound that sends one ally into a berserk fury, boosting damage but removing control.")
	spell.add_status_effect(CharacterEnums.StatusEffect.BERSERK, "", CharacterEnums.SaveType.PHYSICAL, 0)
	_spells["a2_rage_draught"] = spell

	spell = Spell.create("a3_bottled_lightning", "Bottled Lightning", "", CharacterEnums.SpellSchool.ALCHEMIST, 3, CharacterEnums.SpellTargetType.COLUMN, "Electrical discharge strikes enemies in a line.")
	spell.add_damage_effect(CharacterEnums.Element.LIGHTNING, "3d6", 0)
	_spells["a3_bottled_lightning"] = spell

	spell = Spell.create("a3_panic_philter", "Panic Philter", "", CharacterEnums.SpellSchool.ALCHEMIST, 3, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "A fear-inducing compound strikes terror into one enemy.")
	spell.add_status_effect(CharacterEnums.StatusEffect.AFRAID, "3+1d4", CharacterEnums.SaveType.MENTAL, 2)
	_spells["a3_panic_philter"] = spell

	spell = Spell.create("a4_flash_freeze", "Flash Freeze", "", CharacterEnums.SpellSchool.ALCHEMIST, 4, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "A cryogenic compound freezes one enemy.")
	spell.add_damage_effect(CharacterEnums.Element.ICE, "4d8", 1)
	_spells["a4_flash_freeze"] = spell

	spell = Spell.create("a4_paralysis_gas", "Paralysis Gas", "", CharacterEnums.SpellSchool.ALCHEMIST, 4, CharacterEnums.SpellTargetType.SPLASH, "A paralytic agent affects enemies in an area.")
	spell.add_status_effect(CharacterEnums.StatusEffect.PARALYZED, "3+1d3", CharacterEnums.SaveType.PHYSICAL, 4)
	_spells["a4_paralysis_gas"] = spell

	spell = Spell.create("a5_frost_bomb", "Frost Bomb", "", CharacterEnums.SpellSchool.ALCHEMIST, 5, CharacterEnums.SpellTargetType.ALL_ENEMIES, "An extreme cold reaction freezes all enemies.")
	spell.add_damage_effect(CharacterEnums.Element.ICE, "5d8", 0)
	_spells["a5_frost_bomb"] = spell

	spell = Spell.create("a5_ite_serum", "ite Serum", "", CharacterEnums.SpellSchool.ALCHEMIST, 5, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "A calcium compound attempts to turn one enemy to stone.")
	spell.add_status_effect(CharacterEnums.StatusEffect.STONED, "", CharacterEnums.SaveType.MAGICAL, 4)
	_spells["a5_ite_serum"] = spell

	spell = Spell.create("a6_dissolving_acid", "Dissolving Acid", "", CharacterEnums.SpellSchool.ALCHEMIST, 6, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "Molecular breakdown destroys one enemy.")
	spell.effects.append(SpellEffect.create_instant_death(0))
	_spells["a6_dissolving_acid"] = spell

	spell = Spell.create("a6_nullifying_solvent", "Nullifying Solvent", "", CharacterEnums.SpellSchool.ALCHEMIST, 6, CharacterEnums.SpellTargetType.ALL_ENEMIES, "Dissolves magical effects from all enemies.")
	spell.add_cure_effect("all")
	_spells["a6_nullifying_solvent"] = spell

	spell = Spell.create("a7_volatile_reaction", "Volatile Reaction", "", CharacterEnums.SpellSchool.ALCHEMIST, 7, CharacterEnums.SpellTargetType.ALL_ENEMIES, "A catastrophic chain reaction devastates all enemies.")
	spell.add_damage_effect(CharacterEnums.Element.FIRE, "10d10", 2)
	_spells["a7_volatile_reaction"] = spell


static func _create_psionic_spells() -> void:
	var spell: Spell

	spell = Spell.create("s1_psychic_shield", "Psychic Shield", "", CharacterEnums.SpellSchool.PSIONIC, 1, CharacterEnums.SpellTargetType.ALL_ALLIES, "Protects the party's minds.")
	spell.add_buff_effect("evasion", 2, -1)
	_spells["s1_psychic_shield"] = spell

	spell = Spell.create("s1_mind_bolt", "Mind Bolt", "", CharacterEnums.SpellSchool.PSIONIC, 1, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "A bolt of psychic energy.")
	spell.add_damage_effect(CharacterEnums.Element.PSYCHIC, "1d8", 0)
	_spells["s1_mind_bolt"] = spell

	spell = Spell.create("s2_mental_block", "Mental Block", "", CharacterEnums.SpellSchool.PSIONIC, 2, CharacterEnums.SpellTargetType.SPLASH, "Silences the minds of enemies in an area.")
	spell.add_status_effect(CharacterEnums.StatusEffect.SILENCED, "4+1d4", CharacterEnums.SaveType.MENTAL, 2)
	_spells["s2_mental_block"] = spell

	spell = Spell.create("s2_blur_mind", "Blur Mind", "", CharacterEnums.SpellSchool.PSIONIC, 2, CharacterEnums.SpellTargetType.SINGLE_ALLY, "Makes one ally hard to perceive.")
	spell.add_buff_effect("evasion", 4, -1)
	_spells["s2_blur_mind"] = spell

	spell = Spell.create("s2_battle_fury", "Battle Fury", "", CharacterEnums.SpellSchool.PSIONIC, 2, CharacterEnums.SpellTargetType.SINGLE_ALLY, "Unleashes primal rage in one ally's mind, boosting damage but removing control.")
	spell.add_status_effect(CharacterEnums.StatusEffect.BERSERK, "", CharacterEnums.SaveType.MENTAL, 0)
	_spells["s2_battle_fury"] = spell

	spell = Spell.create("s2_mind_sense", "Mind Sense", "", CharacterEnums.SpellSchool.PSIONIC, 2, CharacterEnums.SpellTargetType.SELF, "Senses all enemy minds on the current floor.")
	spell.effects.append(SpellEffect.create_reveal_enemies(40))
	spell.set_in_combat(false).set_out_of_combat(true)
	_spells["s2_mind_sense"] = spell

	spell = Spell.create("s2_mind_ward", "Mind Ward", "", CharacterEnums.SpellSchool.PSIONIC, 2, CharacterEnums.SpellTargetType.SINGLE_ALLY, "Fortifies one ally's mind against mental attacks, granting strong resistance to confusion, charm, and fear.")
	spell.add_status_effect(CharacterEnums.StatusEffect.MIND_WARDED, "8+1d6", CharacterEnums.SaveType.MENTAL, 0)
	_spells["s2_mind_ward"] = spell

	spell = Spell.create("s3_mind_cleanse", "Mind Cleanse", "", CharacterEnums.SpellSchool.PSIONIC, 3, CharacterEnums.SpellTargetType.SINGLE_ALLY, "Cures mental afflictions.")
	spell.add_cure_effect("mental")
	spell.set_out_of_combat(true)
	_spells["s3_mind_cleanse"] = spell

	spell = Spell.create("s3_psychic_surge", "Psychic Surge", "", CharacterEnums.SpellSchool.PSIONIC, 3, CharacterEnums.SpellTargetType.ALL_ALLIES, "Empowers the entire party mentally.")
	spell.add_status_effect(CharacterEnums.StatusEffect.BLESSED, "5+1d6", CharacterEnums.SaveType.MAGICAL, 0)
	_spells["s3_psychic_surge"] = spell

	spell = Spell.create("s4_mind_lock", "Mind Lock", "", CharacterEnums.SpellSchool.PSIONIC, 4, CharacterEnums.SpellTargetType.SPLASH, "Freezes enemies in place via mental force.")
	spell.add_status_effect(CharacterEnums.StatusEffect.PARALYZED, "2+1d3", CharacterEnums.SaveType.MENTAL, 4)
	_spells["s4_mind_lock"] = spell

	spell = Spell.create("s4_pyrokinesis", "Pyrokinesis", "", CharacterEnums.SpellSchool.PSIONIC, 4, CharacterEnums.SpellTargetType.COLUMN, "A pillar of fire created by thought burns through enemies.")
	spell.add_damage_effect(CharacterEnums.Element.FIRE, "4d6", 1)
	_spells["s4_pyrokinesis"] = spell

	spell = Spell.create("s5_death_thought", "Death Thought", "", CharacterEnums.SpellSchool.PSIONIC, 5, CharacterEnums.SpellTargetType.SINGLE_ENEMY, "Attempts to kill one enemy with pure thought.")
	spell.effects.append(SpellEffect.create_instant_death(-2))
	_spells["s5_death_thought"] = spell

	spell = Spell.create("s5_teleport", "Teleport", "", CharacterEnums.SpellSchool.PSIONIC, 5, CharacterEnums.SpellTargetType.SELF, "Teleports the party to safety.")
	spell.set_in_combat(false).set_out_of_combat(true)
	_spells["s5_teleport"] = spell

	spell = Spell.create("s6_psychic_shards", "Psychic Shards", "", CharacterEnums.SpellSchool.PSIONIC, 6, CharacterEnums.SpellTargetType.ALL_ENEMIES, "Psychic blades strike all enemies.")
	spell.add_damage_effect(CharacterEnums.Element.PSYCHIC, "6d6", 1)
	_spells["s6_psychic_shards"] = spell

	spell = Spell.create("s6_mass_death", "Mass Death", "", CharacterEnums.SpellSchool.PSIONIC, 6, CharacterEnums.SpellTargetType.ALL_ENEMIES, "Attempts to kill all enemies with pure thought.")
	spell.effects.append(SpellEffect.create_instant_death(2))
	_spells["s6_mass_death"] = spell

	spell = Spell.create("s7_psychic_storm", "Psychic Storm", "", CharacterEnums.SpellSchool.PSIONIC, 7, CharacterEnums.SpellTargetType.ALL_ENEMIES, "A devastating psychic assault on all enemies.")
	spell.add_damage_effect(CharacterEnums.Element.PSYCHIC, "12d6", 2)
	_spells["s7_psychic_storm"] = spell

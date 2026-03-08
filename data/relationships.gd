class_name Relationships
extends RefCounted

enum BondTier { NEUTRAL, COMPANION, BONDED }

const COMPANION_THRESHOLD := 50
const BONDED_THRESHOLD := 150
const DIMINISHING_DECAY := 0.85
const DIMINISHING_FLOOR := 0.25
const REUNION_WEIGHT := 5
const ADJACENCY_BONUSES := {
	BondTier.NEUTRAL: { "accuracy": 0, "evasion": 0 },
	BondTier.COMPANION: { "accuracy": 2, "evasion": 1 },
	BondTier.BONDED: { "accuracy": 4, "evasion": 2 },
}
const TIER_NAMES := {
	BondTier.NEUTRAL: "Neutral",
	BondTier.COMPANION: "Companion",
	BondTier.BONDED: "Bonded",
}


static func get_tier(total_weight: int) -> BondTier:
	if total_weight >= BONDED_THRESHOLD:
		return BondTier.BONDED
	if total_weight >= COMPANION_THRESHOLD:
		return BondTier.COMPANION
	return BondTier.NEUTRAL


static func get_tier_name(tier: BondTier) -> String:
	return TIER_NAMES.get(tier, "Neutral")


static func make_pair_key(id_a: String, id_b: String) -> String:
	var ids := [id_a, id_b]
	ids.sort()
	return "%s:%s" % [ids[0], ids[1]]


static func create_modifier(source: String, weight: int, day: int) -> Dictionary:
	return { "source": source, "weight": weight, "day": day }

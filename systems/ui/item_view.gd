class_name ItemView

## Shared presentation helpers for items, so the Inventory tab and every Shop
## mode badge/label items identically. Badge color encodes rarity; the short
## glyph encodes type. Unidentified items get a mysterious "?" crest.

const UNIDENTIFIED_COLOR := Color(0.62, 0.48, 0.86)


static func badge(item: Item) -> Dictionary:
	if not item.is_identified:
		return {"text": "?", "color": UNIDENTIFIED_COLOR}
	var codes := {
		Item.ItemType.WEAPON: "Wp", Item.ItemType.ARMOR: "Ar", Item.ItemType.SHIELD: "Sh",
		Item.ItemType.HELMET: "Hl", Item.ItemType.GLOVES: "Gl", Item.ItemType.BOOTS: "Bt",
		Item.ItemType.ACCESSORY: "Ac", Item.ItemType.CONSUMABLE: "Cn", Item.ItemType.QUEST: "Qs",
	}
	return {"text": codes.get(item.item_type, "?"), "color": UIColors.rarity_color(item.rarity)}


static func subtitle(item: Item) -> String:
	var s := item.get_type_name()
	var stats := item.get_stats_text()
	if item.is_identified and stats != "" and stats != "No special properties":
		s += "  ·  " + stats
	return s


static func name_color(item: Item) -> Color:
	if not item.is_identified:
		return UNIDENTIFIED_COLOR
	if item.is_cursed:
		return UIColors.TEXT_DANGER
	return UIColors.rarity_color(item.rarity)

class_name LootDrop
extends Resource

@export var item_id: String = ""
@export var chance: float = 0.1


static func create(p_item_id: String, p_chance: float) -> Resource:
	var script: GDScript = load("res://resources/loot_drop.gd")
	var drop: Resource = script.new()
	drop.set("item_id", p_item_id)
	drop.set("chance", p_chance)
	return drop

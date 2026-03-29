class_name Inventory
extends Resource

signal item_added(item: Item, quantity: int)
signal item_removed(item: Item, quantity: int)
signal inventory_full()

const MAX_SLOTS: int = 30

@export var slots: Array[Dictionary] = []


func add_item(item: Item, quantity: int = 1) -> int:
	if item.stackable:
		for slot in slots:
			if slot.get("item_id") == item.id:
				var current: int = slot.get("quantity", 0)
				var can_add := mini(quantity, item.max_stack - current)
				if can_add > 0:
					slot["quantity"] = current + can_add
					item_added.emit(item, can_add)
					quantity -= can_add
				if quantity <= 0:
					return 0

	while quantity > 0 and slots.size() < MAX_SLOTS:
		var add_qty := mini(quantity, item.max_stack) if item.stackable else 1
		var slot_item: Item = item if quantity == 1 else item.duplicate() as Item
		slots.append({
			"item_id": item.id,
			"item": slot_item,
			"quantity": add_qty
		})
		item_added.emit(slot_item, add_qty)
		quantity -= add_qty

	if quantity > 0:
		inventory_full.emit()

	return quantity


func remove_item(item_id: String, quantity: int = 1) -> int:
	var removed := 0

	for i in range(slots.size() - 1, -1, -1):
		if slots[i].get("item_id") != item_id:
			continue

		var slot_qty: int = slots[i].get("quantity", 1)
		var to_remove := mini(quantity - removed, slot_qty)

		slots[i]["quantity"] = slot_qty - to_remove
		removed += to_remove

		if slots[i]["quantity"] <= 0:
			var item: Item = slots[i].get("item")
			slots.remove_at(i)
			if item:
				item_removed.emit(item, to_remove)

		if removed >= quantity:
			break

	return removed


func get_item_count(item_id: String) -> int:
	var count := 0
	for slot in slots:
		if slot.get("item_id") == item_id:
			count += slot.get("quantity", 1)
	return count


func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= slots.size():
		return {}
	return slots[index]


func get_item_at(index: int) -> Item:
	var slot := get_slot(index)
	return slot.get("item", null)


func get_quantity_at(index: int) -> int:
	var slot := get_slot(index)
	return slot.get("quantity", 0)


func size() -> int:
	return slots.size()


func is_empty() -> bool:
	return slots.is_empty()


func is_full() -> bool:
	return slots.size() >= MAX_SLOTS


func get_all_items() -> Array[Item]:
	var items: Array[Item] = []
	for slot in slots:
		var item: Item = slot.get("item")
		if item and not items.has(item):
			items.append(item)
	return items


func clear() -> void:
	slots.clear()

class_name CombatItemHandler
extends RefCounted

var combat = null


func init(p_combat: Control) -> void:
	combat = p_combat


func on_item_pressed() -> void:
	if not combat.combat_system or not combat.combat_system.is_player_turn():
		return

	populate_item_list()
	if combat.available_items.is_empty():
		combat.message_log.append_text("[color=#aaaaaa]>[/color] No usable items!\n")
		return

	combat._close_all_modals()
	combat._set_actions_enabled(false)
	combat.item_modal.visible = true

	if combat.item_nav and not combat.item_buttons.is_empty():
		combat.item_nav.setup(combat.item_buttons, 0)


func populate_item_list() -> void:
	for child in combat.item_list.get_children():
		child.queue_free()
	combat.available_items.clear()
	combat.item_buttons.clear()

	if GameState.party == null or GameState.party.inventory == null:
		return

	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		var qty: int = GameState.party.inventory.get_quantity_at(i)
		if item == null:
			continue
		if item.item_type != Item.ItemType.CONSUMABLE:
			continue
		if item.heal_amount <= 0 and item.mp_restore <= 0 and item.cures_status.is_empty():
			continue

		if not combat.available_items.has(item):
			combat.available_items.append(item)
			var btn := Button.new()
			btn.text = "%s x%d" % [item.item_name, qty]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.custom_minimum_size = Vector2(0, 32)
			btn.pressed.connect(on_item_selected.bind(item))
			combat.item_list.add_child(btn)
			combat.item_buttons.append(btn)

	combat.item_nav = MenuNavigator.new()
	if not combat.item_buttons.is_empty():
		combat.item_nav.setup(combat.item_buttons, 0)


func on_item_selected(item: Item) -> void:
	combat.selected_item = item
	combat.item_modal.visible = false
	populate_target_list()
	combat.target_modal.visible = true

	if combat.target_nav and not combat.target_buttons.is_empty():
		combat.target_nav.setup(combat.target_buttons, 0)


func populate_target_list() -> void:
	for child in combat.target_list.get_children():
		child.queue_free()
	combat.target_buttons.clear()

	if combat.combat_system == null:
		return

	for character in combat.combat_system.get_party():
		var btn := Button.new()
		var status := ""
		if character.is_dead:
			status = " [DEAD]"
		btn.text = "%s: %d/%d HP%s" % [
			character.get_display_name(),
			character.current_hp,
			character.max_hp,
			status
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)

		var can_use := can_use_item_on(combat.selected_item, character)
		if not can_use:
			btn.disabled = true
			btn.modulate = UIColors.MODULATE_DISABLED

		btn.pressed.connect(on_target_selected.bind(character))
		btn.focus_entered.connect(combat.targeting.highlight_party_target.bind(character))
		combat.target_list.add_child(btn)
		combat.target_buttons.append(btn)

	combat.target_nav = MenuNavigator.new()
	if not combat.target_buttons.is_empty():
		combat.target_nav.setup(combat.target_buttons, 0)


func can_use_item_on(item: Item, character: Character) -> bool:
	if character.is_dead:
		return false

	if item.heal_amount > 0 and character.current_hp < character.max_hp:
		return true

	if item.mp_restore > 0 and character.current_mp < character.max_mp:
		return true

	for status in item.cures_status:
		if character.has_status(status):
			return true

	return false


func on_target_selected(character: Character) -> void:
	if combat.selected_item == null:
		return

	combat._close_all_modals()

	var current_char: Character = combat._get_character_by_id(combat.combat_system.current_combatant_id)
	var user_name := current_char.get_display_name() if current_char else "Party"

	var message := "%s uses %s on %s. " % [
		user_name,
		combat.selected_item.item_name,
		character.get_display_name()
	]

	if combat.selected_item.heal_amount > 0:
		var healed := character.heal(combat.selected_item.heal_amount)
		message += "Restored %d HP. " % healed
		combat.targeting.show_floating_text(character.id, "+%d HP" % healed, UIColors.HP_GREEN)

	if combat.selected_item.mp_restore > 0:
		var restored := character.restore_mp(combat.selected_item.mp_restore)
		message += "Restored %d MP. " % restored
		combat.targeting.show_floating_text(character.id, "+%d MP" % restored, UIColors.MP_BLUE)

	for status in combat.selected_item.cures_status:
		if character.has_status(status):
			character.remove_status(status)
			message += "Cured %s. " % get_status_name(status)

	GameState.party.inventory.remove_item(combat.selected_item.id, 1)
	combat.message_log.append_text("[color=#aaaaaa]>[/color] " + message + "\n")

	combat.selected_item = null

	if combat.combat_system:
		combat.combat_system.end_player_turn()


func get_status_name(status) -> String:
	match status:
		CharacterEnums.StatusEffect.POISONED: return "Poison"
		CharacterEnums.StatusEffect.PARALYZED: return "Paralysis"
		CharacterEnums.StatusEffect.ASLEEP: return "Sleep"
		CharacterEnums.StatusEffect.CONFUSED: return "Confusion"
		CharacterEnums.StatusEffect.SILENCED: return "Silence"
		CharacterEnums.StatusEffect.BLINDED: return "Blindness"
		_: return "status"

extends Control

const MenuNavigatorClass = preload("res://systems/ui/menu_navigator.gd")
const KeyBindingHelperClass = preload("res://systems/ui/key_binding_helper.gd")

signal closed()

enum FocusPanel { ITEMS, TARGETS }

var current_panel: FocusPanel = FocusPanel.ITEMS
var selected_item: Item = null
var selected_slot_index: int = -1

var items_nav: MenuNavigator = null
var targets_nav: MenuNavigator = null
var item_buttons: Array[Button] = []
var target_buttons: Array[Button] = []

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var items_list: VBoxContainer = $VBoxContainer/MainPanel/ItemsPanel/ScrollContainer/ItemsList
@onready var targets_panel: PanelContainer = $VBoxContainer/MainPanel/TargetsPanel
@onready var targets_list: VBoxContainer = $VBoxContainer/MainPanel/TargetsPanel/TargetsList
@onready var info_label: RichTextLabel = $VBoxContainer/InfoPanel/InfoLabel
@onready var message_label: Label = $VBoxContainer/MessageLabel
@onready var back_button: Button = $VBoxContainer/BackButton


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	targets_panel.visible = false
	_refresh_items_list()
	_set_panel(FocusPanel.ITEMS)


func _refresh_items_list() -> void:
	for child in items_list.get_children():
		child.queue_free()
	item_buttons.clear()

	if GameState.party == null or GameState.party.inventory == null:
		var label := Label.new()
		label.text = "(No inventory)"
		items_list.add_child(label)
		return

	if GameState.party.inventory.is_empty():
		var label := Label.new()
		label.text = "(Inventory is empty)"
		items_list.add_child(label)
		return

	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		var qty: int = GameState.party.inventory.get_quantity_at(i)
		if item == null:
			continue

		var btn := Button.new()
		var qty_text := " x%d" % qty if qty > 1 else ""
		btn.text = "%s%s" % [item.get_display_name(), qty_text]
		btn.custom_minimum_size = Vector2(300, 30)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_item_selected.bind(i, item))
		items_list.add_child(btn)
		item_buttons.append(btn)

	items_nav = MenuNavigatorClass.new()
	if not item_buttons.is_empty():
		items_nav.setup(item_buttons, 0)
		items_nav.selection_changed.connect(_on_item_highlight_changed)


func _refresh_targets_list() -> void:
	for child in targets_list.get_children():
		child.queue_free()
	target_buttons.clear()

	if GameState.party == null:
		return

	for character in GameState.party.get_members():
		var btn := Button.new()
		var status := ""
		if character.is_dead:
			status = " [DEAD]"
		btn.text = "%s: %d/%d HP, %d/%d MP%s" % [
			character.get_display_name(),
			character.current_hp,
			character.max_hp,
			character.current_mp,
			character.max_mp,
			status
		]
		btn.custom_minimum_size = Vector2(300, 30)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var can_use := _can_use_item_on(selected_item, character)
		if not can_use:
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)

		btn.pressed.connect(_on_target_selected.bind(character))
		targets_list.add_child(btn)
		target_buttons.append(btn)

	targets_nav = MenuNavigatorClass.new()
	if not target_buttons.is_empty():
		targets_nav.setup(target_buttons, 0)


func _can_use_item_on(item: Item, character: Character) -> bool:
	if item == null:
		return false

	if character.is_dead:
		return false

	if item.item_type != Item.ItemType.CONSUMABLE:
		return false

	if item.heal_amount > 0 and character.current_hp < character.max_hp:
		return true

	if item.mp_restore > 0 and character.current_mp < character.max_mp:
		return true

	for status in item.cures_status:
		if character.has_status(status):
			return true

	return false


func _set_panel(panel: FocusPanel) -> void:
	current_panel = panel
	var cancel := KeyBindingHelperClass.get_cancel_help()

	match panel:
		FocusPanel.ITEMS:
			targets_panel.visible = false
			var help_text := "Select an item. [%s]" % cancel
			if GameState.party.has_living_bishop():
				help_text += " [I to identify]"
			message_label.text = help_text
			_update_item_info()
		FocusPanel.TARGETS:
			targets_panel.visible = true
			message_label.text = "Select a target. [%s]" % cancel


func _update_item_info() -> void:
	if items_nav == null or item_buttons.is_empty():
		info_label.text = "No items in inventory."
		return

	var idx := items_nav.get_current_index()
	if idx < 0 or idx >= GameState.party.inventory.size():
		return

	var item: Item = GameState.party.inventory.get_item_at(idx)
	if item == null:
		return

	var text := "[b]%s[/b]\n" % item.get_display_name()
	text += "Type: %s\n" % item.get_type_name()
	text += "%s\n" % item.get_stats_text()

	if item.item_type == Item.ItemType.CONSUMABLE:
		text += "\n[Press Enter to use]"
	elif item.is_equipment():
		text += "\n[Equip from Equipment screen]"

	if not item.is_identified and GameState.party.has_living_bishop():
		text += "\n[color=cyan][Press I to identify (Bishop)][/color]"

	info_label.text = text


func _on_item_highlight_changed(_index: int) -> void:
	_update_item_info()


func _on_item_selected(slot_index: int, item: Item) -> void:
	if item.item_type != Item.ItemType.CONSUMABLE:
		message_label.text = "Cannot use %s here. Equip from Equipment screen." % item.get_display_name()
		return

	if item.heal_amount <= 0 and item.mp_restore <= 0 and item.cures_status.is_empty():
		message_label.text = "%s has no usable effect." % item.get_display_name()
		return

	selected_item = item
	selected_slot_index = slot_index
	_refresh_targets_list()
	_set_panel(FocusPanel.TARGETS)


func _on_target_selected(character: Character) -> void:
	if selected_item == null:
		return

	if not _can_use_item_on(selected_item, character):
		message_label.text = "Cannot use %s on %s." % [selected_item.get_display_name(), character.get_display_name()]
		return

	var message := "Used %s on %s. " % [selected_item.get_display_name(), character.get_display_name()]

	if selected_item.heal_amount > 0:
		var healed := character.heal(selected_item.heal_amount)
		message += "Restored %d HP. " % healed

	if selected_item.mp_restore > 0:
		var restored := character.restore_mp(selected_item.mp_restore)
		message += "Restored %d MP. " % restored

	for status in selected_item.cures_status:
		if character.has_status(status):
			character.remove_status(status)
			message += "Cured %s. " % _get_status_name(status)

	GameState.party.inventory.remove_item(selected_item.id, 1)
	message_label.text = message

	selected_item = null
	selected_slot_index = -1
	_set_panel(FocusPanel.ITEMS)
	_refresh_items_list()


func _get_status_name(status) -> String:
	var CharEnum = preload("res://resources/character_enums.gd")
	match status:
		CharEnum.StatusEffect.POISONED: return "Poison"
		CharEnum.StatusEffect.PARALYZED: return "Paralysis"
		CharEnum.StatusEffect.ASLEEP: return "Sleep"
		CharEnum.StatusEffect.CONFUSED: return "Confusion"
		CharEnum.StatusEffect.SILENCED: return "Silence"
		CharEnum.StatusEffect.BLINDED: return "Blindness"
		_: return "status"


func _try_identify_current_item() -> void:
	if items_nav == null or item_buttons.is_empty():
		return

	var idx := items_nav.get_current_index()
	if idx < 0 or idx >= GameState.party.inventory.size():
		return

	var item: Item = GameState.party.inventory.get_item_at(idx)
	if item == null:
		return

	if item.is_identified:
		message_label.text = "Item is already identified."
		return

	if not GameState.party.has_living_bishop():
		message_label.text = "No living Bishop in party to identify items."
		return

	item.is_identified = true
	message_label.text = "Bishop identified %s!" % item.get_display_name()
	_refresh_items_list()
	_update_item_info()
	if items_nav and idx < item_buttons.size():
		items_nav.select(idx)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		match current_panel:
			FocusPanel.ITEMS:
				_on_back_pressed()
			FocusPanel.TARGETS:
				_set_panel(FocusPanel.ITEMS)
		return

	if current_panel == FocusPanel.ITEMS:
		if event is InputEventKey and event.pressed and event.keycode == KEY_I:
			_try_identify_current_item()
			return

	var nav: MenuNavigator = _get_current_nav()
	if nav == null:
		return

	if event.is_action_pressed("menu_up"):
		nav._move(-1)
		if current_panel == FocusPanel.ITEMS:
			_update_item_info()
	elif event.is_action_pressed("menu_down"):
		nav._move(1)
		if current_panel == FocusPanel.ITEMS:
			_update_item_info()
	elif event.is_action_pressed("menu_confirm"):
		nav._confirm()


func _get_current_nav() -> MenuNavigator:
	match current_panel:
		FocusPanel.ITEMS: return items_nav
		FocusPanel.TARGETS: return targets_nav
	return null


func _on_back_pressed() -> void:
	if closed.get_connections().is_empty():
		SceneManager.go_to_town()
	else:
		closed.emit()

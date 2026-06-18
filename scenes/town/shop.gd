extends Control

enum Mode { BUY, SELL, UPGRADE, SCRAP, IDENTIFY, UNCURSE }

const MODE_NAMES: Array[String] = ["Buy", "Sell", "Upgrade", "Scrap", "Identify", "Uncurse"]

var current_mode: Mode = Mode.BUY

var nav: MenuNavigator = null
var item_buttons: Array[Button] = []
var displayed_items: Array[Item] = []

var buy_mode: ShopBuyMode
var sell_mode: ShopSellMode
var upgrade_mode: ShopUpgradeMode
var scrap_mode: ShopScrapMode
var identify_mode: ShopIdentifyMode
var uncurse_mode: ShopUncurseMode
var modes: Array[RefCounted] = []

var _scaffold: ScreenScaffold = null
var _mode_buttons: Array[Button] = []
var _detail: ItemDetailView = null

@onready var title_label: Label = $MainHBox/LeftPanel/Header/TitleLabel
@onready var gold_label: Label = $MainHBox/LeftPanel/Header/GoldLabel
@onready var scrap_label: Label = $MainHBox/LeftPanel/Header/ScrapLabel
@onready var capacity_label: Label = $MainHBox/LeftPanel/ModeContainer/CapacityLabel
@onready var mode_label: Label = $MainHBox/LeftPanel/ModeContainer/ModeLabel
@onready var buy_button: Button = $MainHBox/LeftPanel/ModeContainer/BuyButton
@onready var sell_button: Button = $MainHBox/LeftPanel/ModeContainer/SellButton
@onready var items_panel: PanelContainer = $MainHBox/LeftPanel/ItemsPanel
@onready var items_list: VBoxContainer = $MainHBox/LeftPanel/ItemsPanel/ScrollContainer/ItemsList
@onready var message_label: Label = $MainHBox/LeftPanel/MessageLabel
@onready var help_label: Label = $MainHBox/LeftPanel/HelpLabel
@onready var back_button: Button = $MainHBox/LeftPanel/BackButton

@onready var right_panel: Control = $MainHBox/RightPanel

@onready var quantity_dialog: PanelContainer = $QuantityDialog
@onready var quantity_title: Label = $QuantityDialog/VBox/QuantityTitle
@onready var quantity_value: Label = $QuantityDialog/VBox/QuantityHBox/QuantityValue
@onready var total_label: Label = $QuantityDialog/VBox/TotalLabel
@onready var minus_button: Button = $QuantityDialog/VBox/QuantityHBox/MinusButton
@onready var plus_button: Button = $QuantityDialog/VBox/QuantityHBox/PlusButton
@onready var confirm_quantity: Button = $QuantityDialog/VBox/ButtonsHBox/ConfirmQuantity
@onready var cancel_quantity: Button = $QuantityDialog/VBox/ButtonsHBox/CancelQuantity

@onready var modal_overlay: ColorRect = $ModalOverlay

@onready var equip_dialog: PanelContainer = $EquipDialog
@onready var equip_title: Label = $EquipDialog/VBox/EquipTitle
@onready var equip_item_name: Label = $EquipDialog/VBox/EquipItemName
@onready var equip_options: VBoxContainer = $EquipDialog/VBox/EquipOptions
@onready var cancel_equip: Button = $EquipDialog/VBox/CancelEquip

@onready var upgrade_dialog: PanelContainer = $UpgradeDialog
@onready var upgrade_title: Label = $UpgradeDialog/VBox/UpgradeTitle
@onready var upgrade_item_name: Label = $UpgradeDialog/VBox/UpgradeItemName
@onready var upgrade_options: VBoxContainer = $UpgradeDialog/VBox/UpgradeOptions
@onready var cancel_upgrade: Button = $UpgradeDialog/VBox/CancelUpgrade


func _ready() -> void:
	buy_mode = ShopBuyMode.new()
	buy_mode.init(self)
	buy_mode.connect_buttons()

	sell_mode = ShopSellMode.new()
	sell_mode.init(self)

	upgrade_mode = ShopUpgradeMode.new()
	upgrade_mode.init(self)
	upgrade_mode.connect_buttons()

	scrap_mode = ShopScrapMode.new()
	scrap_mode.init(self)

	identify_mode = ShopIdentifyMode.new()
	identify_mode.init(self)

	uncurse_mode = ShopUncurseMode.new()
	uncurse_mode.init(self)

	modes = [buy_mode, sell_mode, upgrade_mode, scrap_mode, identify_mode, uncurse_mode]

	_install_chrome()
	refresh_display()


## Wrap the shop in the shared scaffold (title + live gold/scrap pill + frame),
## hide the legacy in-panel header / help / back, and replace the two competing
## mode controls (Buy/Sell toggles + "< Mode >" stepper) with one clean rail of
## all six modes.
func _install_chrome() -> void:
	var bg := get_node_or_null("Background")
	if bg != null:
		bg.queue_free()

	$MainHBox/LeftPanel/Header.visible = false
	help_label.visible = false
	back_button.visible = false
	buy_button.visible = false
	sell_button.visible = false
	mode_label.visible = false

	var main: Control = $MainHBox
	var left: VBoxContainer = $MainHBox/LeftPanel
	remove_child(main)
	_scaffold = ScreenScaffold.create({"title": "SHOP", "hint": "", "show_scrap": true})
	add_child(_scaffold)
	move_child(_scaffold, 0)
	_scaffold.body.add_child(main)
	_scaffold.back_pressed.connect(_on_back_pressed)

	_detail = ItemDetailView.new(right_panel)
	_build_mode_rail(left)


func _build_mode_rail(left: VBoxContainer) -> void:
	var rail := HBoxContainer.new()
	rail.add_theme_constant_override("separation", 6)
	left.add_child(rail)
	left.move_child(rail, 0)

	var group := ButtonGroup.new()
	_mode_buttons.clear()
	for m in range(Mode.size()):
		var btn := Button.new()
		btn.text = MODE_NAMES[m]
		btn.toggle_mode = true
		btn.button_group = group
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 34)
		_style_mode_button(btn)
		btn.pressed.connect(_set_mode.bind(m as Mode))
		rail.add_child(btn)
		_mode_buttons.append(btn)


func _style_mode_button(btn: Button) -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = UIColors.SURFACE_BACKGROUND
	flat.corner_radius_top_left = 6
	flat.corner_radius_top_right = 6
	flat.content_margin_top = 7
	flat.content_margin_bottom = 7

	var hover := flat.duplicate() as StyleBoxFlat
	hover.bg_color = UIColors.SURFACE_HOVER

	var active := flat.duplicate() as StyleBoxFlat
	active.bg_color = UIColors.SURFACE_CARD
	active.border_width_bottom = 3
	active.border_color = UIColors.ACCENT

	var focus := active.duplicate() as StyleBoxFlat
	focus.border_color = UIColors.BORDER_FOCUS

	btn.add_theme_stylebox_override("normal", flat)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", active)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", UIColors.TEXT_PRIMARY)


func _update_mode_rail() -> void:
	for i in range(_mode_buttons.size()):
		_mode_buttons[i].button_pressed = (i == current_mode)


func _get_active_mode() -> RefCounted:
	return modes[current_mode]


func refresh_display() -> void:
	_update_capacity_label()
	_update_mode_rail()
	_refresh_items_list()
	_update_info()
	update_help()


func _update_capacity_label() -> void:
	var current := GameState.party.inventory.size() if GameState.party.inventory else 0
	var max_cap := Inventory.MAX_SLOTS
	capacity_label.text = "Inventory: %d/%d" % [current, max_cap]

	var ratio := float(current) / float(max_cap)
	if ratio >= 1.0:
		capacity_label.add_theme_color_override("font_color", UIColors.TEXT_DANGER)
	elif ratio >= 0.8:
		capacity_label.add_theme_color_override("font_color", UIColors.TEXT_WARNING)
	else:
		capacity_label.remove_theme_color_override("font_color")


func _refresh_items_list() -> void:
	for child in items_list.get_children():
		child.queue_free()
	item_buttons.clear()
	displayed_items.clear()

	_get_active_mode().populate()

	nav = MenuNavigator.new()
	if not item_buttons.is_empty():
		nav.setup(item_buttons, 0)
		nav.selection_changed.connect(_on_selection_changed)


## Shared item-row factory used by every shop mode. Pass mode-specific chips
## (price, yield, selection marker) and a dim flag for unavailable rows.
func make_item_row(item: Item, chips: Array, dim: bool = false) -> MenuListRow:
	var b := ItemView.badge(item)
	return MenuListRow.create({
		"badge": b["text"],
		"badge_color": b["color"],
		"title": item.get_display_name(),
		"title_color": ItemView.name_color(item),
		"subtitle": ItemView.subtitle(item),
		"chips": chips,
		"dim": dim,
	})


## Rebuild the item list (e.g. after a multi-select toggle) without losing the
## player's place in it.
func rebuild_items_keep_focus(focus_index: int) -> void:
	_refresh_items_list()
	if nav and not item_buttons.is_empty():
		nav.select(clampi(focus_index, 0, item_buttons.size() - 1))
	_update_info()
	update_help()


func _on_selection_changed(_index: int) -> void:
	_update_info()


func _update_info() -> void:
	if _detail == null:
		return

	var idx := nav.get_current_index() if nav != null else -1
	if idx < 0 or idx >= displayed_items.size():
		_detail.show_text(_empty_detail_text())
		return

	var item: Item = displayed_items[idx]
	var fit_rows: Array = _build_fit_rows(item) if item.is_equipment() else []
	_detail.show_item(item, _item_body_bbcode(item), fit_rows)


## A centered guidance card for the current mode when no item is in focus.
func _empty_detail_text() -> String:
	return "[b]%s[/b]\n\n[color=#%s]%s[/color]" % [
		MODE_NAMES[current_mode],
		UIColors.TEXT_SECONDARY.to_html(false),
		_get_active_mode().get_mode_message()]


## Description / stats / requirements + the mode's transaction line. The name and
## type live in the dossier's header band, so they are omitted here.
func _item_body_bbcode(item: Item) -> String:
	var text := ""
	if item.is_identified:
		if item.description != "":
			text += "[color=#%s]%s[/color]\n\n" % [UIColors.TEXT_SECONDARY.to_html(false), item.description]
		text += "[color=#%s]%s[/color]" % [UIColors.TEXT_PRIMARY.to_html(false), item.get_stats_text()]

		var reqs: Array[String] = []
		if item.required_level > 1:
			reqs.append("Lv %d" % item.required_level)
		if not item.required_classes.is_empty():
			var class_names: Array[String] = []
			for c in item.required_classes:
				class_names.append(CharacterEnums.get_class_name(c))
			reqs.append(", ".join(class_names))
		if not item.required_races.is_empty():
			var race_names: Array[String] = []
			for r in item.required_races:
				race_names.append(CharacterEnums.get_race_name(r))
			reqs.append(", ".join(race_names))
		if not reqs.is_empty():
			text += "\n[color=#%s]Requires: %s[/color]" % [UIColors.TEXT_MUTED.to_html(false), "  ·  ".join(reqs)]
	else:
		text += "[color=#%s]Unidentified — stats unknown[/color]" % UIColors.TEXT_MUTED.to_html(false)

	text += _get_active_mode().get_info_suffix(item)
	return text


## Pre-build the per-member party-fit rows the dossier folds into its card.
func _build_fit_rows(item: Item) -> Array:
	var rows: Array = []
	if GameState.party == null or GameState.party.is_empty():
		var label := Label.new()
		label.theme_type_variation = &"MutedLabel"
		label.text = "No party members."
		rows.append(label)
		return rows
	for member in GameState.party.get_members():
		rows.append(_create_comparison_row(member, item))
	return rows


func _create_comparison_row(member: Character, item: Item) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)
	row.add_theme_constant_override("separation", 8)

	# Class crest, matching the dossier/roster crests.
	var tint := UIColors.class_color(member.character_class)
	var badge := Label.new()
	badge.text = CharacterEnums.get_class_name(member.character_class).substr(0, 1).to_upper()
	badge.custom_minimum_size = Vector2(22, 22)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", tint.lightened(0.4))
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint.darkened(0.55)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = tint
	badge.add_theme_stylebox_override("normal", sb)
	row.add_child(badge)

	var name_label := Label.new()
	name_label.text = member.character_name
	name_label.custom_minimum_size = Vector2(90, 0)
	row.add_child(name_label)

	var can_equip := member.can_equip_item(item)
	var current_item: Item = member.get_equipped_item(item.item_type)

	var diff_label := Label.new()
	diff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if not can_equip:
		diff_label.text = "Can't equip"
		diff_label.add_theme_color_override("font_color", UIColors.TEXT_MUTED)
	else:
		var diff_text := get_stat_diff(current_item, item)
		diff_label.text = diff_text
		if diff_text.begins_with("+"):
			diff_label.add_theme_color_override("font_color", UIColors.TEXT_HEALTHY)
		elif diff_text.begins_with("-"):
			diff_label.add_theme_color_override("font_color", UIColors.TEXT_DANGER)
		else:
			diff_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)

	row.add_child(diff_label)
	return row


func get_stat_diff(current: Item, new_item: Item) -> String:
	var parts: Array[String] = []

	var def_diff := new_item.get_effective_defense_bonus() - (current.get_effective_defense_bonus() if current else 0)
	var acc_diff := new_item.get_effective_accuracy_bonus() - (current.get_effective_accuracy_bonus() if current else 0)
	var eva_diff := new_item.get_effective_evasion_bonus() - (current.get_effective_evasion_bonus() if current else 0)
	var dmg_diff := new_item.get_effective_damage_bonus() - (current.get_effective_damage_bonus() if current else 0)

	if def_diff != 0:
		parts.append("Def %+d" % def_diff)
	if acc_diff != 0:
		parts.append("Acc %+d" % acc_diff)
	if eva_diff != 0:
		parts.append("Eva %+d" % eva_diff)
	if dmg_diff != 0:
		parts.append("Dmg %+d" % dmg_diff)

	if new_item.item_type == Item.ItemType.WEAPON and current == null:
		parts.append("Wpn: %s" % new_item.damage_dice)
	elif new_item.item_type == Item.ItemType.WEAPON and current:
		if new_item.damage_dice != current.damage_dice:
			parts.append("Wpn: %s->%s" % [current.damage_dice, new_item.damage_dice])

	if parts.is_empty():
		return "(no change)"
	return ", ".join(parts)


func update_help() -> void:
	if _scaffold != null:
		_scaffold.set_hint(_get_active_mode().get_help_text())


func _set_mode(mode: Mode) -> void:
	if current_mode == mode:
		return
	_get_active_mode().reset()
	current_mode = mode
	message_label.text = _get_active_mode().get_mode_message()
	refresh_display()


func _cycle_mode(direction: int) -> void:
	var new_mode := (current_mode + direction) % Mode.size()
	if new_mode < 0:
		new_mode = Mode.size() - 1
	_set_mode(new_mode as Mode)


func _unhandled_input(event: InputEvent) -> void:
	var active := _get_active_mode()

	if active.is_dialog_active():
		active.handle_input(event)
		return

	if event.is_action_pressed("menu_cancel"):
		if active.handle_cancel():
			return
		_on_back_pressed()
		return

	if event.is_action_pressed("menu_left"):
		_cycle_mode(-1)
		return
	elif event.is_action_pressed("menu_right"):
		_cycle_mode(1)
		return

	if active.handle_special_input(event):
		return

	if nav:
		if event.is_action_pressed("menu_confirm"):
			if active.handle_confirm():
				return
			nav.handle_input(event)
		else:
			nav.handle_input(event)


func _on_back_pressed() -> void:
	SceneManager.go_to_town()

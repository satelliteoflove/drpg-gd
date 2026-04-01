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

@onready var info_panel: PanelContainer = $MainHBox/RightPanel/InfoPanel
@onready var info_label: RichTextLabel = $MainHBox/RightPanel/InfoPanel/InfoLabel
@onready var comparison_label: Label = $MainHBox/RightPanel/ComparisonLabel
@onready var comparison_panel: PanelContainer = $MainHBox/RightPanel/ComparisonPanel
@onready var comparison_list: VBoxContainer = $MainHBox/RightPanel/ComparisonPanel/ScrollContainer/ComparisonList

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

	buy_button.pressed.connect(_on_buy_mode)
	sell_button.pressed.connect(_on_sell_mode)
	back_button.pressed.connect(_on_back_pressed)

	refresh_display()


func _get_active_mode() -> RefCounted:
	return modes[current_mode]


func refresh_display() -> void:
	gold_label.text = "Gold: %d" % GameState.party.gold
	if scrap_label:
		scrap_label.text = "Scrap: %d" % GameState.party.scrap
	_update_capacity_label()
	_update_mode_label()
	buy_button.button_pressed = (current_mode == Mode.BUY)
	sell_button.button_pressed = (current_mode == Mode.SELL)
	_refresh_items_list()
	_update_info()
	update_help()


func _update_mode_label() -> void:
	if mode_label:
		mode_label.text = "< %s >" % MODE_NAMES[current_mode]


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


func _on_selection_changed(_index: int) -> void:
	_update_info()
	_update_comparison()


func _update_info() -> void:
	if nav == null or displayed_items.is_empty():
		info_label.text = "Select an item to view details."
		comparison_label.visible = false
		comparison_panel.visible = false
		return

	var idx := nav.get_current_index()
	if idx < 0 or idx >= displayed_items.size():
		info_label.text = "Select an item to view details."
		return

	var item: Item = displayed_items[idx]
	_show_item_info(item)

	if item.is_equipment():
		comparison_label.visible = true
		comparison_panel.visible = true
		_update_comparison()
	else:
		comparison_label.visible = false
		comparison_panel.visible = false


func _show_item_info(item: Item) -> void:
	var text := "[b]%s[/b]\n" % item.get_display_name()
	text += "Type: %s\n" % item.get_type_name()

	if item.is_identified:
		if item.description != "":
			text += "%s\n" % item.description

		text += "\n%s\n" % item.get_stats_text()

		if item.required_level > 1:
			text += "\nRequires Level %d" % item.required_level

		if not item.required_classes.is_empty():
			var class_names: Array[String] = []
			for c in item.required_classes:
				class_names.append(CharacterEnums.get_class_name(c))
			text += "\nClasses: %s" % ", ".join(class_names)

		if not item.required_races.is_empty():
			var race_names: Array[String] = []
			for r in item.required_races:
				race_names.append(CharacterEnums.get_race_name(r))
			text += "\nRaces: %s" % ", ".join(race_names)
	else:
		text += "\n[color=gray]Unidentified - stats unknown[/color]\n"

	text += _get_active_mode().get_info_suffix(item)
	info_label.text = text


func _update_comparison() -> void:
	for child in comparison_list.get_children():
		child.queue_free()

	if nav == null or displayed_items.is_empty():
		return

	var idx := nav.get_current_index()
	if idx < 0 or idx >= displayed_items.size():
		return

	var item: Item = displayed_items[idx]
	if not item.is_equipment():
		return

	if GameState.party == null or GameState.party.is_empty():
		var label := Label.new()
		label.text = "(No party members)"
		comparison_list.add_child(label)
		return

	for member in GameState.party.get_members():
		var row := _create_comparison_row(member, item)
		comparison_list.add_child(row)


func _create_comparison_row(member: Character, item: Item) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)

	var name_label := Label.new()
	name_label.text = member.character_name
	name_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(name_label)

	var can_equip := member.can_equip_item(item)
	var current_item: Item = member.get_equipped_item(item.item_type)

	var diff_label := Label.new()
	diff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if not can_equip:
		diff_label.text = "[Cannot equip]"
		diff_label.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	else:
		var diff_text := get_stat_diff(current_item, item)
		diff_label.text = diff_text
		if diff_text.begins_with("+"):
			diff_label.add_theme_color_override("font_color", UIColors.TEXT_HEALTHY)
		elif diff_text.begins_with("-"):
			diff_label.add_theme_color_override("font_color", UIColors.TEXT_DANGER)

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
	help_label.text = _get_active_mode().get_help_text()


func _on_buy_mode() -> void:
	_set_mode(Mode.BUY)


func _on_sell_mode() -> void:
	_set_mode(Mode.SELL)


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

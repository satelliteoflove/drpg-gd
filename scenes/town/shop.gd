extends Control

const CharEnum = preload("res://resources/character_enums.gd")
const ShopItemsRef = preload("res://data/items/shop_items.gd")
const MenuNavigatorClass = preload("res://systems/ui/menu_navigator.gd")
const KeyBindingHelperClass = preload("res://systems/ui/key_binding_helper.gd")

enum Mode { BUY, SELL, UPGRADE, SCRAP, IDENTIFY, UNCURSE }
enum BuyState { BROWSING, QUANTITY_SELECT, EQUIP_SELECT }
enum SellState { BROWSING, CONFIRM_SELL }
enum UpgradeState { BROWSING, STAT_SELECT }
enum ScrapState { BROWSING }
enum IdentifyState { BROWSING }
enum UncurseState { BROWSING }

const MODE_NAMES: Array[String] = ["Buy", "Sell", "Upgrade", "Scrap", "Identify", "Uncurse"]

var current_mode: Mode = Mode.BUY
var buy_state: BuyState = BuyState.BROWSING
var sell_state: SellState = SellState.BROWSING
var upgrade_state: UpgradeState = UpgradeState.BROWSING
var scrap_state: ScrapState = ScrapState.BROWSING
var identify_state: IdentifyState = IdentifyState.BROWSING
var uncurse_state: UncurseState = UncurseState.BROWSING

var nav: MenuNavigator = null
var equip_nav: MenuNavigator = null
var item_buttons: Array[Button] = []
var equip_buttons: Array[Button] = []
var displayed_items: Array[Item] = []
var selected_members: Array[Character] = []

var selected_item: Item = null
var selected_quantity: int = 1
var max_quantity: int = 1
var selected_inventory_index: int = -1

var sell_selected_indices: Array[int] = []
var sell_multi_select: bool = false
var scrap_selected_indices: Array[int] = []
var scrap_multi_select: bool = false

var upgrade_stat_buttons: Array[Button] = []
var upgrade_stat_nav: MenuNavigator = null
var upgradeable_stats: Array[String] = []

var uncurse_items: Array[Dictionary] = []

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
	buy_button.pressed.connect(_on_buy_mode)
	sell_button.pressed.connect(_on_sell_mode)
	back_button.pressed.connect(_on_back_pressed)

	minus_button.pressed.connect(_on_quantity_minus)
	plus_button.pressed.connect(_on_quantity_plus)
	confirm_quantity.pressed.connect(_on_quantity_confirm)
	cancel_quantity.pressed.connect(_on_quantity_cancel)
	cancel_equip.pressed.connect(_on_equip_cancel)
	cancel_upgrade.pressed.connect(_on_upgrade_cancel)

	_refresh_display()


func _refresh_display() -> void:
	gold_label.text = "Gold: %d" % GameState.party.gold
	if scrap_label:
		scrap_label.text = "Scrap: %d" % GameState.party.scrap
	_update_capacity_label()
	_update_mode_label()
	buy_button.button_pressed = (current_mode == Mode.BUY)
	sell_button.button_pressed = (current_mode == Mode.SELL)
	_refresh_items_list()
	_update_info()
	_update_help()


func _update_mode_label() -> void:
	if mode_label:
		mode_label.text = "< %s >" % MODE_NAMES[current_mode]


func _update_capacity_label() -> void:
	var current := GameState.party.inventory.size() if GameState.party.inventory else 0
	var max_cap := Inventory.MAX_SLOTS
	capacity_label.text = "Inventory: %d/%d" % [current, max_cap]

	var ratio := float(current) / float(max_cap)
	if ratio >= 1.0:
		capacity_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	elif ratio >= 0.8:
		capacity_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	else:
		capacity_label.remove_theme_color_override("font_color")


func _refresh_items_list() -> void:
	for child in items_list.get_children():
		child.queue_free()
	item_buttons.clear()
	displayed_items.clear()

	match current_mode:
		Mode.BUY:
			_populate_buy_list()
		Mode.SELL:
			_populate_sell_list()
		Mode.UPGRADE:
			_populate_upgrade_list()
		Mode.SCRAP:
			_populate_scrap_list()
		Mode.IDENTIFY:
			_populate_identify_list()
		Mode.UNCURSE:
			_populate_uncurse_list()

	nav = MenuNavigatorClass.new()
	if not item_buttons.is_empty():
		nav.setup(item_buttons, 0)
		nav.selection_changed.connect(_on_selection_changed)


func _populate_buy_list() -> void:
	var shop_items := ShopItemsRef.get_shop_inventory()
	shop_items.sort_custom(_sort_by_type_and_price)

	for item in shop_items:
		displayed_items.append(item)
		var btn := _create_buy_button(item)
		items_list.add_child(btn)
		item_buttons.append(btn)

	if item_buttons.is_empty():
		var label := Label.new()
		label.text = "(Shop is empty)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(label)


func _create_buy_button(item: Item) -> Button:
	var btn := Button.new()
	btn.text = "%s - %d gold" % [item.item_name, item.buy_price]
	btn.custom_minimum_size = Vector2(400, 32)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_buy_item.bind(item))

	var can_afford := GameState.party.has_gold(item.buy_price)
	var has_space := not GameState.party.inventory.is_full()

	if not can_afford:
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6)
		btn.tooltip_text = "Not enough gold"
	elif not has_space and not item.is_equipment():
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6)
		btn.tooltip_text = "Inventory full"

	return btn


func _populate_sell_list() -> void:
	if GameState.party.inventory == null or GameState.party.inventory.is_empty():
		var label := Label.new()
		label.text = "(No items to sell)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(label)
		return

	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		var qty: int = GameState.party.inventory.get_quantity_at(i)
		if item:
			displayed_items.append(item)
			var btn := _create_sell_button(i, item, qty)
			items_list.add_child(btn)
			item_buttons.append(btn)


func _create_sell_button(index: int, item: Item, qty: int) -> Button:
	var btn := Button.new()
	var qty_text := " x%d" % qty if qty > 1 else ""
	var marker := "[ ] " if sell_multi_select else ""
	btn.text = "%s%s%s - %d gold" % [marker, item.get_display_name(), qty_text, item.sell_price]
	btn.custom_minimum_size = Vector2(400, 32)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_sell_item.bind(index, item))
	return btn


func _populate_upgrade_list() -> void:
	if GameState.party.inventory == null or GameState.party.inventory.is_empty():
		var label := Label.new()
		label.text = "(No items to upgrade)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(label)
		return

	var found_any := false
	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		if item == null:
			continue
		if not item.is_equipment():
			continue
		if not item.is_identified:
			continue
		if item.is_cursed:
			continue

		var upgradeable := item.get_upgradeable_stats()
		var can_upgrade_any := false
		for stat in upgradeable:
			if item.can_upgrade(stat):
				can_upgrade_any = true
				break

		if not can_upgrade_any:
			continue

		found_any = true
		displayed_items.append(item)
		var btn := _create_upgrade_button(i, item)
		items_list.add_child(btn)
		item_buttons.append(btn)

	if not found_any:
		var label := Label.new()
		label.text = "(No upgradeable items)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(label)


func _create_upgrade_button(index: int, item: Item) -> Button:
	var btn := Button.new()
	btn.text = "%s" % item.get_display_name()
	btn.custom_minimum_size = Vector2(400, 32)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_upgrade_item.bind(index, item))
	return btn


func _populate_scrap_list() -> void:
	if GameState.party.inventory == null or GameState.party.inventory.is_empty():
		var label := Label.new()
		label.text = "(No items to scrap)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(label)
		return

	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		var qty: int = GameState.party.inventory.get_quantity_at(i)
		if item:
			displayed_items.append(item)
			var btn := _create_scrap_button(i, item, qty)
			items_list.add_child(btn)
			item_buttons.append(btn)


func _create_scrap_button(index: int, item: Item, qty: int) -> Button:
	var btn := Button.new()
	var qty_text := " x%d" % qty if qty > 1 else ""
	var marker := "[ ] " if scrap_multi_select else ""
	btn.text = "%s%s%s -> 1-2 scrap" % [marker, item.get_display_name(), qty_text]
	btn.custom_minimum_size = Vector2(400, 32)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_scrap_item.bind(index, item))
	return btn


func _populate_identify_list() -> void:
	if GameState.party.inventory == null or GameState.party.inventory.is_empty():
		var label := Label.new()
		label.text = "(No items to identify)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(label)
		return

	var found_any := false
	for i in range(GameState.party.inventory.size()):
		var item: Item = GameState.party.inventory.get_item_at(i)
		if item == null:
			continue
		if item.is_identified:
			continue

		found_any = true
		displayed_items.append(item)
		var btn := _create_identify_button(i, item)
		items_list.add_child(btn)
		item_buttons.append(btn)

	if not found_any:
		var label := Label.new()
		label.text = "(No unidentified items)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(label)


func _create_identify_button(index: int, item: Item) -> Button:
	var btn := Button.new()
	var cost := item.buy_price / 2
	btn.text = "%s - %d gold" % [item.get_display_name(), cost]
	btn.custom_minimum_size = Vector2(400, 32)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_identify_item.bind(index, item))

	if not GameState.party.has_gold(cost):
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6)
		btn.tooltip_text = "Not enough gold"

	return btn


func _populate_uncurse_list() -> void:
	uncurse_items.clear()

	if GameState.party == null or GameState.party.is_empty():
		var label := Label.new()
		label.text = "(No party members)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(label)
		return

	var found_any := false
	for member in GameState.party.get_members():
		for slot_type in member.get_cursed_slots():
			var item: Item = member.get_equipped_item(slot_type)
			if item:
				found_any = true
				uncurse_items.append({"member": member, "slot": slot_type, "item": item})
				displayed_items.append(item)
				var btn := _create_uncurse_button(uncurse_items.size() - 1, member, item)
				items_list.add_child(btn)
				item_buttons.append(btn)

	if not found_any:
		var label := Label.new()
		label.text = "(No cursed equipment)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_list.add_child(label)


func _create_uncurse_button(index: int, member: Character, item: Item) -> Button:
	var btn := Button.new()
	var cost := item.buy_price
	btn.text = "%s's %s - %d gold" % [member.character_name, item.get_display_name(), cost]
	btn.custom_minimum_size = Vector2(400, 32)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_uncurse_item.bind(index))

	if not GameState.party.has_gold(cost):
		btn.disabled = true
		btn.modulate = Color(0.6, 0.6, 0.6)
		btn.tooltip_text = "Not enough gold"

	return btn


func _sort_by_type_and_price(a: Item, b: Item) -> bool:
	if a.item_type != b.item_type:
		return a.item_type < b.item_type
	return a.buy_price < b.buy_price


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
				class_names.append(CharEnum.get_class_name(c))
			text += "\nClasses: %s" % ", ".join(class_names)

		if not item.required_races.is_empty():
			var race_names: Array[String] = []
			for r in item.required_races:
				race_names.append(CharEnum.get_race_name(r))
			text += "\nRaces: %s" % ", ".join(race_names)
	else:
		text += "\n[color=gray]Unidentified - stats unknown[/color]\n"

	match current_mode:
		Mode.BUY:
			text += "\n\n[color=yellow]Buy: %d gold[/color]" % item.buy_price
		Mode.SELL:
			text += "\n\n[color=green]Sell: %d gold[/color]" % item.sell_price
		Mode.UPGRADE:
			if item.is_equipment() and item.is_identified:
				text += "\n\n[color=cyan]Upgradeable Stats:[/color]"
				for stat in item.get_upgradeable_stats():
					var current_level: int = item.upgrades.get(stat, 0)
					var cost := item.get_upgrade_cost(stat)
					var status := ""
					if current_level >= Item.UPGRADE_CAP:
						status = " [MAX]"
					elif not GameState.party.has_scrap(cost):
						status = " [Need %d scrap]" % cost
					text += "\n  %s +%d%s" % [stat.capitalize(), current_level, status]
		Mode.SCRAP:
			text += "\n\n[color=orange]Scrap yield: 1-2[/color]"
		Mode.IDENTIFY:
			var cost := item.buy_price / 2
			text += "\n\n[color=yellow]Identify cost: %d gold[/color]" % cost
		Mode.UNCURSE:
			text += "\n\n[color=red]Uncurse cost: %d gold[/color]" % item.buy_price
			text += "\n[color=gray]Item will be destroyed[/color]"

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

	var can_equip := item.can_equip(member)
	var current_item: Item = member.get_equipped_item(item.item_type)

	var diff_label := Label.new()
	diff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if not can_equip:
		diff_label.text = "[Cannot equip]"
		diff_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	else:
		var diff_text := _get_stat_diff(current_item, item)
		diff_label.text = diff_text
		if diff_text.begins_with("+"):
			diff_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
		elif diff_text.begins_with("-"):
			diff_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))

	row.add_child(diff_label)
	return row


func _get_stat_diff(current: Item, new_item: Item) -> String:
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


func _update_help() -> void:
	var h_nav := KeyBindingHelperClass.get_horizontal_help()
	var v_nav := KeyBindingHelperClass.get_nav_help()
	var confirm := KeyBindingHelperClass.get_confirm_help()
	var cancel := KeyBindingHelperClass.get_cancel_help()

	match current_mode:
		Mode.BUY:
			help_label.text = "%s mode | %s | %s: Buy | %s" % [h_nav, v_nav, confirm.split(":")[0], cancel]
		Mode.SELL:
			if sell_multi_select:
				help_label.text = "S: Toggle | A: Select all | %s: Sell | %s" % [confirm.split(":")[0], cancel]
			else:
				help_label.text = "%s mode | %s | S: Multi | %s: Sell | %s" % [h_nav, v_nav, confirm.split(":")[0], cancel]
		Mode.UPGRADE:
			help_label.text = "%s mode | %s | %s: Upgrade | %s" % [h_nav, v_nav, confirm.split(":")[0], cancel]
		Mode.SCRAP:
			if scrap_multi_select:
				help_label.text = "S: Toggle | A: Select all | %s: Scrap | %s" % [confirm.split(":")[0], cancel]
			else:
				help_label.text = "%s mode | %s | S: Multi | %s: Scrap | %s" % [h_nav, v_nav, confirm.split(":")[0], cancel]
		Mode.IDENTIFY:
			help_label.text = "%s mode | %s | %s: Identify | %s" % [h_nav, v_nav, confirm.split(":")[0], cancel]
		Mode.UNCURSE:
			help_label.text = "%s mode | %s | %s: Uncurse | %s" % [h_nav, v_nav, confirm.split(":")[0], cancel]


func _on_buy_item(item: Item) -> void:
	if not GameState.party.has_gold(item.buy_price):
		message_label.text = "Not enough gold!"
		return

	selected_item = item

	if item.item_type == Item.ItemType.CONSUMABLE:
		_show_quantity_dialog(item)
	elif item.is_equipment():
		_show_equip_dialog(item)
	else:
		_buy_to_inventory(item, 1)


func _show_quantity_dialog(item: Item) -> void:
	buy_state = BuyState.QUANTITY_SELECT
	selected_quantity = 1

	var max_afford := GameState.party.gold / item.buy_price
	var space_left := Inventory.MAX_SLOTS - GameState.party.inventory.size()
	max_quantity = mini(max_afford, space_left)
	max_quantity = maxi(1, max_quantity)

	quantity_title.text = "Buy %s" % item.item_name
	_update_quantity_display()
	modal_overlay.visible = true
	quantity_dialog.visible = true
	confirm_quantity.grab_focus()


func _update_quantity_display() -> void:
	quantity_value.text = str(selected_quantity)
	total_label.text = "Total: %d gold" % (selected_quantity * selected_item.buy_price)

	minus_button.disabled = (selected_quantity <= 1)
	plus_button.disabled = (selected_quantity >= max_quantity)


func _on_quantity_minus() -> void:
	if selected_quantity > 1:
		selected_quantity -= 1
		_update_quantity_display()


func _on_quantity_plus() -> void:
	if selected_quantity < max_quantity:
		selected_quantity += 1
		_update_quantity_display()


func _on_quantity_confirm() -> void:
	modal_overlay.visible = false
	quantity_dialog.visible = false
	buy_state = BuyState.BROWSING
	_buy_to_inventory(selected_item, selected_quantity)
	selected_item = null


func _on_quantity_cancel() -> void:
	modal_overlay.visible = false
	quantity_dialog.visible = false
	buy_state = BuyState.BROWSING
	selected_item = null
	if nav and not item_buttons.is_empty():
		nav._update_focus()


func _show_equip_dialog(item: Item) -> void:
	buy_state = BuyState.EQUIP_SELECT
	equip_item_name.text = "%s - %d gold" % [item.item_name, item.buy_price]

	for child in equip_options.get_children():
		child.queue_free()
	equip_buttons.clear()
	selected_members.clear()

	var inv_btn := Button.new()
	inv_btn.text = "Add to Inventory"
	inv_btn.custom_minimum_size = Vector2(0, 32)

	if GameState.party.inventory.is_full():
		inv_btn.disabled = true
		inv_btn.modulate = Color(0.6, 0.6, 0.6)
		inv_btn.tooltip_text = "Inventory full"
	inv_btn.pressed.connect(_on_equip_to_inventory)
	equip_options.add_child(inv_btn)
	equip_buttons.append(inv_btn)

	for member in GameState.party.get_members():
		var btn := Button.new()
		var can_equip := item.can_equip(member)
		var old_item: Item = member.get_equipped_item(item.item_type)

		var will_overflow := false
		if old_item and GameState.party.inventory.is_full():
			will_overflow = true

		if can_equip and not will_overflow:
			var diff := _get_stat_diff(old_item, item)
			btn.text = "Equip on %s (%s)" % [member.character_name, diff]
		elif will_overflow:
			btn.text = "%s (inventory full for old item)" % member.character_name
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)
		else:
			btn.text = "%s (cannot equip)" % member.character_name
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)

		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_equip_to_member.bind(member))
		equip_options.add_child(btn)
		equip_buttons.append(btn)
		selected_members.append(member)

	equip_nav = MenuNavigatorClass.new()
	equip_nav.setup(equip_buttons, 0)

	modal_overlay.visible = true
	equip_dialog.visible = true


func _on_equip_to_inventory() -> void:
	modal_overlay.visible = false
	equip_dialog.visible = false
	buy_state = BuyState.BROWSING
	_buy_to_inventory(selected_item, 1)
	selected_item = null


func _on_equip_to_member(member: Character) -> void:
	if not selected_item.can_equip(member):
		return

	var old_item: Item = member.get_equipped_item(selected_item.item_type)
	if old_item and GameState.party.inventory.is_full():
		message_label.text = "Inventory full! Cannot store old equipment."
		return

	if not GameState.party.spend_gold(selected_item.buy_price):
		message_label.text = "Not enough gold!"
		return

	var new_item := selected_item.duplicate() as Item
	var unequipped: Item = member.equip_item(new_item)

	if unequipped:
		GameState.party.inventory.add_item(unequipped, 1)

	message_label.text = "Equipped %s on %s for %d gold." % [selected_item.item_name, member.character_name, selected_item.buy_price]

	modal_overlay.visible = false
	equip_dialog.visible = false
	buy_state = BuyState.BROWSING
	selected_item = null
	_refresh_display()


func _on_equip_cancel() -> void:
	modal_overlay.visible = false
	equip_dialog.visible = false
	buy_state = BuyState.BROWSING
	selected_item = null
	if nav and not item_buttons.is_empty():
		nav._update_focus()


func _buy_to_inventory(item: Item, quantity: int) -> void:
	var total_cost := item.buy_price * quantity

	if not GameState.party.has_gold(total_cost):
		message_label.text = "Not enough gold!"
		return

	GameState.party.spend_gold(total_cost)

	var added := 0
	for i in range(quantity):
		var new_item := item.duplicate() as Item
		var leftover := GameState.party.inventory.add_item(new_item, 1)
		if leftover == 0:
			added += 1
		else:
			GameState.party.add_gold(item.buy_price)
			break

	if added == quantity:
		message_label.text = "Bought %d %s for %d gold." % [quantity, item.item_name, total_cost]
	elif added > 0:
		message_label.text = "Bought %d %s (inventory full)." % [added, item.item_name]
	else:
		message_label.text = "Inventory is full!"

	_refresh_display()


func _on_sell_item(slot_index: int, item: Item) -> void:
	if sell_multi_select:
		_toggle_sell_selection(slot_index)
		return

	var removed := GameState.party.inventory.remove_item(item.id, 1)
	if removed > 0:
		GameState.party.add_gold(item.sell_price)
		message_label.text = "Sold %s for %d gold." % [item.item_name, item.sell_price]
	else:
		message_label.text = "Failed to sell item."

	_refresh_display()
	if nav and not item_buttons.is_empty():
		nav.select(0)


func _toggle_sell_selection(index: int) -> void:
	if index in sell_selected_indices:
		sell_selected_indices.erase(index)
	else:
		sell_selected_indices.append(index)
	_update_sell_button_markers()


func _update_sell_button_markers() -> void:
	for i in range(item_buttons.size()):
		var btn := item_buttons[i]
		var item: Item = displayed_items[i] if i < displayed_items.size() else null
		if item == null:
			continue

		var qty: int = GameState.party.inventory.get_quantity_at(i)
		var qty_text := " x%d" % qty if qty > 1 else ""
		var marker := "[X] " if i in sell_selected_indices else "[ ] "
		btn.text = "%s%s%s - %d gold" % [marker, item.item_name, qty_text, item.sell_price]


func _sell_selected_items() -> void:
	if sell_selected_indices.is_empty():
		message_label.text = "No items selected to sell."
		return

	sell_selected_indices.sort()
	sell_selected_indices.reverse()

	var total_gold := 0
	var sold_count := 0

	for idx in sell_selected_indices:
		if idx >= displayed_items.size():
			continue
		var item: Item = displayed_items[idx]
		var removed := GameState.party.inventory.remove_item(item.id, 1)
		if removed > 0:
			total_gold += item.sell_price
			sold_count += 1

	GameState.party.add_gold(total_gold)
	message_label.text = "Sold %d items for %d gold." % [sold_count, total_gold]

	sell_multi_select = false
	sell_selected_indices.clear()
	_refresh_display()
	if nav and not item_buttons.is_empty():
		nav.select(0)


func _select_all_for_sell() -> void:
	sell_selected_indices.clear()
	for i in range(displayed_items.size()):
		sell_selected_indices.append(i)
	_update_sell_button_markers()


func _on_upgrade_item(index: int, item: Item) -> void:
	selected_item = item
	selected_inventory_index = index
	upgradeable_stats = item.get_upgradeable_stats()
	_show_upgrade_dialog(item)


func _show_upgrade_dialog(item: Item) -> void:
	upgrade_state = UpgradeState.STAT_SELECT
	upgrade_item_name.text = item.get_display_name()

	for child in upgrade_options.get_children():
		child.queue_free()
	upgrade_stat_buttons.clear()

	for stat in upgradeable_stats:
		if not item.can_upgrade(stat):
			continue

		var btn := Button.new()
		var current_level: int = item.upgrades.get(stat, 0)
		var cost := item.get_upgrade_cost(stat)
		btn.text = "%s +%d -> +%d (%d scrap)" % [stat.capitalize(), current_level, current_level + 1, cost]
		btn.custom_minimum_size = Vector2(0, 32)

		if not GameState.party.has_scrap(cost):
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)
			btn.tooltip_text = "Not enough scrap"

		btn.pressed.connect(_on_upgrade_stat_selected.bind(stat))
		upgrade_options.add_child(btn)
		upgrade_stat_buttons.append(btn)

	upgrade_stat_nav = MenuNavigatorClass.new()
	if not upgrade_stat_buttons.is_empty():
		upgrade_stat_nav.setup(upgrade_stat_buttons, 0)

	modal_overlay.visible = true
	upgrade_dialog.visible = true


func _on_upgrade_stat_selected(stat: String) -> void:
	if selected_item == null:
		return

	var cost := selected_item.get_upgrade_cost(stat)
	if not GameState.party.spend_scrap(cost):
		message_label.text = "Not enough scrap!"
		return

	selected_item.apply_upgrade(stat)
	message_label.text = "Upgraded %s's %s for %d scrap." % [selected_item.get_display_name(), stat, cost]

	modal_overlay.visible = false
	upgrade_dialog.visible = false
	upgrade_state = UpgradeState.BROWSING
	selected_item = null
	selected_inventory_index = -1
	_refresh_display()


func _on_upgrade_cancel() -> void:
	modal_overlay.visible = false
	upgrade_dialog.visible = false
	upgrade_state = UpgradeState.BROWSING
	selected_item = null
	selected_inventory_index = -1
	if nav and not item_buttons.is_empty():
		nav._update_focus()


func _on_scrap_item(index: int, item: Item) -> void:
	if scrap_multi_select:
		_toggle_scrap_selection(index)
		return

	var scrap_yield := randi_range(1, 2)
	var removed := GameState.party.inventory.remove_item(item.id, 1)
	if removed > 0:
		GameState.party.add_scrap(scrap_yield)
		message_label.text = "Scrapped %s for %d scrap." % [item.get_display_name(), scrap_yield]
	else:
		message_label.text = "Failed to scrap item."

	_refresh_display()
	if nav and not item_buttons.is_empty():
		nav.select(0)


func _toggle_scrap_selection(index: int) -> void:
	if index in scrap_selected_indices:
		scrap_selected_indices.erase(index)
	else:
		scrap_selected_indices.append(index)
	_update_scrap_button_markers()


func _update_scrap_button_markers() -> void:
	for i in range(item_buttons.size()):
		var btn := item_buttons[i]
		var item: Item = displayed_items[i] if i < displayed_items.size() else null
		if item == null:
			continue

		var qty: int = GameState.party.inventory.get_quantity_at(i)
		var qty_text := " x%d" % qty if qty > 1 else ""
		var marker := "[X] " if i in scrap_selected_indices else "[ ] "
		btn.text = "%s%s%s -> 1-2 scrap" % [marker, item.get_display_name(), qty_text]


func _scrap_selected_items() -> void:
	if scrap_selected_indices.is_empty():
		message_label.text = "No items selected to scrap."
		return

	scrap_selected_indices.sort()
	scrap_selected_indices.reverse()

	var total_scrap := 0
	var scrapped_count := 0

	for idx in scrap_selected_indices:
		if idx >= displayed_items.size():
			continue
		var item: Item = displayed_items[idx]
		var removed := GameState.party.inventory.remove_item(item.id, 1)
		if removed > 0:
			var scrap_yield := randi_range(1, 2)
			total_scrap += scrap_yield
			scrapped_count += 1

	GameState.party.add_scrap(total_scrap)
	message_label.text = "Scrapped %d items for %d scrap." % [scrapped_count, total_scrap]

	scrap_multi_select = false
	scrap_selected_indices.clear()
	_refresh_display()
	if nav and not item_buttons.is_empty():
		nav.select(0)


func _select_all_for_scrap() -> void:
	scrap_selected_indices.clear()
	for i in range(displayed_items.size()):
		scrap_selected_indices.append(i)
	_update_scrap_button_markers()


func _on_identify_item(_index: int, item: Item) -> void:
	var cost := item.buy_price / 2
	if not GameState.party.spend_gold(cost):
		message_label.text = "Not enough gold!"
		return

	item.is_identified = true
	message_label.text = "Identified %s for %d gold." % [item.get_display_name(), cost]

	_refresh_display()
	if nav and not item_buttons.is_empty():
		nav.select(0)


func _on_uncurse_item(index: int) -> void:
	if index < 0 or index >= uncurse_items.size():
		return

	var data: Dictionary = uncurse_items[index]
	var member: Character = data["member"]
	var slot: Item.ItemType = data["slot"]
	var item: Item = data["item"]

	var cost := item.buy_price
	if not GameState.party.spend_gold(cost):
		message_label.text = "Not enough gold!"
		return

	member.force_unequip_slot(slot)
	message_label.text = "Uncursed and destroyed %s from %s for %d gold." % [item.get_display_name(), member.character_name, cost]

	_refresh_display()
	if nav and not item_buttons.is_empty():
		nav.select(0)


func _on_buy_mode() -> void:
	_set_mode(Mode.BUY)


func _on_sell_mode() -> void:
	_set_mode(Mode.SELL)


func _set_mode(mode: Mode) -> void:
	if current_mode == mode:
		return
	current_mode = mode
	sell_multi_select = false
	sell_selected_indices.clear()
	scrap_multi_select = false
	scrap_selected_indices.clear()
	match mode:
		Mode.BUY:
			message_label.text = "Select an item to buy."
		Mode.SELL:
			message_label.text = "Select an item to sell."
		Mode.UPGRADE:
			message_label.text = "Select an item to upgrade."
		Mode.SCRAP:
			message_label.text = "Select an item to scrap."
		Mode.IDENTIFY:
			message_label.text = "Select an item to identify."
		Mode.UNCURSE:
			message_label.text = "Select cursed equipment to remove."
	_refresh_display()


func _cycle_mode(direction: int) -> void:
	var new_mode := (current_mode + direction) % Mode.size()
	if new_mode < 0:
		new_mode = Mode.size() - 1
	_set_mode(new_mode as Mode)


func _unhandled_input(event: InputEvent) -> void:
	if buy_state == BuyState.QUANTITY_SELECT:
		_handle_quantity_input(event)
		return

	if buy_state == BuyState.EQUIP_SELECT:
		_handle_equip_input(event)
		return

	if upgrade_state == UpgradeState.STAT_SELECT:
		_handle_upgrade_input(event)
		return

	if event.is_action_pressed("menu_cancel"):
		if sell_multi_select:
			sell_multi_select = false
			sell_selected_indices.clear()
			_refresh_display()
			return
		if scrap_multi_select:
			scrap_multi_select = false
			scrap_selected_indices.clear()
			_refresh_display()
			return
		_on_back_pressed()
		return

	if event.is_action_pressed("menu_left"):
		_cycle_mode(-1)
		return
	elif event.is_action_pressed("menu_right"):
		_cycle_mode(1)
		return

	if current_mode == Mode.SELL:
		if event.is_action_pressed("menu_select"):
			if not sell_multi_select:
				sell_multi_select = true
				_refresh_display()
				_update_help()
			elif nav:
				_toggle_sell_selection(nav.get_current_index())
			return
		elif event.is_action_pressed("menu_select_all") and sell_multi_select:
			_select_all_for_sell()
			return

	if current_mode == Mode.SCRAP:
		if event.is_action_pressed("menu_select"):
			if not scrap_multi_select:
				scrap_multi_select = true
				_refresh_display()
				_update_help()
			elif nav:
				_toggle_scrap_selection(nav.get_current_index())
			return
		elif event.is_action_pressed("menu_select_all") and scrap_multi_select:
			_select_all_for_scrap()
			return

	if nav:
		if event.is_action_pressed("menu_up"):
			nav._move(-1)
			_update_info()
			_update_comparison()
		elif event.is_action_pressed("menu_down"):
			nav._move(1)
			_update_info()
			_update_comparison()
		elif event.is_action_pressed("menu_confirm"):
			if sell_multi_select and not sell_selected_indices.is_empty():
				_sell_selected_items()
			elif scrap_multi_select and not scrap_selected_indices.is_empty():
				_scrap_selected_items()
			else:
				nav._confirm()


func _handle_quantity_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		_on_quantity_cancel()
	elif event.is_action_pressed("menu_confirm"):
		_on_quantity_confirm()
	elif event.is_action_pressed("menu_left"):
		_on_quantity_minus()
	elif event.is_action_pressed("menu_right"):
		_on_quantity_plus()


func _handle_equip_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		_on_equip_cancel()
	elif equip_nav:
		if event.is_action_pressed("menu_up"):
			equip_nav._move(-1)
		elif event.is_action_pressed("menu_down"):
			equip_nav._move(1)
		elif event.is_action_pressed("menu_confirm"):
			equip_nav._confirm()


func _handle_upgrade_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		_on_upgrade_cancel()
	elif upgrade_stat_nav:
		if event.is_action_pressed("menu_up"):
			upgrade_stat_nav._move(-1)
		elif event.is_action_pressed("menu_down"):
			upgrade_stat_nav._move(1)
		elif event.is_action_pressed("menu_confirm"):
			upgrade_stat_nav._confirm()


func _on_back_pressed() -> void:
	SceneManager.go_to_town()

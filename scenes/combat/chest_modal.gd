extends PanelContainer

signal chest_resolved(items: Array[Item], left_behind: bool)
signal combat_triggered()

var chest: Chest = null
var party: Party = null
var opener: Character = null
var option_nav: MenuNavigator = null
var option_buttons: Array[Button] = []
var _loot_items: Array[Item] = []
var _loot_left_behind: bool = false

@onready var header_label: Label = $ChestModalVBox/ChestModalHeader
@onready var description_label: Label = $ChestModalVBox/DescriptionLabel
@onready var trap_warning_label: Label = $ChestModalVBox/TrapWarningLabel
@onready var status_label: RichTextLabel = $ChestModalVBox/StatusLabel
@onready var options_vbox: VBoxContainer = $ChestModalVBox/OptionsVBox
@onready var leave_button: Button = $ChestModalVBox/LeaveButton


func _ready() -> void:
	leave_button.pressed.connect(_on_leave)


func setup(p_chest: Chest, p_party: Party) -> void:
	chest = p_chest
	party = p_party
	opener = party.get_alive_members()[0] if not party.get_alive_members().is_empty() else null

	_update_header()
	_update_trap_warning()
	_populate_options()
	status_label.clear()

	if option_nav and not option_buttons.is_empty():
		option_nav.setup(option_buttons, 0)


func _update_header() -> void:
	match chest.chest_type:
		Chest.ChestType.PLAIN:
			header_label.text = "A small chest appears..."
			description_label.text = "It looks ordinary, but may still be trapped."
		Chest.ChestType.ORNATE:
			header_label.text = "An ornate chest appears..."
			description_label.text = "This chest appears valuable. It's likely trapped."


func _update_trap_warning() -> void:
	if chest.trap_identified and chest.is_trapped and chest.trap != null:
		trap_warning_label.visible = true
		if chest.trap_disarmed:
			trap_warning_label.text = "Trap disarmed: %s" % chest.trap.trap_name
			trap_warning_label.add_theme_color_override("font_color", UIColors.TEXT_HEALTHY)
		else:
			trap_warning_label.text = "Trap detected: %s" % chest.trap.trap_name
			trap_warning_label.add_theme_color_override("font_color", UIColors.TEXT_DANGER)
	else:
		trap_warning_label.visible = false


func _populate_options() -> void:
	for child in options_vbox.get_children():
		child.queue_free()
	option_buttons.clear()

	var thief: Character = party.get_living_thief()
	var has_thief := thief != null

	if has_thief and chest.chest_type == Chest.ChestType.PLAIN:
		var quick_btn := Button.new()
		quick_btn.text = "Quick Open (%s)" % thief.get_display_name()
		quick_btn.custom_minimum_size = Vector2(0, 36)
		quick_btn.pressed.connect(_on_quick_open)
		options_vbox.add_child(quick_btn)
		option_buttons.append(quick_btn)

	var inspect_btn := Button.new()
	inspect_btn.text = "Inspect"
	inspect_btn.custom_minimum_size = Vector2(0, 36)
	inspect_btn.pressed.connect(_on_inspect)
	options_vbox.add_child(inspect_btn)
	option_buttons.append(inspect_btn)

	if chest.trap_identified and chest.is_trapped and not chest.trap_disarmed:
		var disarm_btn := Button.new()
		disarm_btn.text = "Disarm Trap"
		disarm_btn.custom_minimum_size = Vector2(0, 36)
		disarm_btn.pressed.connect(_on_disarm)
		options_vbox.add_child(disarm_btn)
		option_buttons.append(disarm_btn)

	var open_btn := Button.new()
	open_btn.text = "Open"
	open_btn.custom_minimum_size = Vector2(0, 36)
	open_btn.pressed.connect(_on_open)
	options_vbox.add_child(open_btn)
	option_buttons.append(open_btn)

	option_buttons.append(leave_button)

	option_nav = MenuNavigator.new()
	if not option_buttons.is_empty():
		option_nav.setup(option_buttons, 0)


func _add_status_message(message: String) -> void:
	status_label.append_text(message + "\n")


func _on_quick_open() -> void:
	var thief: Character = party.get_living_thief()
	if thief == null:
		return

	var result := ChestSystem.quick_open(chest, thief, party)

	for msg in result.messages:
		_add_status_message(msg)

	if result.get("combat_triggered", false):
		await get_tree().create_timer(1.0).timeout
		combat_triggered.emit()
		return

	if result.get("party_wiped", false):
		await get_tree().create_timer(1.0).timeout
		var no_items: Array[Item] = []
		chest_resolved.emit(no_items, false)
		return

	if result.success:
		await get_tree().create_timer(0.5).timeout
		_collect_items()
	else:
		_update_trap_warning()
		_populate_options()


func _on_inspect() -> void:
	var inspector := _get_best_inspector()
	var result := ChestSystem.attempt_inspect(chest, inspector)

	_add_status_message(result.message)
	_update_trap_warning()
	_populate_options()


func _on_disarm() -> void:
	var disarmer := _get_best_disarmer()
	var result := ChestSystem.attempt_disarm(chest, disarmer)

	_add_status_message(result.message)

	if not result.success:
		var trap_result := ChestSystem.trigger_trap(chest, disarmer, party)
		for msg in trap_result.messages:
			_add_status_message(msg)

		if trap_result.get("combat_triggered", false):
			await get_tree().create_timer(1.0).timeout
			combat_triggered.emit()
			return

		if trap_result.get("party_wiped", false):
			await get_tree().create_timer(1.0).timeout
			var no_items: Array[Item] = []
			chest_resolved.emit(no_items, false)
			return

	_update_trap_warning()
	_populate_options()


func _on_open() -> void:
	var result := ChestSystem.open_chest(chest, opener, party)

	for msg in result.messages:
		_add_status_message(msg)

	if result.get("combat_triggered", false):
		await get_tree().create_timer(1.0).timeout
		combat_triggered.emit()
		return

	if result.get("party_wiped", false):
		await get_tree().create_timer(1.0).timeout
		var no_items: Array[Item] = []
		chest_resolved.emit(no_items, false)
		return

	if result.success:
		await get_tree().create_timer(0.5).timeout
		_collect_items()


func _on_leave() -> void:
	var empty_items: Array[Item] = []
	chest_resolved.emit(empty_items, true)


func _collect_items() -> void:
	var items_collected: Array[Item] = []
	var items_left_behind: Array[Item] = []

	for item in chest.contents:
		var remaining := GameState.party.inventory.add_item(item)
		if remaining == 0:
			items_collected.append(item)
		else:
			items_left_behind.append(item)

	_loot_items = items_collected
	_loot_left_behind = not items_left_behind.is_empty()
	_show_loot_summary(items_collected, items_left_behind)


func _show_loot_summary(collected: Array[Item], left_behind: Array[Item]) -> void:
	for child in options_vbox.get_children():
		child.queue_free()
	option_buttons.clear()

	status_label.clear()
	var summary := "[color=cyan]Loot collected:[/color]\n"
	for item in collected:
		summary += "  [color=cyan]%s[/color]\n" % item.get_display_name()
	if collected.is_empty():
		summary += "  (nothing)\n"
	if not left_behind.is_empty():
		summary += "\n[color=yellow]Left behind (inventory full):[/color]\n"
		for item in left_behind:
			summary += "  [color=yellow]%s[/color]\n" % item.get_display_name()
	status_label.append_text(summary)

	if leave_button.pressed.is_connected(_on_leave):
		leave_button.pressed.disconnect(_on_leave)
	if not leave_button.pressed.is_connected(_on_loot_continue):
		leave_button.pressed.connect(_on_loot_continue)
	leave_button.text = "Continue"

	option_buttons.append(leave_button)
	option_nav = MenuNavigator.new()
	option_nav.setup(option_buttons, 0)


func _on_loot_continue() -> void:
	chest_resolved.emit(_loot_items, _loot_left_behind)


func _get_best_inspector() -> Character:
	var thief: Character = party.get_living_thief()
	if thief:
		return thief
	return opener


func _get_best_disarmer() -> Character:
	var thief: Character = party.get_living_thief()
	if thief:
		return thief
	return opener


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if option_nav:
		if event.is_action_pressed("menu_up"):
			option_nav._move(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("menu_down"):
			option_nav._move(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("menu_confirm"):
			option_nav._confirm()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("menu_cancel"):
			_on_leave()
			get_viewport().set_input_as_handled()

extends Control

enum Mode { SERVICE_SELECT, MEMBER_SELECT }
enum ServiceType { RESURRECT, CURE_STATUS, TITHE }

const SERVICES: Array[Dictionary] = [
	{
		"type": ServiceType.RESURRECT,
		"name": "Resurrection",
		"description": "Restore a fallen party member to life. The process is taxing and may cost the recipient some Vitality."
	},
	{
		"type": ServiceType.CURE_STATUS,
		"name": "Cure Ailments",
		"description": "Remove debilitating conditions such as poison, paralysis, blindness, or curses through divine intervention."
	},
	{
		"type": ServiceType.TITHE,
		"name": "Tithe for Blessing",
		"description": "Make a donation to receive the Temple's blessing, granting your party divine favor in combat."
	}
]

const CURABLE_STATUSES: Array[CharacterEnums.StatusEffect] = [
	CharacterEnums.StatusEffect.POISONED,
	CharacterEnums.StatusEffect.PARALYZED,
	CharacterEnums.StatusEffect.SILENCED,
	CharacterEnums.StatusEffect.BLINDED,
	CharacterEnums.StatusEffect.CURSED,
	CharacterEnums.StatusEffect.CONFUSED,
	CharacterEnums.StatusEffect.STONED
]

const RESURRECT_BASE_COST: int = 100
const RESURRECT_PER_LEVEL: int = 25
const CURE_BASE_COST: int = 25
const CURE_PER_LEVEL: int = 10
const TITHE_AMOUNTS: Array[int] = [100, 500, 1000]
const BLESSING_DURATION: int = 10

var current_mode: Mode = Mode.SERVICE_SELECT
var selected_service: ServiceType = ServiceType.RESURRECT
var selected_member: Character = null
var selected_status: CharacterEnums.StatusEffect = CharacterEnums.StatusEffect.NONE

var nav: MenuNavigator = null
var buttons: Array[Button] = []

@onready var title_label: Label = $MainHBox/LeftPanel/Header/TitleLabel
@onready var gold_label: Label = $MainHBox/LeftPanel/Header/GoldLabel
@onready var options_panel: PanelContainer = $MainHBox/LeftPanel/OptionsPanel
@onready var options_list: VBoxContainer = $MainHBox/LeftPanel/OptionsPanel/ScrollContainer/OptionsList
@onready var message_label: Label = $MainHBox/LeftPanel/MessageLabel
@onready var help_label: Label = $MainHBox/LeftPanel/HelpLabel
@onready var back_button: Button = $MainHBox/LeftPanel/BackButton

@onready var info_panel: PanelContainer = $MainHBox/RightPanel/InfoPanel
@onready var info_label: RichTextLabel = $MainHBox/RightPanel/InfoPanel/InfoLabel
@onready var party_label: Label = $MainHBox/RightPanel/PartyLabel
@onready var party_panel: PanelContainer = $MainHBox/RightPanel/PartyPanel
@onready var party_list: VBoxContainer = $MainHBox/RightPanel/PartyPanel/ScrollContainer/PartyList


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_refresh_display()


func _refresh_display() -> void:
	gold_label.text = "Gold: %d" % GameState.party.gold
	_update_party_display()

	if current_mode == Mode.SERVICE_SELECT:
		_populate_services()
		message_label.text = "Welcome to the Temple. How may we serve you?"
	else:
		_populate_members_for_service()

	_update_info()
	_update_help()


func _populate_services() -> void:
	_clear_options()

	if GameState.party.is_empty():
		var label := Label.new()
		label.text = "(No party members)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		options_list.add_child(label)
		return

	for service in SERVICES:
		var btn := Button.new()
		btn.text = service["name"]
		btn.custom_minimum_size = Vector2(350, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		var service_type: ServiceType = service["type"]
		var available := _is_service_available(service_type)

		if not available:
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)

		btn.pressed.connect(_on_service_selected.bind(service_type))
		options_list.add_child(btn)
		buttons.append(btn)

	_setup_nav()


func _populate_members_for_service() -> void:
	_clear_options()

	match selected_service:
		ServiceType.RESURRECT:
			_populate_dead_members()
			message_label.text = "Select a fallen member to resurrect."
		ServiceType.CURE_STATUS:
			_populate_afflicted_members()
			message_label.text = "Select a member to cure."
		ServiceType.TITHE:
			_populate_tithe_options()
			message_label.text = "Choose your offering amount."

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(350, 36)
	cancel_btn.pressed.connect(_on_cancel_service)
	options_list.add_child(cancel_btn)
	buttons.append(cancel_btn)

	_setup_nav()


func _populate_dead_members() -> void:
	for member in GameState.party.get_members():
		if not member.is_dead:
			continue

		var cost := _calculate_resurrect_cost(member)
		var btn := Button.new()
		btn.text = "%s (L%d) - %d gold" % [member.character_name, member.level, cost]
		btn.custom_minimum_size = Vector2(350, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if member.has_status(CharacterEnums.StatusEffect.ASHED):
			btn.add_theme_color_override("font_color", Color(0.7, 0.4, 0.1))
			btn.tooltip_text = "Ashed - lower success chance"
		elif member.has_status(CharacterEnums.StatusEffect.LOST):
			btn.disabled = true
			btn.modulate = Color(0.4, 0.4, 0.4)
			btn.tooltip_text = "Lost forever - cannot be resurrected"

		if not GameState.party.has_gold(cost):
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)
			btn.tooltip_text = "Not enough gold"

		btn.pressed.connect(_on_resurrect_member.bind(member))
		options_list.add_child(btn)
		buttons.append(btn)


func _populate_afflicted_members() -> void:
	for member in GameState.party.get_members():
		if member.is_dead:
			continue

		var curable := _get_curable_statuses(member)
		if curable.is_empty():
			continue

		for status in curable:
			var cost := _calculate_cure_cost(member)
			var status_name := CharacterEnums.get_status_name(status)
			var btn := Button.new()
			btn.text = "%s - Cure %s - %d gold" % [member.character_name, status_name, cost]
			btn.custom_minimum_size = Vector2(350, 36)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

			if not GameState.party.has_gold(cost):
				btn.disabled = true
				btn.modulate = Color(0.6, 0.6, 0.6)

			btn.pressed.connect(_on_cure_member.bind(member, status))
			options_list.add_child(btn)
			buttons.append(btn)


func _populate_tithe_options() -> void:
	for amount in TITHE_AMOUNTS:
		var btn := Button.new()
		var duration := BLESSING_DURATION + amount / 100
		btn.text = "Offer %d gold - Blessing for %d turns" % [amount, duration]
		btn.custom_minimum_size = Vector2(350, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if not GameState.party.has_gold(amount):
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6)

		btn.pressed.connect(_on_tithe.bind(amount))
		options_list.add_child(btn)
		buttons.append(btn)


func _clear_options() -> void:
	for child in options_list.get_children():
		child.queue_free()
	buttons.clear()
	nav = null


func _setup_nav() -> void:
	if buttons.is_empty():
		return

	nav = MenuNavigator.new()
	nav.setup(buttons, 0)
	nav.selection_changed.connect(_on_selection_changed)


func _is_service_available(service_type: ServiceType) -> bool:
	match service_type:
		ServiceType.RESURRECT:
			for member in GameState.party.get_members():
				if member.is_dead and not member.has_status(CharacterEnums.StatusEffect.LOST):
					return true
			return false
		ServiceType.CURE_STATUS:
			for member in GameState.party.get_members():
				if not member.is_dead and not _get_curable_statuses(member).is_empty():
					return true
			return false
		ServiceType.TITHE:
			for amount in TITHE_AMOUNTS:
				if GameState.party.has_gold(amount):
					return true
			return false
	return false


func _calculate_resurrect_cost(member: Character) -> int:
	var base := RESURRECT_BASE_COST + member.level * RESURRECT_PER_LEVEL
	if member.has_status(CharacterEnums.StatusEffect.ASHED):
		base = int(base * 2.0)
	return base


func _calculate_cure_cost(member: Character) -> int:
	return CURE_BASE_COST + member.level * CURE_PER_LEVEL


func _get_curable_statuses(member: Character) -> Array[CharacterEnums.StatusEffect]:
	var result: Array[CharacterEnums.StatusEffect] = []
	for status in CURABLE_STATUSES:
		if member.has_status(status):
			result.append(status)
	return result


func _on_selection_changed(_index: int) -> void:
	_update_info()


func _update_info() -> void:
	if nav == null or buttons.is_empty():
		info_label.text = "Select a service."
		return

	var idx := nav.get_current_index()

	if current_mode == Mode.SERVICE_SELECT:
		_update_service_info(idx)
	else:
		_update_member_info(idx)


func _update_service_info(idx: int) -> void:
	if idx < 0 or idx >= SERVICES.size():
		info_label.text = "Select a service."
		return

	var service: Dictionary = SERVICES[idx]
	var service_type: ServiceType = service["type"]

	var text := "[b]%s[/b]\n\n" % service["name"]
	text += "%s\n\n" % service["description"]

	match service_type:
		ServiceType.RESURRECT:
			text += "[color=yellow]Cost:[/color] %d + %d per level\n" % [RESURRECT_BASE_COST, RESURRECT_PER_LEVEL]
			text += "[color=yellow]Ashed characters:[/color] Double cost, 50%% success\n\n"
			text += "[color=cyan]Warning:[/color] Resurrection may cost 1 Vitality.\n"
			text += "If Vitality reaches 0, the character is lost forever.\n\n"

			var dead_count := 0
			var ashed_count := 0
			var lost_count := 0
			for member in GameState.party.get_members():
				if member.has_status(CharacterEnums.StatusEffect.LOST):
					lost_count += 1
				elif member.has_status(CharacterEnums.StatusEffect.ASHED):
					ashed_count += 1
				elif member.is_dead:
					dead_count += 1

			if dead_count + ashed_count > 0:
				text += "[color=gray]Dead: %d | Ashed: %d[/color]" % [dead_count, ashed_count]
				if lost_count > 0:
					text += " [color=red]| Lost: %d[/color]" % lost_count
			else:
				text += "[color=green]No fallen party members.[/color]"

		ServiceType.CURE_STATUS:
			text += "[color=yellow]Cost:[/color] %d + %d per level\n\n" % [CURE_BASE_COST, CURE_PER_LEVEL]
			text += "[color=cyan]Curable conditions:[/color]\n"
			for status in CURABLE_STATUSES:
				text += "  - %s\n" % CharacterEnums.get_status_name(status)

		ServiceType.TITHE:
			text += "[color=yellow]Offerings available:[/color]\n"
			for amount in TITHE_AMOUNTS:
				var duration := BLESSING_DURATION + amount / 100
				var can_afford := GameState.party.has_gold(amount)
				var color := "white" if can_afford else "gray"
				text += "  [color=%s]%d gold - %d turns of blessing[/color]\n" % [color, amount, duration]
			text += "\n[color=cyan]Blessing grants:[/color]\n"
			text += "  +2 to hit\n"
			text += "  +2 evasion\n"
			text += "  Lasts for specified combat turns\n"

	info_label.text = text


func _update_member_info(idx: int) -> void:
	if idx < 0:
		info_label.text = "Select a member."
		return

	match selected_service:
		ServiceType.RESURRECT:
			_update_resurrect_info(idx)
		ServiceType.CURE_STATUS:
			_update_cure_info(idx)
		ServiceType.TITHE:
			_update_tithe_info(idx)


func _update_resurrect_info(idx: int) -> void:
	var dead_members: Array[Character] = []
	for member in GameState.party.get_members():
		if member.is_dead:
			dead_members.append(member)

	if idx >= dead_members.size():
		info_label.text = "Press Enter to cancel."
		return

	var member: Character = dead_members[idx]
	var cost := _calculate_resurrect_cost(member)

	var text := "[b]Resurrect %s[/b]\n\n" % member.character_name
	text += "Level %d %s %s\n\n" % [
		member.level,
		CharacterEnums.get_race_name(member.race),
		CharacterEnums.get_class_name(member.character_class)
	]

	text += "[color=yellow]Cost: %d gold[/color]\n" % cost
	text += "[color=yellow]Current Vitality: %d[/color]\n\n" % member.vitality

	if member.has_status(CharacterEnums.StatusEffect.LOST):
		text += "[color=red]This character is LOST FOREVER and cannot be resurrected.[/color]"
	elif member.has_status(CharacterEnums.StatusEffect.ASHED):
		text += "[color=orange]This character has been reduced to ashes.[/color]\n"
		text += "[color=orange]Success chance: 50%%[/color]\n"
		text += "[color=orange]Failure turns ashes to dust (LOST).[/color]\n\n"
		if member.vitality <= 1:
			text += "[color=red]WARNING: Low vitality - high risk of permanent loss![/color]"
	else:
		text += "[color=cyan]Standard resurrection.[/color]\n"
		text += "May lose 1 Vitality.\n"
		if member.vitality <= 2:
			text += "[color=orange]WARNING: Low vitality.[/color]\n"

	info_label.text = text


func _update_cure_info(idx: int) -> void:
	var cure_list: Array[Dictionary] = []
	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		for status in _get_curable_statuses(member):
			cure_list.append({"member": member, "status": status})

	if idx >= cure_list.size():
		info_label.text = "Press Enter to cancel."
		return

	var entry: Dictionary = cure_list[idx]
	var member: Character = entry["member"]
	var status: CharacterEnums.StatusEffect = entry["status"]
	var cost := _calculate_cure_cost(member)
	var status_name := CharacterEnums.get_status_name(status)

	var text := "[b]Cure %s[/b]\n\n" % member.character_name
	text += "Remove: [color=orange]%s[/color]\n\n" % status_name
	text += "[color=yellow]Cost: %d gold[/color]\n\n" % cost

	text += "[color=cyan]Status effect:[/color]\n"
	match status:
		CharacterEnums.StatusEffect.POISONED:
			text += "Takes damage each turn in combat."
		CharacterEnums.StatusEffect.PARALYZED:
			text += "Cannot act in combat."
		CharacterEnums.StatusEffect.SILENCED:
			text += "Cannot cast spells."
		CharacterEnums.StatusEffect.BLINDED:
			text += "-4 to hit in combat."
		CharacterEnums.StatusEffect.CURSED:
			text += "-2 to hit and evasion, takes damage while exploring."
		CharacterEnums.StatusEffect.CONFUSED:
			text += "May attack allies or act randomly."
		CharacterEnums.StatusEffect.STONED:
			text += "Turned to stone, cannot act."

	info_label.text = text


func _update_tithe_info(idx: int) -> void:
	if idx >= TITHE_AMOUNTS.size():
		info_label.text = "Press Enter to cancel."
		return

	var amount: int = TITHE_AMOUNTS[idx]
	var duration := BLESSING_DURATION + amount / 100

	var text := "[b]Offer %d Gold[/b]\n\n" % amount
	text += "The Temple accepts your offering and bestows\n"
	text += "divine blessing upon your party.\n\n"
	text += "[color=yellow]Duration: %d combat turns[/color]\n\n" % duration
	text += "[color=cyan]Blessing grants all party members:[/color]\n"
	text += "  +2 accuracy bonus\n"
	text += "  +2 evasion bonus\n\n"

	if GameState.party.has_gold(amount):
		text += "[color=green]You can afford this offering.[/color]"
	else:
		text += "[color=red]You cannot afford this offering.[/color]"

	info_label.text = text


func _update_party_display() -> void:
	for child in party_list.get_children():
		child.queue_free()

	if GameState.party.is_empty():
		var label := Label.new()
		label.text = "(No party members)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		party_list.add_child(label)
		return

	for member in GameState.party.get_members():
		var row := _create_party_row(member)
		party_list.add_child(row)


func _create_party_row(member: Character) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)

	var name_label := Label.new()
	name_label.text = member.character_name
	name_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(name_label)

	var status_label := Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if member.has_status(CharacterEnums.StatusEffect.LOST):
		status_label.text = "[LOST]"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.2, 0.2))
	elif member.has_status(CharacterEnums.StatusEffect.ASHED):
		status_label.text = "[ASHED]"
		status_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.1))
	elif member.is_dead:
		status_label.text = "[DEAD]"
		status_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	else:
		var statuses := _get_curable_statuses(member)
		if not statuses.is_empty():
			var status_names: Array[String] = []
			for s in statuses:
				status_names.append(CharacterEnums.get_status_name(s))
			status_label.text = ", ".join(status_names)
			status_label.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
		else:
			status_label.text = "Healthy"
			status_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))

	row.add_child(status_label)

	var vit_label := Label.new()
	vit_label.text = "VIT: %d" % member.vitality
	if member.vitality <= 2:
		vit_label.add_theme_color_override("font_color", Color(1, 0.5, 0.3))
	row.add_child(vit_label)

	return row


func _on_service_selected(service_type: ServiceType) -> void:
	selected_service = service_type
	current_mode = Mode.MEMBER_SELECT
	_refresh_display()


func _on_cancel_service() -> void:
	current_mode = Mode.SERVICE_SELECT
	selected_member = null
	selected_status = CharacterEnums.StatusEffect.NONE
	_refresh_display()


func _on_resurrect_member(member: Character) -> void:
	var cost := _calculate_resurrect_cost(member)
	if not GameState.party.spend_gold(cost):
		message_label.text = "Not enough gold!"
		return

	var is_ashed := member.has_status(CharacterEnums.StatusEffect.ASHED)

	if is_ashed:
		if randf() < 0.5:
			member.remove_status(CharacterEnums.StatusEffect.ASHED)
			member.add_status(CharacterEnums.StatusEffect.LOST)
			message_label.text = "%s's ashes crumble to dust... They are lost forever." % member.character_name
			_refresh_display()
			return

	var old_vit := member.vitality
	var success := member.resurrect(1)

	if success:
		var vit_lost := old_vit - member.vitality
		if vit_lost > 0:
			message_label.text = "%s has been resurrected! (Lost %d Vitality)" % [member.character_name, vit_lost]
		else:
			message_label.text = "%s has been resurrected!" % member.character_name
	else:
		message_label.text = "The resurrection failed. %s is lost forever." % member.character_name

	_refresh_display()


func _on_cure_member(member: Character, status: CharacterEnums.StatusEffect) -> void:
	var cost := _calculate_cure_cost(member)
	if not GameState.party.spend_gold(cost):
		message_label.text = "Not enough gold!"
		return

	member.remove_status(status)
	var status_name := CharacterEnums.get_status_name(status)
	message_label.text = "%s's %s has been cured!" % [member.character_name, status_name]

	if _get_curable_statuses(member).is_empty() and not _is_service_available(ServiceType.CURE_STATUS):
		_on_cancel_service()
	else:
		_refresh_display()


func _on_tithe(amount: int) -> void:
	if not GameState.party.spend_gold(amount):
		message_label.text = "Not enough gold!"
		return

	var duration := BLESSING_DURATION + amount / 100

	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		member.add_status(CharacterEnums.StatusEffect.BLESSED, duration, "temple")

	message_label.text = "The Temple blesses your party for %d turns!" % duration
	_on_cancel_service()


func _update_help() -> void:
	var v_nav := KeyBindingHelper.get_nav_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()

	if current_mode == Mode.SERVICE_SELECT:
		help_label.text = "%s | %s: Select | %s" % [v_nav, confirm.split(":")[0], cancel]
	else:
		help_label.text = "%s | %s: Confirm | %s: Back" % [v_nav, confirm.split(":")[0], cancel.split(":")[0]]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		if current_mode == Mode.MEMBER_SELECT:
			_on_cancel_service()
		else:
			_on_back_pressed()
		return

	if nav:
		nav.handle_input(event)


func _on_back_pressed() -> void:
	SceneManager.go_to_town()

extends Control

enum Mode { SERVICE_SELECT, MEMBER_SELECT }
enum ServiceType { RESURRECT, CURE_STATUS, TITHE }

const SERVICES: Array[Dictionary] = [
	{
		"type": ServiceType.RESURRECT, "name": "Resurrection", "badge": "R",
		"color": Color(0.42, 0.72, 0.48),
		"description": "Restore a fallen party member to life. The process is taxing and may cost the recipient some Vitality."
	},
	{
		"type": ServiceType.CURE_STATUS, "name": "Cure Ailments", "badge": "C",
		"color": Color(0.40, 0.70, 0.90),
		"description": "Remove debilitating conditions such as poison, paralysis, blindness, or curses through divine intervention."
	},
	{
		"type": ServiceType.TITHE, "name": "Tithe for Blessing", "badge": "T",
		"color": Color(0.87, 0.74, 0.47),
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

var nav: MenuNavigator = null
var buttons: Array[Button] = []

var _scaffold: ScreenScaffold
var _section_label: Label
var _options_list: VBoxContainer
var _message_label: Label
var _info_label: RichTextLabel
var _party_list: VBoxContainer


func _ready() -> void:
	_build_ui()
	_refresh_display()


# --- Construction -----------------------------------------------------------

func _build_ui() -> void:
	_scaffold = ScreenScaffold.create({"title": "TEMPLE", "hint": ""})
	add_child(_scaffold)
	_scaffold.back_pressed.connect(_on_back_pressed)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	_scaffold.body.add_child(hbox)

	# Left: service / option list.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
	left.add_theme_constant_override("separation", 10)
	hbox.add_child(left)

	_section_label = Label.new()
	_section_label.theme_type_variation = &"SubheaderLabel"
	_section_label.text = "SERVICES"
	left.add_child(_section_label)

	var options_panel := PanelContainer.new()
	options_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(options_panel)

	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	options_panel.add_child(scroll)

	_options_list = VBoxContainer.new()
	_options_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_options_list)

	_message_label = Label.new()
	_message_label.theme_type_variation = &"MutedLabel"
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_message_label)

	# Right: details + party.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	hbox.add_child(right)

	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(0, 230)
	right.add_child(info_panel)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 14)
	info_margin.add_theme_constant_override("margin_right", 14)
	info_margin.add_theme_constant_override("margin_top", 12)
	info_margin.add_theme_constant_override("margin_bottom", 12)
	info_panel.add_child(info_margin)

	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.fit_content = true
	_info_label.scroll_active = false
	info_margin.add_child(_info_label)

	var party_header := Label.new()
	party_header.theme_type_variation = &"SubheaderLabel"
	party_header.text = "PARTY"
	right.add_child(party_header)

	var party_panel := PanelContainer.new()
	party_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(party_panel)

	var party_scroll := ScrollContainer.new()
	party_scroll.follow_focus = true
	party_panel.add_child(party_scroll)

	_party_list = VBoxContainer.new()
	_party_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_list.add_theme_constant_override("separation", 8)
	party_scroll.add_child(_party_list)


# --- Display ----------------------------------------------------------------

func _refresh_display() -> void:
	_update_party_display()

	if current_mode == Mode.SERVICE_SELECT:
		_section_label.text = "SERVICES"
		_populate_services()
		_message_label.text = "How may the Temple serve you?"
	else:
		_populate_members_for_service()

	_update_info()
	_update_help()


func _make_row(cfg: Dictionary) -> MenuListRow:
	var row := MenuListRow.create(cfg)
	_options_list.add_child(row)
	buttons.append(row)
	return row


func _populate_services() -> void:
	_clear_options()
	if GameState.party.is_empty():
		_empty_note("(No party members)")
		return

	for service in SERVICES:
		var service_type: ServiceType = service["type"]
		var available := _is_service_available(service_type)
		var row := _make_row({
			"badge": service["badge"], "badge_color": service["color"],
			"title": service["name"], "subtitle": service["description"],
			"dim": not available,
		})
		row.disabled = not available
		row.pressed.connect(_on_service_selected.bind(service_type))

	_setup_nav()


func _populate_members_for_service() -> void:
	_clear_options()

	match selected_service:
		ServiceType.RESURRECT:
			_section_label.text = "RESURRECT"
			_populate_dead_members()
			_message_label.text = "Select a fallen member to resurrect."
		ServiceType.CURE_STATUS:
			_section_label.text = "CURE AILMENTS"
			_populate_afflicted_members()
			_message_label.text = "Select a member to cure."
		ServiceType.TITHE:
			_section_label.text = "TITHE FOR BLESSING"
			_populate_tithe_options()
			_message_label.text = "Choose your offering."

	var cancel := _make_row({"badge": "‹", "badge_color": UIColors.TEXT_MUTED, "title": "Cancel"})
	cancel.pressed.connect(_on_cancel_service)
	_setup_nav()


func _populate_dead_members() -> void:
	for member in GameState.party.get_members():
		if not member.is_dead:
			continue
		var cost := _calculate_resurrect_cost(member)
		var chips: Array = []
		var affordable := GameState.party.has_gold(cost)
		var lost := member.has_status(CharacterEnums.StatusEffect.LOST)
		if lost:
			chips.append({"text": "LOST", "fg": Color.WHITE, "bg": UIColors.TEXT_LOST})
		elif member.has_status(CharacterEnums.StatusEffect.ASHED):
			chips.append({"text": "ASHED", "fg": Color.WHITE, "bg": UIColors.WARNING.darkened(0.25)})
		var row := _make_row({
			"badge": _crest_letter(member), "badge_color": UIColors.class_color(member.character_class),
			"title": member.character_name,
			"subtitle": "L%d  ·  %d gold" % [member.level, cost],
			"chips": chips, "dim": lost or not affordable,
		})
		row.disabled = lost or not affordable
		row.pressed.connect(_on_resurrect_member.bind(member))


func _populate_afflicted_members() -> void:
	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		for status in _get_curable_statuses(member):
			var cost := _calculate_cure_cost(member)
			var affordable := GameState.party.has_gold(cost)
			var row := _make_row({
				"badge": _crest_letter(member), "badge_color": UIColors.class_color(member.character_class),
				"title": member.character_name,
				"subtitle": "Cure %s  ·  %d gold" % [CharacterEnums.get_status_name(status), cost],
				"chips": [{"text": CharacterEnums.get_status_name(status).to_upper(),
					"fg": UIColors.TEXT_WARNING, "bg": UIColors.SURFACE_SELECTED}],
				"dim": not affordable,
			})
			row.disabled = not affordable
			row.pressed.connect(_on_cure_member.bind(member, status))


func _populate_tithe_options() -> void:
	for amount in TITHE_AMOUNTS:
		var duration := BLESSING_DURATION + amount / 100
		var affordable := GameState.party.has_gold(amount)
		var row := _make_row({
			"badge": "◆", "badge_color": UIColors.GOLD,
			"title": "Offer %d gold" % amount,
			"subtitle": "Blessing for %d turns" % duration,
			"dim": not affordable,
		})
		row.disabled = not affordable
		row.pressed.connect(_on_tithe.bind(amount))


func _crest_letter(member: Character) -> String:
	return CharacterEnums.get_class_name(member.character_class).substr(0, 1).to_upper()


func _clear_options() -> void:
	for child in _options_list.get_children():
		child.queue_free()
	buttons.clear()
	nav = null


func _empty_note(text: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"MutedLabel"
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_options_list.add_child(label)


func _setup_nav() -> void:
	if buttons.is_empty():
		return
	nav = MenuNavigator.new()
	nav.setup(buttons, 0)
	nav.selection_changed.connect(_on_selection_changed)


func _update_party_display() -> void:
	for child in _party_list.get_children():
		child.queue_free()

	if GameState.party.is_empty():
		_party_list.add_child(_party_empty())
		return

	var members := GameState.party.get_members()
	for i in members.size():
		_party_list.add_child(PartyMemberCard.create(members[i], {"index": i}))


func _party_empty() -> Label:
	var label := Label.new()
	label.theme_type_variation = &"MutedLabel"
	label.text = "(No party members)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


# --- Service availability / costs (unchanged) -------------------------------

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


# --- Info panel (unchanged content) -----------------------------------------

func _on_selection_changed(_index: int) -> void:
	_update_info()


func _update_info() -> void:
	if nav == null or buttons.is_empty():
		_info_label.text = "Select a service."
		return
	var idx := nav.get_current_index()
	if current_mode == Mode.SERVICE_SELECT:
		_update_service_info(idx)
	else:
		_update_member_info(idx)


func _update_service_info(idx: int) -> void:
	if idx < 0 or idx >= SERVICES.size():
		_info_label.text = "Select a service."
		return

	var service: Dictionary = SERVICES[idx]
	var service_type: ServiceType = service["type"]

	var text := "[b]%s[/b]\n\n%s\n\n" % [service["name"], service["description"]]

	match service_type:
		ServiceType.RESURRECT:
			text += "[color=yellow]Cost:[/color] %d + %d per level\n" % [RESURRECT_BASE_COST, RESURRECT_PER_LEVEL]
			text += "[color=yellow]Ashed:[/color] Double cost, 50% success\n\n"
			text += "[color=#8da0c8]Resurrection may cost 1 Vitality. At 0 Vitality the character is lost forever.[/color]\n\n"
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
			text += "[color=#8da0c8]Curable:[/color] "
			var names: Array[String] = []
			for status in CURABLE_STATUSES:
				names.append(CharacterEnums.get_status_name(status))
			text += ", ".join(names)
		ServiceType.TITHE:
			text += "[color=yellow]Offerings:[/color]\n"
			for amount in TITHE_AMOUNTS:
				var duration := BLESSING_DURATION + amount / 100
				var color := "white" if GameState.party.has_gold(amount) else "gray"
				text += "  [color=%s]%d gold → %d turns[/color]\n" % [color, amount, duration]
			text += "\n[color=#8da0c8]Blessing grants +2 to hit and +2 evasion to all members.[/color]"

	_info_label.text = text


func _update_member_info(idx: int) -> void:
	if idx < 0:
		_info_label.text = "Select a member."
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
		_info_label.text = "Press Enter to cancel."
		return

	var member: Character = dead_members[idx]
	var cost := _calculate_resurrect_cost(member)
	var text := "[b]Resurrect %s[/b]\n\n" % member.character_name
	text += "Level %d %s %s\n\n" % [member.level,
		CharacterEnums.get_race_name(member.race),
		CharacterEnums.get_class_name(member.character_class)]
	text += "[color=yellow]Cost: %d gold[/color]\n" % cost
	text += "[color=yellow]Current Vitality: %d[/color]\n\n" % member.vitality

	if member.has_status(CharacterEnums.StatusEffect.LOST):
		text += "[color=red]This character is LOST FOREVER and cannot be resurrected.[/color]"
	elif member.has_status(CharacterEnums.StatusEffect.ASHED):
		text += "[color=orange]Reduced to ashes — 50% success. Failure turns ashes to dust (LOST).[/color]\n\n"
		if member.vitality <= 1:
			text += "[color=red]WARNING: Low vitality — high risk of permanent loss![/color]"
	else:
		text += "[color=#8da0c8]Standard resurrection. May lose 1 Vitality.[/color]\n"
		if member.vitality <= 2:
			text += "[color=orange]WARNING: Low vitality.[/color]"

	_info_label.text = text


func _update_cure_info(idx: int) -> void:
	var cure_list: Array[Dictionary] = []
	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		for status in _get_curable_statuses(member):
			cure_list.append({"member": member, "status": status})
	if idx >= cure_list.size():
		_info_label.text = "Press Enter to cancel."
		return

	var entry: Dictionary = cure_list[idx]
	var member: Character = entry["member"]
	var status: CharacterEnums.StatusEffect = entry["status"]
	var cost := _calculate_cure_cost(member)

	var text := "[b]Cure %s[/b]\n\n" % member.character_name
	text += "Remove: [color=orange]%s[/color]\n\n" % CharacterEnums.get_status_name(status)
	text += "[color=yellow]Cost: %d gold[/color]\n\n" % cost
	match status:
		CharacterEnums.StatusEffect.POISONED: text += "Takes damage each turn in combat."
		CharacterEnums.StatusEffect.PARALYZED: text += "Cannot act in combat."
		CharacterEnums.StatusEffect.SILENCED: text += "Cannot cast spells."
		CharacterEnums.StatusEffect.BLINDED: text += "-4 to hit in combat."
		CharacterEnums.StatusEffect.CURSED: text += "-2 to hit and evasion, takes damage while exploring."
		CharacterEnums.StatusEffect.CONFUSED: text += "May attack allies or act randomly."
		CharacterEnums.StatusEffect.STONED: text += "Turned to stone, cannot act."
	_info_label.text = text


func _update_tithe_info(idx: int) -> void:
	if idx >= TITHE_AMOUNTS.size():
		_info_label.text = "Press Enter to cancel."
		return
	var amount: int = TITHE_AMOUNTS[idx]
	var duration := BLESSING_DURATION + amount / 100
	var text := "[b]Offer %d Gold[/b]\n\n" % amount
	text += "The Temple bestows divine blessing upon your party.\n\n"
	text += "[color=yellow]Duration: %d combat turns[/color]\n\n" % duration
	text += "[color=#8da0c8]Grants all members +2 accuracy and +2 evasion.[/color]\n\n"
	if GameState.party.has_gold(amount):
		text += "[color=green]You can afford this offering.[/color]"
	else:
		text += "[color=red]You cannot afford this offering.[/color]"
	_info_label.text = text


# --- Actions (unchanged behaviour) ------------------------------------------

func _on_service_selected(service_type: ServiceType) -> void:
	selected_service = service_type
	current_mode = Mode.MEMBER_SELECT
	_refresh_display()


func _on_cancel_service() -> void:
	current_mode = Mode.SERVICE_SELECT
	_refresh_display()


func _on_resurrect_member(member: Character) -> void:
	var cost := _calculate_resurrect_cost(member)
	if not GameState.party.spend_gold(cost):
		_message_label.text = "Not enough gold!"
		return

	if member.has_status(CharacterEnums.StatusEffect.ASHED):
		if randf() < 0.5:
			member.remove_status(CharacterEnums.StatusEffect.ASHED)
			member.add_status(CharacterEnums.StatusEffect.LOST)
			_message_label.text = "%s's ashes crumble to dust... lost forever." % member.character_name
			_refresh_display()
			return

	var old_vit := member.vitality
	var success := member.resurrect(1)
	if success:
		var vit_lost := old_vit - member.vitality
		if vit_lost > 0:
			_message_label.text = "%s has been resurrected! (Lost %d Vitality)" % [member.character_name, vit_lost]
		else:
			_message_label.text = "%s has been resurrected!" % member.character_name
	else:
		_message_label.text = "The resurrection failed. %s is lost forever." % member.character_name

	if not _is_service_available(ServiceType.RESURRECT):
		_on_cancel_service()
	else:
		_refresh_display()


func _on_cure_member(member: Character, status: CharacterEnums.StatusEffect) -> void:
	var cost := _calculate_cure_cost(member)
	if not GameState.party.spend_gold(cost):
		_message_label.text = "Not enough gold!"
		return
	member.remove_status(status)
	_message_label.text = "%s's %s has been cured!" % [member.character_name, CharacterEnums.get_status_name(status)]
	if not _is_service_available(ServiceType.CURE_STATUS):
		_on_cancel_service()
	else:
		_refresh_display()


func _on_tithe(amount: int) -> void:
	if not GameState.party.spend_gold(amount):
		_message_label.text = "Not enough gold!"
		return
	var duration := BLESSING_DURATION + amount / 100
	for member in GameState.party.get_members():
		if member.is_dead:
			continue
		member.add_status(CharacterEnums.StatusEffect.BLESSED, duration, "temple")
	_message_label.text = "The Temple blesses your party for %d turns!" % duration
	_on_cancel_service()


func _update_help() -> void:
	var v_nav := KeyBindingHelper.get_nav_help()
	var confirm := KeyBindingHelper.get_confirm_help()
	var cancel := KeyBindingHelper.get_cancel_help()
	if current_mode == Mode.SERVICE_SELECT:
		_scaffold.set_hint("%s   ·   %s Select   ·   %s" % [v_nav, confirm.split(":")[0], cancel])
	else:
		_scaffold.set_hint("%s   ·   %s Confirm   ·   %s Back" % [v_nav, confirm.split(":")[0], cancel.split(":")[0]])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel"):
		if current_mode == Mode.MEMBER_SELECT:
			_on_cancel_service()
		else:
			_on_back_pressed()
		get_viewport().set_input_as_handled()
		return
	if nav:
		nav.handle_input(event)


func _on_back_pressed() -> void:
	SceneManager.go_to_town()

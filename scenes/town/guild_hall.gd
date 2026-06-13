extends Control

enum Tab { CREATE, ROSTER, PARTY }

var current_tab: Tab = Tab.CREATE

var nav: MenuNavigator = null
var buttons: Array[Button] = []

var roster_tab: GuildHallRosterTab = null
var party_tab: GuildHallPartyTab = null

@onready var title_label: Label = $MainHBox/LeftPanel/Header/TitleLabel
@onready var count_label: Label = $MainHBox/LeftPanel/Header/CountLabel
var _date_labels: Dictionary = {}
var roster_value_label: Label = null
@onready var tab_bar: TabBar = $MainHBox/LeftPanel/TabBar
@onready var options_panel: PanelContainer = $MainHBox/LeftPanel/OptionsPanel
@onready var options_list: VBoxContainer = $MainHBox/LeftPanel/OptionsPanel/ScrollContainer/OptionsList
@onready var message_label: Label = $MainHBox/LeftPanel/MessageLabel
@onready var help_label: Label = $MainHBox/LeftPanel/HelpLabel
@onready var back_button: Button = $MainHBox/LeftPanel/BackButton
@onready var info_panel: PanelContainer = $MainHBox/RightPanel/InfoPanel
@onready var info_label: RichTextLabel = $MainHBox/RightPanel/InfoPanel/InfoLabel
@onready var roster_label: Label = $MainHBox/RightPanel/RosterLabel
@onready var roster_panel: PanelContainer = $MainHBox/RightPanel/RosterPanel
@onready var roster_list: VBoxContainer = $MainHBox/RightPanel/RosterPanel/ScrollContainer/RosterList


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	tab_bar.tab_changed.connect(_on_tab_changed)
	_build_header_grid()

	roster_tab = GuildHallRosterTab.new()
	roster_tab.init(options_list, info_label)
	roster_tab.message_changed.connect(_on_delegate_message)
	roster_tab.display_refresh_requested.connect(_refresh_display)

	party_tab = GuildHallPartyTab.new()
	party_tab.init(options_list, info_label)
	party_tab.message_changed.connect(_on_delegate_message)
	party_tab.display_refresh_requested.connect(_refresh_display)

	if GameState.has_party():
		current_tab = Tab.PARTY
	elif not GameState.roster.is_empty():
		current_tab = Tab.PARTY
	else:
		current_tab = Tab.CREATE
	tab_bar.current_tab = current_tab
	_refresh_display()


func _build_header_grid() -> void:
	count_label.hide()
	var header: HBoxContainer = title_label.get_parent()
	_date_labels = GameCalendar.create_date_grid(GameState.game_day)
	var grid: GridContainer = _date_labels["grid"]
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_SHRINK_END
	var roster_header := Label.new()
	roster_header.text = "Roster"
	roster_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roster_header.add_theme_font_size_override("font_size", UIColors.FONT_SIZE_SMALL)
	roster_header.add_theme_color_override("font_color", UIColors.TEXT_SECONDARY)
	grid.add_child(roster_header)
	grid.move_child(roster_header, 3)
	roster_value_label = Label.new()
	roster_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(roster_value_label)
	header.add_child(grid)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.shift_pressed and event.keycode == KEY_D:
		GameState.advance_game_days(30)
		message_label.text = "DEBUG: Advanced 30 days. Now %s." % GameCalendar.format_short(GameState.game_day)
		_refresh_display()


func _on_tab_changed(tab_index: int) -> void:
	current_tab = tab_index as Tab
	roster_tab.reset()
	party_tab.reset()
	_refresh_display()


func _on_delegate_message(text: String) -> void:
	message_label.text = text


func _refresh_display() -> void:
	if not _date_labels.is_empty():
		GameCalendar.update_date_labels(_date_labels, GameState.game_day)
		roster_value_label.text = "%d/%d" % [GameState.roster.size(), GameState.roster.MAX_SIZE]
	_update_roster_overview()

	match current_tab:
		Tab.CREATE:
			_populate_create_tab()
		Tab.ROSTER:
			roster_tab.populate()
		Tab.PARTY:
			party_tab.populate()

	_update_help()


func _populate_create_tab() -> void:
	_clear_options()

	var create_btn := Button.new()
	create_btn.text = "Create New Character"
	create_btn.custom_minimum_size = Vector2(350, 40)

	if GameState.roster.is_full():
		create_btn.disabled = true
		create_btn.modulate = UIColors.MODULATE_DISABLED
	else:
		create_btn.pressed.connect(_on_create_character)

	options_list.add_child(create_btn)
	buttons.append(create_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	options_list.add_child(spacer)

	var capacity_label := Label.new()
	capacity_label.text = "Roster: %d / %d characters" % [GameState.roster.size(), GameState.roster.MAX_SIZE]
	capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options_list.add_child(capacity_label)

	if GameState.roster.is_full():
		message_label.text = "Roster is full. Delete a character to make room."
	else:
		message_label.text = "Create a new adventurer to join the guild."

	_setup_nav()

	var text := "[b]Create Character[/b]\n\n"
	text += "Create a new adventurer by choosing their race,\n"
	text += "background, stats, class, alignment, and name.\n\n"
	text += "[color=cyan]Roster capacity:[/color] %d/%d\n" % [
		GameState.roster.size(), GameState.roster.MAX_SIZE
	]
	if GameState.roster.is_full():
		text += "\n[color=red]Roster is full! Delete a character to make room.[/color]"
	info_label.text = text


func _on_create_character() -> void:
	SceneManager.go_to_character_creation()


func _update_roster_overview() -> void:
	for child in roster_list.get_children():
		child.queue_free()

	var characters: Array[Character] = GameState.roster.get_all()
	if characters.is_empty():
		var label := Label.new()
		label.text = "(No characters in roster)"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		roster_list.add_child(label)
		return

	for c in characters:
		var row := _create_roster_row(c)
		roster_list.add_child(row)


func _create_roster_row(c: Character) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)
	row.add_theme_constant_override("separation", 8)

	# Class crest, matching the dossier/list crests.
	var tint := UIColors.class_color(c.character_class)
	var badge := Label.new()
	badge.text = CharacterEnums.get_class_name(c.character_class).substr(0, 1).to_upper()
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
	name_label.text = c.character_name
	name_label.custom_minimum_size = Vector2(96, 0)
	row.add_child(name_label)

	var class_label := Label.new()
	class_label.text = "L%d %s" % [c.level, CharacterEnums.get_class_name(c.character_class)]
	class_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_label.theme_type_variation = &"MutedLabel"
	row.add_child(class_label)

	var status_label := Label.new()
	if c.has_status(CharacterEnums.StatusEffect.LOST):
		status_label.text = "[LOST]"
		status_label.add_theme_color_override("font_color", UIColors.TEXT_LOST)
	elif c.is_dead:
		status_label.text = "[DEAD]"
		status_label.add_theme_color_override("font_color", UIColors.DANGER)
	elif c.is_training():
		var t_elapsed := c.get_training_days_elapsed(GameState.game_day)
		status_label.text = "[Training %d/%d]" % [t_elapsed, c.get_training_total()]
		status_label.add_theme_color_override("font_color", UIColors.TEXT_WARNING)
	elif GameState.party.has_member(c):
		status_label.text = "[PARTY]"
		status_label.add_theme_color_override("font_color", UIColors.TEXT_IN_PARTY)
	else:
		status_label.text = ""
	row.add_child(status_label)

	return row


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


func _update_help() -> void:
	match current_tab:
		Tab.CREATE:
			var h_nav := KeyBindingHelper.get_horizontal_help()
			var confirm := KeyBindingHelper.get_confirm_help()
			var cancel := KeyBindingHelper.get_cancel_help()
			help_label.text = "%s | %s | %s" % [h_nav, confirm, cancel]
		Tab.ROSTER:
			help_label.text = roster_tab.get_help_text()
		Tab.PARTY:
			help_label.text = party_tab.get_help_text()


func _unhandled_input(event: InputEvent) -> void:
	if current_tab == Tab.ROSTER:
		if roster_tab.roster_mode == GuildHallRosterTab.RosterMode.RENAME:
			roster_tab.handle_input(event)
			return

	if current_tab == Tab.PARTY:
		if party_tab.party_mode == GuildHallPartyTab.PartyMode.FORMATION_SAVE:
			party_tab.handle_input(event)
			return
		if party_tab.party_mode in [GuildHallPartyTab.PartyMode.REORDER_SELECT, GuildHallPartyTab.PartyMode.REORDER_MOVE]:
			party_tab.handle_input(event)
			return
		if party_tab.party_mode in [GuildHallPartyTab.PartyMode.FORMATION_LIST, GuildHallPartyTab.PartyMode.FORMATION_MANAGE]:
			if event.is_action_pressed("menu_cancel"):
				party_tab.handle_input(event)
				return
			party_tab.handle_input(event)
			return

	if event.is_action_pressed("menu_sort"):
		if current_tab == Tab.ROSTER:
			roster_tab.handle_input(event)
			return
		if current_tab == Tab.PARTY and party_tab.party_mode == GuildHallPartyTab.PartyMode.NORMAL:
			party_tab.handle_input(event)
			return

	if event.is_action_pressed("menu_left"):
		tab_bar.current_tab = (tab_bar.current_tab - 1 + 3) % 3
		return
	if event.is_action_pressed("menu_right"):
		tab_bar.current_tab = (tab_bar.current_tab + 1) % 3
		return

	if event.is_action_pressed("menu_cancel"):
		match current_tab:
			Tab.ROSTER:
				if not roster_tab.handle_back():
					_on_back_pressed()
			Tab.PARTY:
				_on_back_pressed()
			_:
				_on_back_pressed()
		return

	match current_tab:
		Tab.PARTY:
			party_tab.handle_input(event)
		Tab.ROSTER:
			roster_tab.handle_input(event)
		Tab.CREATE:
			if nav:
				nav.handle_input(event)


func _on_back_pressed() -> void:
	SceneManager.go_to_town()

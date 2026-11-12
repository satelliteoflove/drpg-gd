extends Control

enum Tab { CREATE, ROSTER, PARTY, STORAGE, CHRONICLE }

var current_tab: Tab = Tab.CREATE

var nav: MenuNavigator = null
var buttons: Array[Button] = []

var roster_tab: GuildHallRosterTab = null
var party_tab: GuildHallPartyTab = null

var _scaffold: ScreenScaffold = null
var _detail: CharacterDetailView = null
var _count_strip: Label = null

@onready var left_panel: VBoxContainer = $MainHBox/LeftPanel
@onready var tab_bar: TabBar = $MainHBox/LeftPanel/TabBar
@onready var options_panel: PanelContainer = $MainHBox/LeftPanel/OptionsPanel
@onready var options_list: VBoxContainer = $MainHBox/LeftPanel/OptionsPanel/ScrollContainer/OptionsList
@onready var message_label: Label = $MainHBox/LeftPanel/MessageLabel
@onready var help_label: Label = $MainHBox/LeftPanel/HelpLabel
@onready var back_button: Button = $MainHBox/LeftPanel/BackButton
@onready var right_panel: Control = $MainHBox/RightPanel


func _ready() -> void:
	_install_scaffold()
	_detail = CharacterDetailView.new(right_panel)
	_build_count_strip()
	tab_bar.add_tab("Storage")
	tab_bar.add_tab("Chronicle")
	# Five tabs don't fit the panel at the default spacing, and a scrolling
	# tab bar hides the first one.
	tab_bar.clip_tabs = false
	tab_bar.add_theme_constant_override("h_separation", 2)
	tab_bar.add_theme_font_size_override("font_size", 14)
	tab_bar.tab_changed.connect(_on_tab_changed)

	roster_tab = GuildHallRosterTab.new()
	roster_tab.init(options_list, _detail)
	roster_tab.message_changed.connect(_on_delegate_message)
	roster_tab.display_refresh_requested.connect(_refresh_display)

	party_tab = GuildHallPartyTab.new()
	party_tab.init(options_list, _detail)
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


## Wrap the guild hall in the shared scaffold for the same top-bar pill (title +
## live date/gold), corner frame and Back affordance as every other screen.
func _install_scaffold() -> void:
	var bg := get_node_or_null("Background")
	if bg != null:
		bg.queue_free()

	$MainHBox/LeftPanel/Header.visible = false
	help_label.visible = false
	back_button.visible = false

	var main: Control = $MainHBox
	remove_child(main)
	_scaffold = ScreenScaffold.create({"title": "GUILD HALL", "hint": ""})
	add_child(_scaffold)
	move_child(_scaffold, 0)
	_scaffold.body.add_child(main)
	_scaffold.back_pressed.connect(_on_back_pressed)


## A persistent, always-visible roster tally pinned beneath the tabs, so "how
## many adventurers do I have?" is answerable from any tab without hunting.
func _build_count_strip() -> void:
	_count_strip = Label.new()
	_count_strip.theme_type_variation = &"MutedLabel"
	_count_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(_count_strip)
	left_panel.move_child(_count_strip, tab_bar.get_index() + 1)


func _unhandled_key_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.shift_pressed and event.keycode == KEY_D:
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
	if _count_strip != null:
		_count_strip.text = "Roster   %d / %d" % [GameState.roster.size(), GameState.roster.MAX_SIZE]

	match current_tab:
		Tab.CREATE:
			_populate_create_tab()
		Tab.ROSTER:
			roster_tab.populate()
		Tab.PARTY:
			party_tab.populate()
		Tab.STORAGE:
			_populate_storage_tab()
		Tab.CHRONICLE:
			_populate_chronicle_tab()

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

	# The right pane has no character to portrait on this tab, so fill it with a
	# living snapshot of the guild itself rather than leaving it blank.
	_detail.show_text(_guild_summary_text())


func _guild_summary_text() -> String:
	var roster := GameState.roster
	var living := 0
	var dead := 0
	for c in roster.get_all():
		if c.is_dead:
			dead += 1
		elif c.is_available():
			living += 1

	var text := "[b]The Adventurers' Guild[/b]\n\n"
	text += "Roster      %d / %d\n" % [roster.size(), roster.MAX_SIZE]
	text += "Ready       %d\n" % living
	if dead > 0:
		text += "[color=red]Fallen      %d[/color]\n" % dead
	text += "In Party    %d / 6\n\n" % GameState.party.size()

	if roster.is_full():
		text += "[color=red]The roster is full — delete a character to make room.[/color]"
	elif roster.is_empty():
		text += "Your guild has no members yet.\nRecruit your first adventurer to begin."
	else:
		text += "Recruit a new adventurer to join the guild."
	return text


# --- Storage -------------------------------------------------------------------------

## Each row on the storage tab: {from: Inventory, to: Inventory, index: int}.
var _storage_rows: Array[Dictionary] = []
var _storage_focus: int = 0


## The guild's storage: anything left here can be taken by whichever party is
## in town, so characters never have to share a party to pass gear along.
func _populate_storage_tab() -> void:
	_clear_options()
	_storage_rows.clear()
	var pack := GameState.party.inventory
	var storage := GameState.guild_storage

	_add_section_label("PARTY'S PACK  (%d / %d)" % [pack.size(), pack.max_slots])
	_add_storage_rows(pack, storage, "Store")
	_add_section_label("GUILD STORAGE  (%d / %d)" % [storage.size(), storage.max_slots])
	_add_storage_rows(storage, pack, "Take")

	message_label.text = "Store what the party won't need, or take what it will." if not buttons.is_empty() \
		else "Nothing in the party's pack or in storage."
	_setup_nav()
	if nav:
		nav.selection_changed.connect(_on_storage_selection)
		nav.select(clampi(_storage_focus, 0, buttons.size() - 1))
	_on_storage_selection(nav.get_current_index() if nav else -1)


func _add_section_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"MutedLabel"
	options_list.add_child(label)


func _add_storage_rows(from: Inventory, to: Inventory, verb: String) -> void:
	if from.slots.is_empty():
		var empty := Label.new()
		empty.text = "  (empty)"
		empty.theme_type_variation = &"MutedLabel"
		options_list.add_child(empty)
		return
	for i in from.slots.size():
		var item: Item = from.slots[i].get("item")
		if item == null:
			continue
		var quantity: int = from.slots[i].get("quantity", 1)
		var button := Button.new()
		button.text = "%s   %s%s" % [verb, item.get_display_name(), "  ×%d" % quantity if quantity > 1 else ""]
		button.custom_minimum_size = Vector2(350, 34)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_storage_row.bind(_storage_rows.size()))
		options_list.add_child(button)
		buttons.append(button)
		_storage_rows.append({"from": from, "to": to, "index": i})


func _on_storage_row(row_index: int) -> void:
	var row: Dictionary = _storage_rows[row_index]
	var from: Inventory = row["from"]
	var to: Inventory = row["to"]
	var slot: Dictionary = from.slots[row["index"]]
	var item: Item = slot.get("item")
	var quantity: int = slot.get("quantity", 1)
	var remaining := to.add_item(item, quantity)
	if remaining >= quantity:
		message_label.text = "There's no room for %s." % item.get_display_name()
		return
	if remaining <= 0:
		from.slots.remove_at(row["index"])
	else:
		slot["quantity"] = remaining
	_storage_focus = row_index
	_refresh_display()


func _on_storage_selection(index: int) -> void:
	if index < 0 or index >= _storage_rows.size():
		_detail.show_text("[b]Guild Storage[/b]\n\nAnything stored here stays in town, and any party in town can take it.")
		return
	var row: Dictionary = _storage_rows[index]
	var item: Item = row["from"].slots[row["index"]].get("item")
	_detail.show_text("[b]%s[/b]\n\n%s" % [item.get_display_name(), item.get_stats_text()])


# --- Chronicle -----------------------------------------------------------------------

const CHRONICLE_SHOWN := 40
const CHRONICLE_COLORS := {
	"collapse": "#dfbd78", "story": "#dfbd78", "legend": "#e6c040",
	"retired": "#a8c8e8", "rescue": "#8fd49a", "wipe": "#ff6b6b", "death": "#c9a0a0",
}


## The guild's record: dungeons brought down, Legends, retirements and losses.
func _populate_chronicle_tab() -> void:
	_clear_options()
	var dungeon_set := GameState.dungeon_set
	_add_section_label("DUNGEONS")
	for d in dungeon_set.dungeons:
		_add_chronicle_line("%s  ·  %s" % [d.dungeon_name,
			"collapsed %s" % GameCalendar.format_short(d.collapsed_day) if d.is_collapsed() else "stands"])
	if dungeon_set.final_dungeon:
		_add_chronicle_line("%s  ·  stands" % dungeon_set.final_dungeon.dungeon_name)
	if dungeon_set.set_number > 1:
		_add_chronicle_line("Set %d. The story ended %s." % [
			dungeon_set.set_number, GameCalendar.format_short(GameState.victory_day)])

	var legends: Array[String] = []
	var posts: Array[String] = []
	for c in GameState.roster.get_all():
		if c.is_legend():
			legends.append(c.character_name)
		elif c.is_retired() and not c.town_post.is_empty():
			posts.append("%s, %s" % [c.character_name, Retirement.post_title(c.town_post)])
	if not legends.is_empty():
		_add_section_label("LEGENDS")
		for line in legends:
			_add_chronicle_line(line)
	if not posts.is_empty():
		_add_section_label("IN TOWN POSTS")
		for line in posts:
			_add_chronicle_line(line)

	message_label.text = "The guild's record so far."
	var entries := GameState.chronicle
	if entries.is_empty():
		_detail.show_text("[b]Chronicle[/b]\n\nNothing worth writing down has happened yet.")
		return
	var text := "[b]Chronicle[/b]\n"
	var first := maxi(0, entries.size() - CHRONICLE_SHOWN)
	for i in range(entries.size() - 1, first - 1, -1):
		var entry: Dictionary = entries[i]
		text += "\n[color=#8a8680]%s[/color]\n[color=%s]%s[/color]\n" % [
			GameCalendar.format_short(entry.get("day", 1)),
			CHRONICLE_COLORS.get(entry.get("kind", ""), "#e0dcd2"), entry.get("text", "")]
	if first > 0:
		text += "\n[color=#8a8680]%d earlier entries not shown.[/color]" % first
	_detail.show_text(text)


func _add_chronicle_line(text: String) -> void:
	var label := Label.new()
	label.text = "  " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(340, 0)
	options_list.add_child(label)


func _on_create_character() -> void:
	SceneManager.go_to_character_creation()


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
		Tab.STORAGE:
			help_label.text = "%s | %s | Enter: Store or take | %s" % [
				KeyBindingHelper.get_horizontal_help(), KeyBindingHelper.get_nav_help(), KeyBindingHelper.get_cancel_help()]
		Tab.CHRONICLE:
			help_label.text = "%s | %s" % [KeyBindingHelper.get_horizontal_help(), KeyBindingHelper.get_cancel_help()]

	if _scaffold != null:
		_scaffold.set_hint(help_label.text)


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
		tab_bar.current_tab = (tab_bar.current_tab - 1 + tab_bar.tab_count) % tab_bar.tab_count
		return
	if event.is_action_pressed("menu_right"):
		tab_bar.current_tab = (tab_bar.current_tab + 1) % tab_bar.tab_count
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
		_:
			if nav:
				nav.handle_input(event)


func _on_back_pressed() -> void:
	SceneManager.go_to_town()

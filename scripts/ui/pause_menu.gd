class_name PauseMenu
extends Control
## Pause menu: freezes the game while open and runs even while the tree is
## paused. Pages: main buttons, rules, scoring cheat sheet, new-game confirm.

signal new_match_confirmed

const SETTINGS_PATH := "user://settings.cfg"
const PANEL_WIDTH := 600.0
const RULES_HEIGHT := 400.0
const BRASS := Color("f5d78c")

const RULES_TEXT := """[color=#f5d78c]Goal[/color]
Capture cards to score points. The first to reach 101 points at the end of a round wins the match.

[color=#f5d78c]The deal[/color]
Four cards go face up on the table and each player gets six. A jack never starts on the table: it goes back into the deck (the first to the bottom, a second to the middle) and is replaced. When both hands are empty, everyone gets six more (no new table cards) until the deck runs out.

[color=#f5d78c]Your turn[/color]
Play one card from your hand:
- Match: it takes every table card of the same rank.
- Add up: a number card also takes groups of table cards that add up to its value. Aces count as 1, so an 8 can take a 2 and a 6.
- Queens and kings only take matching queens and kings.
- Jacks sweep the whole table.
- If it takes nothing, it stays on the table.

A card always takes everything it can. Hover over a card to see what it will take.

[color=#f5d78c]Basra[/color]
Clear the whole table in one play, by matching or adding up, and you score a Basra worth 10 points. A 10 can take a 7 and a 3 for a Basra, but a 7 can't take a 10 and a 3. Sweeping with a jack never counts as a Basra.

[color=#f5d78c]End of a round[/color]
Whoever captured last takes the cards left on the table. Then the round is scored (see Scoring). If both sides pass 101, the higher score wins. An exact tie plays another round."""

const SCORING_ROWS := [
	["10 of diamonds", "3"],
	["2 of clubs", "2"],
	["Each ace", "1"],
	["Each jack", "1"],
	["Most cards captured", "3"],
	["Each Basra", "10"],
]

var _muted := false
var _pages: Array[Control] = []
var _main_page: VBoxContainer
var _rules_page: VBoxContainer
var _scoring_page: VBoxContainer
var _confirm_page: VBoxContainer
var _title: Label
var _resume_button: Button
var _sound_button: Button


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 40
	visible = false


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = PANEL_WIDTH
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	panel.add_child(rows)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", BRASS)
	rows.add_child(_title)

	_main_page = _build_main_page()
	_rules_page = _build_rules_page()
	_scoring_page = _build_scoring_page()
	_confirm_page = _build_confirm_page()
	for page: Control in [_main_page, _rules_page, _scoring_page, _confirm_page]:
		rows.add_child(page)
		_pages.append(page)

	_load_settings()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if not visible:
		open()
	elif _main_page.visible:
		resume()
	else:
		_show_page(_main_page, "Paused", _resume_button)


func open() -> void:
	get_tree().paused = true
	show()
	_show_page(_main_page, "Paused", _resume_button)


func resume() -> void:
	hide()
	get_tree().paused = false


# --- Pages --------------------------------------------------------------------

func _build_main_page() -> VBoxContainer:
	var page := _page()
	_resume_button = _button(page, "Resume", resume)
	_button(page, "Rules", func() -> void: _show_page(_rules_page, "Rules"))
	_button(page, "Scoring", func() -> void: _show_page(_scoring_page, "Scoring"))
	_sound_button = _button(page, "", _toggle_sound)
	_button(page, "New game", func() -> void: _show_page(_confirm_page, "New game?"))
	# A web or mobile build can't close its own window, so only desktop gets Quit.
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		_button(page, "Quit", func() -> void: get_tree().quit())
	return page


func _build_rules_page() -> VBoxContainer:
	var page := _page()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PANEL_WIDTH - 36, RULES_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("line_separation", 4)
	text.text = RULES_TEXT
	scroll.add_child(text)
	_back_button(page)
	return page


func _build_scoring_page() -> VBoxContainer:
	var page := _page()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("v_separation", 10)
	page.add_child(grid)
	for row: Array in SCORING_ROWS:
		var name_label := Label.new()
		name_label.text = row[0]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var points := Label.new()
		points.text = row[1]
		points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		points.add_theme_color_override("font_color", BRASS)
		grid.add_child(points)
	var note := Label.new()
	note.text = "No one gets the most-cards bonus if it's a tie."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = PANEL_WIDTH - 36
	note.add_theme_color_override("font_color", Color("bfad94"))
	page.add_child(note)
	_back_button(page)
	return page


func _build_confirm_page() -> VBoxContainer:
	var page := _page()
	var message := Label.new()
	message.text = "Start a new match? The current score will be lost."
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.custom_minimum_size.x = PANEL_WIDTH - 36
	page.add_child(message)
	_button(page, "Start new match", func() -> void:
		resume()
		new_match_confirmed.emit())
	_back_button(page, "Cancel")
	return page


func _page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	return page


func _button(page: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.x = 300
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	page.add_child(button)
	return button


func _back_button(page: Control, text: String = "Back") -> void:
	_button(page, text, func() -> void: _show_page(_main_page, "Paused", _resume_button))


func _show_page(page: Control, title: String, focus: Button = null) -> void:
	_title.text = title
	for other in _pages:
		other.visible = other == page
	var target := focus
	if target == null:
		for child in page.get_children():
			if child is Button:
				target = child
	if target:
		target.grab_focus()


# --- Settings -----------------------------------------------------------------

func _toggle_sound() -> void:
	_muted = not _muted
	_apply_sound()
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "muted", _muted)
	config.save(SETTINGS_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		_muted = config.get_value("audio", "muted", false)
	_apply_sound()


func _apply_sound() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), _muted)
	_sound_button.text = "Sound: Off" if _muted else "Sound: On"

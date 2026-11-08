extends SceneTree
## Plays the real game scene headless and checks the pause menu, a mid-turn
## restart, achievements and a full match. Prints PASS/FAIL lines and exits
## with code 1 if any check fails.
##
## Run from the project root (the time limit stops a hung run):
##   perl -e 'alarm 200; exec @ARGV' /Applications/Godot.app/Contents/MacOS/Godot \
##     --headless --path . --script tools/ui_smoke_test.gd
##
## Progress goes to a throwaway file so the player's real achievements are
## never touched, and the sound setting is left as it was found.

const HARNESS_PROGRESS := "user://harness_progress.cfg"
## Frames before giving up on a step that never happens.
const STEP_TIMEOUT := 6000

var main: Control
var menu: PauseMenu
var step := "wait_human"
var waited := 0
var snapshot := {}
var first_game: Object
var failures := 0
var toasts := 0


func _initialize() -> void:
	Engine.time_scale = 20.0
	main = load("res://scenes/main.tscn").instantiate()
	main.progress_path = HARNESS_PROGRESS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HARNESS_PROGRESS))
	root.add_child(main)
	process_frame.connect(_tick)


func finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HARNESS_PROGRESS))
	print("FAILURES ", failures)
	quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		failures += 1


func _find_button(text: String) -> Button:
	for button in menu.find_children("*", "Button", true, false):
		if button.text == text:
			return button
	return null


func _press_escape() -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	Input.parse_input_event(event)


func _tick() -> void:
	waited += 1
	if waited > STEP_TIMEOUT:
		check(false, "step '%s' finished in time" % step)
		finish()
		return
	if menu == null:
		if main._pause_menu == null:
			return
		menu = main._pause_menu
		main._toast.shown.connect(func() -> void: toasts += 1)
	match step:
		"wait_human":
			if not main.busy and main.game.current_player == 0:
				main._on_card_pressed(main._views[main.game.hands[0][0]])
				step = "wait_ai_busy"
				waited = 0
		"wait_ai_busy":
			if main.busy and main.game.current_player == 1:
				menu.open()
				snapshot = {"hand": main.game.hands[1].size(), "table": main.game.table.size()}
				step = "paused"
				waited = 0
		"paused":
			if waited == 120:
				check(paused, "tree is paused while menu is open")
				check(main.game.hands[1].size() == snapshot.hand and main.game.table.size() == snapshot.table,
					"AI did not move while paused")
				var was_muted := AudioServer.is_bus_mute(0)
				menu._sound_button.pressed.emit()
				check(AudioServer.is_bus_mute(0) != was_muted, "sound toggle flips")
				menu._sound_button.pressed.emit()
				check(AudioServer.is_bus_mute(0) == was_muted, "sound toggle flips back")
				_find_button("Achievements").pressed.emit()
				check(menu._achievements_page.visible, "achievements page opens")
				check(menu._achievement_list.get_child_count() == AchievementTracker.ACHIEVEMENTS.size(),
					"every achievement is listed")
				_find_button("Card backs").pressed.emit()
				check(menu._backs_page.visible and menu._backs_grid.get_child_count() == AchievementTracker.CARD_BACKS.size(),
					"card backs page lists every back")
				menu._show_page(menu._main_page, "Paused")
				_find_button("Rules").pressed.emit()
				check(menu._rules_page.visible and not menu._main_page.visible, "rules page opens")
				_press_escape()
				step = "esc_back"
				waited = 0
		"esc_back":
			if waited == 3:
				check(menu.visible and menu._main_page.visible, "Esc on rules returns to main page")
				_find_button("New game").pressed.emit()
				check(menu._confirm_page.visible, "new game asks for confirmation")
				first_game = main.game
				_find_button("Start new match").pressed.emit()
				check(not paused and not menu.visible, "confirming closes menu and unpauses")
				step = "wait_restart"
				waited = 0
		"wait_restart":
			if main.game != first_game and not main.busy and main.game.current_player == 0:
				check(main.game.round_number == 1 and main.game.scores == [0, 0], "new match started at 0-0")
				check(Engine.time_scale == 1.0, "time scale restored after restart")
				Engine.time_scale = 20.0
				_press_escape()
				step = "esc_open"
				waited = 0
		"esc_open":
			if waited == 3:
				check(menu.visible and paused, "Esc opens the menu")
				_press_escape()
				step = "esc_close"
				waited = 0
		"esc_close":
			if waited == 3:
				check(not menu.visible and not paused, "Esc on main page resumes")
				step = "play_out"
				waited = 0
		"play_out":
			var overlay: Control = main.get_node("%Overlay")
			if overlay.visible:
				if main.game.phase == BasraGame.Phase.MATCH_OVER:
					check(true, "match after restart played to the end")
					var tracker: AchievementTracker = main._tracker
					print("unlocked: ", tracker.unlocked.keys(), " stats ", tracker.stats, " toasts ", toasts)
					check(tracker.stats.matches == 1, "the finished match was counted")
					check(toasts >= tracker.unlocked.size(), "every unlock announced")
					var saved := AchievementTracker.new()
					saved.load_from(HARNESS_PROGRESS)
					check(saved.unlocked.size() == tracker.unlocked.size(), "progress saved to the harness file")
					check(not FileAccess.file_exists("user://progress.cfg") or FileAccess.get_modified_time("user://progress.cfg") < Time.get_unix_time_from_system() - 120,
						"the real progress file was not touched")
					finish()
					return
				waited = 0
				main._on_overlay_button_pressed()
			elif not main.busy and main.game.current_player == 0 and not main.game.hands[0].is_empty():
				var view: CardView = main._views[main.game.hands[0][0]]
				if view.playable:
					main._on_card_pressed(view)

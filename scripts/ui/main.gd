extends Control
## Runs one human-versus-AI match: turns the game state into card movement.

const HUMAN := 0
const OPPONENT := 1
const TEAM_NAMES := ["You", "Opponent"]

const SIDE_PANEL_WIDTH := 260.0
const SLOT_MARGIN := 28.0
const SLOT_GAP := 12.0
const TABLE_SINGLE_ROW_MAX := 6

const HAND_STRIDE := 94.0
const FAN_ANGLE := 2.6
const FAN_DROP := 2.4
const HOVER_LIFT := 26.0

const MOVE_TIME := 0.28
const DEAL_STAGGER := 0.05
const CAPTURE_PAUSE := 0.5
const OPPONENT_THINK_TIME := 0.8
const SHAKE_DECAY := 7.0
## How much faster the old match plays out while a new one is waiting to start.
const RESTART_TIME_SCALE := 8.0

const REVEAL_CARD_STRIDE := 106.0
const REVEAL_FAST_FACTOR := 0.1

const BRASS := Color("f5d78c")
const RED := Color("ee6b61")
const BURST_COLORS := [Color("f5d78c"), Color("ee6b61"), Color("f7f0df")]

## Felt colours (dark, mid, light) for the marbled table. Every match starts on
## Cedar; each new round blends to a different one at random.
const FELT_PALETTES := [
	{"name": "Cedar", "colors": [Color("13332a"), Color("1c493b"), Color("295e4d")]},
	{"name": "Mediterranean", "colors": [Color("10283f"), Color("173a5a"), Color("22507a")]},
	{"name": "Twilight", "colors": [Color("231a38"), Color("33264f"), Color("463569")]},
	{"name": "Olive", "colors": [Color("26290f"), Color("383c17"), Color("4d5222")]},
	{"name": "Coffee", "colors": [Color("2b1c13"), Color("3d291c"), Color("533a28")]},
	{"name": "Slate", "colors": [Color("1c2329"), Color("29333b"), Color("3a4651")]},
	{"name": "Wine", "colors": [Color("2c1220"), Color("3f1a2e"), Color("57263f")]},
]
const FELT_UNIFORMS := ["dark_color", "mid_color", "light_color"]
const FELT_BLEND_TIME := 1.6

var game: BasraGame
var busy := true

## Card -> CardView for every card currently in a hand or on the table.
var _views := {}
var _deck_view: CardView
var _pile_views: Array[CardView] = []
var _slot_panels: Array[Panel] = []
var _hand_tray: Panel
var _reveal_views: Array[CardView] = []
var _sfx: Sfx

## The score shown in the HUD, which lags game.scores during the reveal.
var _shown_scores := [0, 0]
var _shake := 0.0
var _revealing := false
var _reveal_fast := false
## Set when a new match was asked for mid-animation; it starts at the next
## safe point (a turn change or the end of a round).
var _restart_pending := false
var _pause_menu: PauseMenu
var _felt_index := 0
var _felt_tween: Tween

@onready var _board: Control = %Board
@onready var _felt_material: ShaderMaterial = ($Felt as ColorRect).material
@onready var _your_score: Label = %YourScore
@onready var _opponent_score: Label = %OpponentScore
@onready var _round_label: Label = %RoundLabel
@onready var _status: Label = %StatusLabel
@onready var _deck_count: Label = %DeckCount
@onready var _your_cards: Label = %YourCards
@onready var _opponent_cards: Label = %OpponentCards
@onready var _your_basras: Label = %YourBasras
@onready var _opponent_basras: Label = %OpponentBasras
@onready var _banner: Label = %Banner
@onready var _overlay: Control = %Overlay
@onready var _overlay_title: Label = %OverlayTitle
@onready var _overlay_grid: GridContainer = %OverlayGrid
@onready var _overlay_button: Button = %OverlayButton
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	_sfx = Sfx.new()
	add_child(_sfx)
	for i in 3:
		_slot_panels.append(_make_slot())
	_hand_tray = _make_slot()
	_deck_view = _make_static_back()
	for team in BasraGame.TEAM_COUNT:
		_pile_views.append(_make_static_back())
	_board.resized.connect(_on_board_resized)
	_overlay_button.pressed.connect(_on_overlay_button_pressed)
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.new_match_confirmed.connect(_request_new_match)
	_menu_button.pressed.connect(_pause_menu.open)
	_start_match()


func _process(delta: float) -> void:
	if _shake <= 0.0:
		return
	_shake = maxf(_shake - _shake * SHAKE_DECAY * delta - delta, 0.0)
	_board.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake


func _input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if _revealing and button and button.pressed:
		_reveal_fast = true


func _start_match() -> void:
	_restart_pending = false
	Engine.time_scale = 1.0
	game = BasraGame.new()
	game.start_match(2, randi())
	_set_felt(0, false)
	_begin_round()


func _begin_round() -> void:
	busy = true
	_overlay.hide()
	for view: CardView in _views.values():
		view.queue_free()
	_views.clear()
	for view in _reveal_views:
		view.queue_free()
	_reveal_views.clear()
	_shown_scores = game.scores.duplicate()
	if game.round_number > 1:
		_set_felt(_random_other_palette(), true)
	_refresh_hud()
	_place_static_views()
	await _deal(true)
	busy = false
	_next_turn()


## Starts a new match now if nothing is animating, otherwise fast-forwards to
## the next safe point so no animation is left touching the old match.
func _request_new_match() -> void:
	if not busy or _overlay.visible:
		_start_match()
		return
	_restart_pending = true
	_status.text = "Starting a new match…"
	Engine.time_scale = RESTART_TIME_SCALE


func _next_turn() -> void:
	if _restart_pending:
		_start_match()
		return
	if game.phase != BasraGame.Phase.PLAYING:
		return
	if game.current_player == HUMAN:
		_status.text = "Your turn"
		for card: Card in game.hands[HUMAN]:
			_views[card].playable = true
		return

	_status.text = "Opponent is playing…"
	busy = true
	await get_tree().create_timer(OPPONENT_THINK_TIME, false).timeout
	_play(OPPONENT, BasraAI.choose_card(game.hands[OPPONENT], game.table))


func _play(player: int, hand_index: int) -> void:
	busy = true
	for card: Card in game.hands[HUMAN]:
		_views[card].playable = false
		_views[card].hovered = false
	_set_capture_preview([])

	var result := game.play_card(player, hand_index)
	await _animate_play(result)
	_refresh_hud()
	if result.dealt:
		await _deal(false)
	if result.round_over:
		await _collect_leftovers(result)
		_refresh_hud()
		await _reveal_scores()
		_show_round_summary()
		return
	busy = false
	_next_turn()


func _animate_play(result: Dictionary) -> void:
	var card: Card = result.card
	var view: CardView = _views[card]
	var captured: Array[Card] = result.captured
	view.z_index = 10
	view.scale = Vector2.ONE
	if not view.face_up:
		view.flip_to(true)

	if captured.is_empty():
		_layout_hands()
		_layout_table()
		await _wait(MOVE_TIME)
		_sfx.card_tap()
		view.pop(1.1)
		view.z_index = 0
		return

	# Land the played card next to what it takes, then sweep them all away.
	var first_taken: CardView = _views[captured[0]]
	_move(view, first_taken.position + Vector2(18, 18), view.table_angle)
	_layout_hands()
	for taken in captured:
		_views[taken].highlighted = true
	await _wait(MOVE_TIME)
	_sfx.card_tap()
	view.pop()

	var impact_point := view.position + CardView.CARD_SIZE / 2
	if result.basra:
		_celebrate_basra(impact_point)
	elif BasraRules.is_sweeper(card):
		_sfx.play("thud")
		_shake = maxf(_shake, 7.0)
	await _wait(CAPTURE_PAUSE)

	var going: Array[Card] = captured.duplicate()
	going.append(card)
	await _send_to_pile(going, result.team)
	_layout_table()


func _collect_leftovers(result: Dictionary) -> void:
	var leftovers: Array[Card] = result.leftovers
	if leftovers.is_empty() or game.last_capture_team < 0:
		return
	_status.text = "%s take%s the last cards" % [
		TEAM_NAMES[game.last_capture_team], "" if game.last_capture_team == HUMAN else "s",
	]
	await _wait(CAPTURE_PAUSE)
	await _send_to_pile(leftovers, game.last_capture_team)


func _send_to_pile(cards: Array[Card], team: int) -> void:
	var target := _pile_position(team)
	for card in cards:
		var view: CardView = _views[card]
		view.highlighted = false
		view.z_index = 5
		_move(view, target, 0.0)
	await _wait(MOVE_TIME)
	_sfx.card_tap()
	for card in cards:
		_views[card].queue_free()
		_views.erase(card)


## Deals out from the deck: the hands, and the table too on a new round.
func _deal(include_table: bool) -> void:
	_status.text = "Dealing…"
	var order: Array[Card] = []
	if include_table:
		order.append_array(game.table)
	for i in BasraRules.HAND_SIZE:
		for player in game.player_count:
			order.append(game.hands[player][i])

	var delay := 0.0
	for card in order:
		var view := CardView.new()
		view.card = card
		view.position = _deck_position()
		view.pressed.connect(_on_card_pressed)
		view.hover_changed.connect(_on_card_hover)
		_board.add_child(view)
		_views[card] = view
		var tween := view.create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(_sfx.card_tap)
		tween.tween_property(view, "position", _home_position(card), MOVE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(view, "rotation_degrees", _home_angle(card), MOVE_TIME)
		if card not in game.hands[OPPONENT]:
			tween.tween_callback(view.flip_to.bind(true))
		delay += DEAL_STAGGER
	await _wait(delay + MOVE_TIME + 0.2)
	_refresh_hud()


# --- Scoring reveal ---------------------------------------------------------

## Lays out each side's scoring cards one at a time while the score counts up.
## Clicking speeds the rest of the reveal up.
func _reveal_scores() -> void:
	_revealing = true
	_reveal_fast = false
	_status.text = "Scoring…"
	await _beat(0.35)

	var step := 0
	for team: int in [HUMAN, OPPONENT]:
		var scoring := _scoring_cards(team)
		var row_y := _reveal_row_y(team)
		for i in scoring.size():
			var card: Card = scoring[i]
			var view := CardView.new()
			view.card = card
			view.face_up = true
			view.z_index = 6
			view.position = _pile_position(team)
			_board.add_child(view)
			_reveal_views.append(view)
			_move(view, Vector2(_reveal_card_x(i, scoring.size()), row_y), 0.0)
			await _beat(MOVE_TIME * 0.7)
			view.pop(1.22)
			var center := view.position + CardView.CARD_SIZE / 2
			_award(team, BasraRules.card_points(card), center, step)
			step += 1
			await _beat(0.12)

		var pile_center := _pile_position(team) + CardView.CARD_SIZE / 2
		var result: Dictionary = game.last_round_result[team]
		if result.majority > 0:
			_award(team, result.majority, pile_center, step, "Most cards  ")
			step += 1
			await _beat(0.45)
		for i: int in result.basras:
			_award(team, BasraRules.BASRA_POINTS, pile_center, step, "Basra  ")
			_shake = maxf(_shake, 10.0)
			_burst(pile_center)
			step += 1
			await _beat(0.5)

	_shown_scores = game.scores.duplicate()
	_refresh_hud()
	await _beat(0.5)
	_revealing = false


func _scoring_cards(team: int) -> Array[Card]:
	var scoring: Array[Card] = []
	for card: Card in game.piles[team]:
		if BasraRules.card_points(card) > 0:
			scoring.append(card)
	scoring.sort_custom(func(a: Card, b: Card) -> bool:
		return BasraRules.card_points(a) > BasraRules.card_points(b))
	return scoring


func _reveal_row_y(team: int) -> float:
	var middle := _board.size.y / 2
	return middle - 24.0 if team == HUMAN else middle - CardView.CARD_SIZE.y - 72.0


func _reveal_card_x(index: int, count: int) -> float:
	var play := _play_rect()
	var usable := play.size.x - 2 * (CardView.CARD_SIZE.x + SLOT_MARGIN * 2)
	var stride := minf(REVEAL_CARD_STRIDE, (usable - CardView.CARD_SIZE.x) / maxf(count - 1, 1))
	var row_width := stride * (count - 1) + CardView.CARD_SIZE.x
	return play.get_center().x - row_width / 2 + stride * index


func _award(team: int, points: int, at: Vector2, step: int, caption: String = "") -> void:
	_shown_scores[team] += points
	_refresh_hud()
	_punch(_your_score if team == HUMAN else _opponent_score)
	_float_text("%s+%d" % [caption, points], at, BRASS if team == HUMAN else RED)
	_sfx.play("tick", 1.0 + step * 0.06)


func _beat(seconds: float) -> void:
	await _wait(seconds * (REVEAL_FAST_FACTOR if _reveal_fast else 1.0))


# --- Effects ----------------------------------------------------------------

func _celebrate_basra(at: Vector2) -> void:
	_shake = 16.0
	_burst(at)
	_show_banner("Basra!  +%d" % BasraRules.BASRA_POINTS)
	_sfx.play("thud", 1.0, -4.0)
	for i in 3:
		get_tree().create_timer(i * 0.09, false).timeout.connect(_sfx.play.bind("tick", 1.0 + i * 0.25))


func _burst(at: Vector2) -> void:
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 0.75])
	ramp.colors = PackedColorArray(BURST_COLORS)

	var particles := CPUParticles2D.new()
	particles.position = at
	particles.z_index = 18
	particles.amount = 48
	particles.lifetime = 0.9
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2(0, 620)
	particles.initial_velocity_min = 180.0
	particles.initial_velocity_max = 520.0
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 10.0
	particles.color_initial_ramp = ramp
	particles.finished.connect(particles.queue_free)
	_board.add_child(particles)
	particles.emitting = true


func _float_text(text: String, at: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.z_index = 22
	label.add_theme_font_size_override("font_size", 33)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("1f1612"))
	label.add_theme_constant_override("outline_size", 10)
	_board.add_child(label)
	label.position = at - label.get_minimum_size() / 2
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 62.0, 0.75) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tween.tween_callback(label.queue_free)


func _punch(label: Label) -> void:
	label.pivot_offset = label.size / 2
	label.scale = Vector2(1.35, 1.35)
	label.create_tween().tween_property(label, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.pivot_offset = _banner.size / 2
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(0.5, 0.5)
	_banner.rotation_degrees = -7.0
	_banner.show()
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.1)
	tween.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_banner, "rotation_degrees", -3.0, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.7)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.25)
	tween.tween_callback(_banner.hide)


# --- Felt ---------------------------------------------------------------------

func _set_felt(index: int, blend: bool) -> void:
	_felt_index = index
	if _felt_tween:
		_felt_tween.kill()
	var colors: Array = FELT_PALETTES[index].colors
	if not blend:
		for i in FELT_UNIFORMS.size():
			_felt_material.set_shader_parameter(FELT_UNIFORMS[i], colors[i])
		return
	_felt_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	for i in FELT_UNIFORMS.size():
		_felt_tween.tween_property(
			_felt_material, "shader_parameter/" + FELT_UNIFORMS[i], colors[i], FELT_BLEND_TIME
		)


func _random_other_palette() -> int:
	var index := randi_range(0, FELT_PALETTES.size() - 2)
	return index + 1 if index >= _felt_index else index


# --- Layout -----------------------------------------------------------------

## The area right of the side panel, where all the cards live.
func _play_rect() -> Rect2:
	return Rect2(SIDE_PANEL_WIDTH, 0, _board.size.x - SIDE_PANEL_WIDTH, _board.size.y)


func _deck_position() -> Vector2:
	return Vector2(_play_rect().position.x + SLOT_MARGIN, _board.size.y / 2 - CardView.CARD_SIZE.y / 2 - 20)


func _pile_position(team: int) -> Vector2:
	var x := _play_rect().end.x - CardView.CARD_SIZE.x - SLOT_MARGIN
	var y := 40.0 if team == OPPONENT else _board.size.y - CardView.CARD_SIZE.y - 40
	return Vector2(x, y)


## Where a card rests right now, given which hand or table it is in.
func _home_position(card: Card) -> Vector2:
	var table_index := game.table.find(card)
	if table_index >= 0:
		return _table_position(table_index, game.table.size())
	for player in game.player_count:
		var index: int = game.hands[player].find(card)
		if index >= 0:
			return _hand_position(player, index, game.hands[player].size())
	return _deck_position()


func _home_angle(card: Card) -> float:
	if card in game.table:
		return _views[card].table_angle
	for player in game.player_count:
		var index: int = game.hands[player].find(card)
		if index >= 0:
			return _fan_offset(index, game.hands[player].size()) * FAN_ANGLE * (1 if player == HUMAN else -1)
	return 0.0


## How far a card sits from the middle of its hand, in card widths.
func _fan_offset(index: int, count: int) -> float:
	return index - (count - 1) / 2.0


func _hand_position(player: int, index: int, count: int) -> Vector2:
	var offset := _fan_offset(index, count)
	var x := _play_rect().get_center().x - CardView.CARD_SIZE.x / 2 + offset * HAND_STRIDE
	var drop := offset * offset * FAN_DROP
	if player == HUMAN:
		return Vector2(x, _board.size.y - CardView.CARD_SIZE.y - 40 + drop)
	return Vector2(x, -84.0 - drop)


func _table_position(index: int, count: int) -> Vector2:
	var card_size := CardView.CARD_SIZE
	var play := _play_rect()
	var rows := 1 if count <= TABLE_SINGLE_ROW_MAX else 2
	var columns := ceili(float(count) / rows)
	var usable := play.size.x - 2 * (card_size.x + SLOT_MARGIN * 2)
	var stride := minf(card_size.x + SLOT_GAP, (usable - card_size.x) / maxf(columns - 1, 1))
	@warning_ignore("integer_division")
	var row := index / columns
	var row_count := columns if row < rows - 1 else count - columns * (rows - 1)
	var row_width := stride * (row_count - 1) + card_size.x
	var total_height := rows * card_size.y + (rows - 1) * SLOT_GAP
	var top := (_board.size.y - total_height) / 2 - 34
	return Vector2(
		play.get_center().x - row_width / 2 + stride * (index % columns),
		top + row * (card_size.y + SLOT_GAP)
	)


func _layout_hands() -> void:
	for player in game.player_count:
		for card: Card in game.hands[player]:
			if card in _views:
				_move(_views[card], _home_position(card), _home_angle(card))


func _layout_table() -> void:
	for card in game.table:
		_move(_views[card], _home_position(card), _home_angle(card))


func _move(view: CardView, target: Vector2, angle: float) -> void:
	var tween := view.create_tween().set_parallel()
	tween.tween_property(view, "position", target, MOVE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "rotation_degrees", angle, MOVE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _place_static_views() -> void:
	_deck_view.position = _deck_position()
	for team in _pile_views.size():
		_pile_views[team].position = _pile_position(team)

	var slot_targets: Array[Vector2] = [
		_deck_position(), _pile_position(HUMAN), _pile_position(OPPONENT),
	]
	for i in slot_targets.size():
		_slot_panels[i].position = slot_targets[i] - Vector2(8, 8)
		_slot_panels[i].size = CardView.CARD_SIZE + Vector2(16, 16)

	var tray_width := HAND_STRIDE * BasraRules.HAND_SIZE + 60.0
	_hand_tray.size = Vector2(tray_width, CardView.CARD_SIZE.y + 30)
	_hand_tray.position = Vector2(
		_play_rect().get_center().x - tray_width / 2, _board.size.y - _hand_tray.size.y - 12
	)


func _make_slot() -> Panel:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.2)
	style.set_corner_radius_all(14)
	var slot := Panel.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", style)
	_board.add_child(slot)
	return slot


func _make_static_back() -> CardView:
	var view := CardView.new()
	view.visible = false
	view.idle = false
	_board.add_child(view)
	return view


func _on_board_resized() -> void:
	if game == null:
		return
	_place_static_views()
	if not busy:
		for card: Card in _views:
			_views[card].position = _home_position(card)


# --- HUD --------------------------------------------------------------------

func _refresh_hud() -> void:
	_your_score.text = str(_shown_scores[HUMAN])
	_opponent_score.text = str(_shown_scores[OPPONENT])
	_round_label.text = "Round %d" % game.round_number
	_deck_view.visible = not game.deck.is_empty()
	_deck_count.text = str(game.deck.size())
	_your_cards.text = str(game.piles[HUMAN].size())
	_opponent_cards.text = str(game.piles[OPPONENT].size())
	_your_basras.text = str(game.basras[HUMAN])
	_opponent_basras.text = str(game.basras[OPPONENT])
	for team in _pile_views.size():
		_pile_views[team].visible = not game.piles[team].is_empty()


func _show_round_summary() -> void:
	if _restart_pending:
		_start_match()
		return
	for child in _overlay_grid.get_children():
		_overlay_grid.remove_child(child)
		child.queue_free()

	var mine: Dictionary = game.last_round_result[HUMAN]
	var theirs: Dictionary = game.last_round_result[OPPONENT]
	_add_summary_row("", "You", "Opponent", true)
	_add_summary_row("10 of diamonds", mine.ten_of_diamonds, theirs.ten_of_diamonds)
	_add_summary_row("2 of clubs", mine.two_of_clubs, theirs.two_of_clubs)
	_add_summary_row("Aces", mine.aces, theirs.aces)
	_add_summary_row("Jacks", mine.jacks, theirs.jacks)
	_add_summary_row("Most cards (%d - %d)" % [mine.cards, theirs.cards], mine.majority, theirs.majority)
	_add_summary_row("Basras", mine.basra_points, theirs.basra_points)
	_add_summary_row("This round", mine.total, theirs.total, true)
	_add_summary_row("Match total", game.scores[HUMAN], game.scores[OPPONENT], true)

	if game.phase == BasraGame.Phase.MATCH_OVER:
		_overlay_title.text = "You win the match!" if game.winner == HUMAN else "Opponent wins the match"
		_overlay_button.text = "New match"
	else:
		_overlay_title.text = "End of round %d" % game.round_number
		_overlay_button.text = "Next round"
	_status.text = ""
	_overlay.show()
	_overlay_button.grab_focus()


func _add_summary_row(label: String, mine: Variant, theirs: Variant, emphasis: bool = false) -> void:
	var cells := [label, str(mine), str(theirs)]
	for i in cells.size():
		var cell := Label.new()
		cell.text = cells[i]
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL if i == 0 else Control.SIZE_SHRINK_END
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		cell.custom_minimum_size.x = 0.0 if i == 0 else 124.0
		if emphasis:
			cell.add_theme_color_override("font_color", BRASS)
		_overlay_grid.add_child(cell)


# --- Input ------------------------------------------------------------------

func _on_card_pressed(view: CardView) -> void:
	if busy or game.current_player != HUMAN:
		return
	_play(HUMAN, game.hands[HUMAN].find(view.card))


## Hovering a card in hand lifts it and outlines what it would capture.
func _on_card_hover(view: CardView, hovering: bool) -> void:
	if busy or not view.playable:
		return
	view.hovered = hovering
	var rest := _home_position(view.card)
	var angle := _home_angle(view.card)
	if hovering:
		_move(view, rest + Vector2(0, -HOVER_LIFT), angle * 0.4)
		_sfx.play("tick", 1.5, -20.0)
	else:
		_move(view, rest, angle)
	_set_capture_preview(BasraRules.capture_for(view.card, game.table) if hovering else [])


func _set_capture_preview(cards: Array) -> void:
	for card in game.table:
		_views[card].highlighted = card in cards


func _on_overlay_button_pressed() -> void:
	if game.phase == BasraGame.Phase.MATCH_OVER:
		_start_match()
	else:
		game.start_round()
		_begin_round()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout

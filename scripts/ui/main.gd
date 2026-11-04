extends Control
## Runs one human-versus-AI match: turns the game state into card movement.

const HUMAN := 0
const OPPONENT := 1
const TEAM_NAMES := ["You", "Opponent"]

const MOVE_TIME := 0.28
const DEAL_STAGGER := 0.05
const CAPTURE_PAUSE := 0.5
const OPPONENT_THINK_TIME := 0.8
const HOVER_LIFT := 18.0
const SLOT_GAP := 12.0
const TABLE_SINGLE_ROW_MAX := 6

var game: BasraGame
var busy := true

## Card -> CardView for every card currently in a hand or on the table.
var _views := {}
var _deck_view: CardView
var _pile_views: Array[CardView] = []

@onready var _board: Control = %Board
@onready var _your_score: Label = %YourScore
@onready var _opponent_score: Label = %OpponentScore
@onready var _round_label: Label = %RoundLabel
@onready var _status: Label = %StatusLabel
@onready var _deck_count: Label = %DeckCount
@onready var _your_pile_count: Label = %YourPileCount
@onready var _opponent_pile_count: Label = %OpponentPileCount
@onready var _banner: Label = %Banner
@onready var _overlay: Control = %Overlay
@onready var _overlay_title: Label = %OverlayTitle
@onready var _overlay_grid: GridContainer = %OverlayGrid
@onready var _overlay_button: Button = %OverlayButton


func _ready() -> void:
	_deck_view = _make_static_back()
	for team in BasraGame.TEAM_COUNT:
		_pile_views.append(_make_static_back())
	_board.resized.connect(_on_board_resized)
	_overlay_button.pressed.connect(_on_overlay_button_pressed)
	_start_match()


func _start_match() -> void:
	game = BasraGame.new()
	game.start_match(2, randi())
	_begin_round()


func _begin_round() -> void:
	busy = true
	_overlay.hide()
	for view: CardView in _views.values():
		view.queue_free()
	_views.clear()
	_refresh_hud()
	_place_static_views()
	await _deal(true)
	busy = false
	_next_turn()


func _next_turn() -> void:
	if game.phase != BasraGame.Phase.PLAYING:
		return
	if game.current_player == HUMAN:
		_status.text = "Your turn"
		for card: Card in game.hands[HUMAN]:
			_views[card].playable = true
		return

	_status.text = "Opponent is playing…"
	busy = true
	await get_tree().create_timer(OPPONENT_THINK_TIME).timeout
	_play(OPPONENT, BasraAI.choose_card(game.hands[OPPONENT], game.table))


func _play(player: int, hand_index: int) -> void:
	busy = true
	for card: Card in game.hands[HUMAN]:
		_views[card].playable = false
	_set_capture_preview([])

	var result := game.play_card(player, hand_index)
	await _animate_play(result)
	_refresh_hud()
	if result.dealt:
		await _deal(false)
	if result.round_over:
		await _collect_leftovers(result)
		_refresh_hud()
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
		view.z_index = 0
		return

	# Land the played card next to what it takes, then sweep them all away.
	var first_taken: CardView = _views[captured[0]]
	var landing := first_taken.position + Vector2(18, 18)
	_move(view, landing)
	_layout_hands()
	for taken in captured:
		_views[taken].highlighted = true
	await _wait(MOVE_TIME)

	if result.basra:
		_show_banner("Basra!  +%d" % BasraRules.BASRA_POINTS)
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
		_move(view, target)
	await _wait(MOVE_TIME)
	for card in cards:
		_views[card].queue_free()
		_views.erase(card)


## Deals every card that has no view yet out from the deck.
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
		tween.tween_property(view, "position", _home_position(card), MOVE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if card not in game.hands[OPPONENT]:
			tween.tween_callback(view.flip_to.bind(true))
		delay += DEAL_STAGGER
	await _wait(delay + MOVE_TIME + 0.2)
	_refresh_hud()


# --- Layout -----------------------------------------------------------------

func _deck_position() -> Vector2:
	return Vector2(44, _board.size.y / 2 - CardView.CARD_SIZE.y / 2)


func _pile_position(team: int) -> Vector2:
	var x := _board.size.x - CardView.CARD_SIZE.x - 44
	var y := 96.0 if team == OPPONENT else _board.size.y - CardView.CARD_SIZE.y - 84
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


func _hand_position(player: int, index: int, count: int) -> Vector2:
	var stride := CardView.CARD_SIZE.x + SLOT_GAP
	var start := (_board.size.x - stride * count + SLOT_GAP) / 2
	var y := _board.size.y - CardView.CARD_SIZE.y - 24 if player == HUMAN else -72.0
	return Vector2(start + stride * index, y)


func _table_position(index: int, count: int) -> Vector2:
	var card_size := CardView.CARD_SIZE
	var rows := 1 if count <= TABLE_SINGLE_ROW_MAX else 2
	var columns := ceili(float(count) / rows)
	var usable := _board.size.x - 2 * (card_size.x + 64)
	var stride := minf(card_size.x + SLOT_GAP, (usable - card_size.x) / maxf(columns - 1, 1))
	@warning_ignore("integer_division")
	var row := index / columns
	var row_count := columns if row < rows - 1 else count - columns * (rows - 1)
	var row_width := stride * (row_count - 1) + card_size.x
	var total_height := rows * card_size.y + (rows - 1) * SLOT_GAP
	var top := (_board.size.y - total_height) / 2 - 22
	return Vector2(
		(_board.size.x - row_width) / 2 + stride * (index % columns),
		top + row * (card_size.y + SLOT_GAP)
	)


func _layout_hands() -> void:
	for player in game.player_count:
		for card: Card in game.hands[player]:
			if card in _views:
				_move(_views[card], _home_position(card))


func _layout_table() -> void:
	for card in game.table:
		_move(_views[card], _home_position(card))


func _move(view: CardView, target: Vector2) -> void:
	view.create_tween().tween_property(view, "position", target, MOVE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _place_static_views() -> void:
	_deck_view.position = _deck_position()
	_deck_count.position = _deck_view.position + Vector2(0, CardView.CARD_SIZE.y + 6)
	for team in _pile_views.size():
		_pile_views[team].position = _pile_position(team)
	var labels: Array[Label] = [_your_pile_count, _opponent_pile_count]
	for team in labels.size():
		labels[team].position = _pile_position(team) + Vector2(0, CardView.CARD_SIZE.y + 6)


func _make_static_back() -> CardView:
	var view := CardView.new()
	view.visible = false
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
	_your_score.text = str(game.scores[HUMAN])
	_opponent_score.text = str(game.scores[OPPONENT])
	_round_label.text = "Round %d  ·  First to %d" % [game.round_number, BasraRules.TARGET_SCORE]
	_deck_view.visible = not game.deck.is_empty()
	_deck_count.text = "%d left" % game.deck.size()
	_your_pile_count.text = _pile_text(HUMAN)
	_opponent_pile_count.text = _pile_text(OPPONENT)
	for team in _pile_views.size():
		_pile_views[team].visible = not game.piles[team].is_empty()


func _pile_text(team: int) -> String:
	var text := "%d cards" % game.piles[team].size()
	var basra_count: int = game.basras[team]
	if basra_count > 0:
		text += "\nBasra ×%d" % basra_count
	return text


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.pivot_offset = _banner.size / 2
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(0.7, 0.7)
	_banner.show()
	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.7)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.25)
	tween.tween_callback(_banner.hide)


func _show_round_summary() -> void:
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
	_add_summary_row("Most cards (%d – %d)" % [mine.cards, theirs.cards], mine.majority, theirs.majority)
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
		cell.custom_minimum_size.x = 0.0 if i == 0 else 92.0
		if emphasis:
			cell.add_theme_color_override("font_color", Color("e0bb72"))
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
	var rest := _home_position(view.card)
	_move(view, rest + Vector2(0, -HOVER_LIFT) if hovering else rest)
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
	await get_tree().create_timer(seconds).timeout

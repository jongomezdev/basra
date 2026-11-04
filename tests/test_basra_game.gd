@tool
extends McpTestSuite

const C := Card.Suit.CLUBS
const D := Card.Suit.DIAMONDS
const H := Card.Suit.HEARTS
const S := Card.Suit.SPADES


func suite_name() -> String:
	return "basra_game"


func _cards(specs: Array) -> Array[Card]:
	var out: Array[Card] = []
	for spec: Array in specs:
		out.append(Card.new(spec[0], spec[1]))
	return out


## A two-player game in a fixed position with an empty deck.
func _position(hand_a: Array, hand_b: Array, table: Array) -> BasraGame:
	var game := BasraGame.new()
	game.start_match(2, 1)
	game.deck = []
	game.current_player = 0
	game.hands = [_cards(hand_a), _cards(hand_b)]
	game.table = _cards(table)
	return game


func _play_round(game: BasraGame) -> void:
	while game.phase == BasraGame.Phase.PLAYING:
		var player := game.current_player
		var index := BasraAI.choose_card(game.hands[player], game.table)
		assert_false(game.play_card(player, index).is_empty(), "AI move must be legal")


func test_two_player_deal() -> void:
	var game := BasraGame.new()
	game.start_match(2, 7)
	assert_eq(game.table.size(), 4)
	assert_eq(game.hands[0].size(), 6)
	assert_eq(game.hands[1].size(), 6)
	assert_eq(game.deck.size(), 36)


func test_four_player_deal() -> void:
	var game := BasraGame.new()
	game.start_match(4, 7)
	assert_eq(game.hands.size(), 4)
	assert_eq(game.deck.size(), 24)
	assert_eq(game.team_of(0), game.team_of(2))
	assert_eq(game.team_of(1), game.team_of(3))
	assert_ne(game.team_of(0), game.team_of(1))


func test_same_seed_deals_the_same_cards() -> void:
	var a := BasraGame.new()
	var b := BasraGame.new()
	a.start_match(2, 42)
	b.start_match(2, 42)
	assert_eq(a.table[0].describe(), b.table[0].describe())
	assert_eq(a.hands[0][0].describe(), b.hands[0][0].describe())


func test_out_of_turn_and_bad_index_are_rejected() -> void:
	var game := _position([[H, 5]], [[H, 6]], [[C, 9]])
	assert_true(game.play_card(1, 0).is_empty())
	assert_true(game.play_card(0, 3).is_empty())
	assert_eq(game.hands[0].size(), 1)


func test_no_capture_lays_card_on_table_and_passes_turn() -> void:
	var game := _position([[H, 5], [H, 6]], [[S, 13]], [[C, 9]])
	var result := game.play_card(0, 0)
	assert_true(result.captured.is_empty())
	assert_eq(game.table.size(), 2)
	assert_eq(game.current_player, 1)


func test_capture_moves_cards_to_the_pile() -> void:
	var game := _position([[H, 8], [H, 13]], [[S, 13]], [[C, 2], [S, 6], [C, 9]])
	game.play_card(0, 0)
	assert_eq(game.table.size(), 1)
	assert_eq(game.piles[0].size(), 3)


func test_basra_is_counted() -> void:
	var game := _position([[H, 5], [H, 13]], [[S, 12]], [[C, 5]])
	assert_true(game.play_card(0, 0).basra)
	assert_eq(game.basras[0], 1)


func test_sweep_is_not_a_basra() -> void:
	var game := _position([[H, 11], [H, 13]], [[S, 12]], [[C, 5]])
	var result := game.play_card(0, 0)
	assert_false(result.basra)
	assert_eq(game.basras[0], 0)
	assert_eq(game.table.size(), 0)


func test_hands_are_redealt_while_the_deck_lasts() -> void:
	var game := _position([[H, 13]], [[S, 12]], [[C, 9]])
	game.deck = _cards([
		[C, 3], [C, 4], [C, 5], [C, 6], [C, 7], [C, 8],
		[D, 3], [D, 4], [D, 5], [D, 6], [D, 8], [D, 9],
	])
	game.play_card(0, 0)
	var result := game.play_card(1, 0)
	assert_true(result.dealt)
	assert_eq(game.hands[0].size(), 6)
	assert_eq(game.hands[1].size(), 6)
	assert_eq(game.table.size(), 3, "no new table cards on a redeal")
	assert_eq(game.phase, BasraGame.Phase.PLAYING)


func test_last_capturer_takes_leftovers_without_a_basra() -> void:
	var game := _position([[H, 9]], [[S, 12]], [[C, 9], [C, 3]])
	game.play_card(0, 0)
	var result := game.play_card(1, 0)
	assert_true(result.round_over)
	assert_eq(result.leftovers.size(), 2)
	assert_eq(game.table.size(), 0)
	assert_eq(game.piles[0].size(), 4)
	assert_eq(game.basras[0], 0)


func test_reaching_101_ends_the_match() -> void:
	var game := _position([[H, 9]], [[S, 12]], [[C, 9]])
	game.scores = [98, 40]
	game.play_card(0, 0)
	game.play_card(1, 0)
	assert_eq(game.phase, BasraGame.Phase.MATCH_OVER)
	assert_eq(game.winner, 0)


func test_higher_score_wins_when_both_pass_101() -> void:
	var game := _position([[H, 9]], [[S, 12]], [[C, 9], [C, 3]])
	game.scores = [100, 110]
	game.play_card(0, 0)
	game.play_card(1, 0)
	assert_eq(game.winner, 1)


func test_tie_above_101_plays_another_round() -> void:
	var game := _position([[H, 9]], [[S, 12]], [[C, 9], [C, 3]])
	game.scores = [101, 104]
	game.play_card(0, 0)
	game.play_card(1, 0)
	assert_eq(game.scores[0], game.scores[1])
	assert_eq(game.phase, BasraGame.Phase.ROUND_OVER)


func test_every_card_is_accounted_for_after_a_round() -> void:
	for seed_value in 30:
		for players: int in [2, 4]:
			var game := BasraGame.new()
			game.start_match(players, seed_value)
			_play_round(game)
			var seen := {}
			for pile: Array in game.piles:
				for card: Card in pile:
					seen[card.describe()] = true
			for card: Card in game.table:
				seen[card.describe()] = true
			assert_eq(seen.size(), 52)


func test_round_totals_without_basras_are_sixteen() -> void:
	for seed_value in 30:
		var game := BasraGame.new()
		game.start_match(2, seed_value)
		_play_round(game)
		var results := game.last_round_result
		var bonus: int = results[0].basra_points + results[1].basra_points
		var tied: bool = results[0].cards == results[1].cards
		assert_eq(results[0].total + results[1].total - bonus, 13 if tied else 16)


func test_full_matches_finish() -> void:
	for seed_value in 10:
		var game := BasraGame.new()
		game.start_match(2, seed_value)
		var rounds := 0
		while game.phase != BasraGame.Phase.MATCH_OVER and rounds < 200:
			_play_round(game)
			if game.phase == BasraGame.Phase.ROUND_OVER:
				game.start_round()
			rounds += 1
		assert_eq(game.phase, BasraGame.Phase.MATCH_OVER)
		assert_true(game.scores.max() >= 101)


func test_ai_takes_a_basra_over_a_plain_discard() -> void:
	var hand := _cards([[H, 13], [H, 5]])
	assert_eq(BasraAI.choose_card(hand, _cards([[C, 5]])), 1)


func test_ai_grabs_the_ten_of_diamonds() -> void:
	var hand := _cards([[H, 4], [H, 10]])
	assert_eq(BasraAI.choose_card(hand, _cards([[D, 10], [C, 4], [S, 12], [S, 13]])), 1)


func test_ai_avoids_discarding_point_cards() -> void:
	var hand := _cards([[D, 10], [H, 13]])
	assert_eq(BasraAI.choose_card(hand, _cards([[C, 9], [C, 3]])), 1)

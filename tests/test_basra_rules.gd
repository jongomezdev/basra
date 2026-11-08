@tool
extends McpTestSuite

const C := Card.Suit.CLUBS
const D := Card.Suit.DIAMONDS
const H := Card.Suit.HEARTS
const S := Card.Suit.SPADES


func suite_name() -> String:
	return "basra_rules"


func _table(cards: Array) -> Array[Card]:
	var out: Array[Card] = []
	for spec: Array in cards:
		out.append(Card.new(spec[0], spec[1]))
	return out


func _ranks(cards: Array[Card]) -> Array:
	var out := []
	for card in cards:
		out.append(card.rank)
	out.sort()
	return out


func test_rank_match_takes_every_card_of_that_rank() -> void:
	var table := _table([[C, 5], [H, 5], [S, 9]])
	assert_eq(_ranks(BasraRules.capture_for(Card.new(D, 5), table)), [5, 5])


func test_sum_match_takes_a_pair() -> void:
	var table := _table([[C, 2], [H, 6], [S, 9]])
	assert_eq(_ranks(BasraRules.capture_for(Card.new(D, 8), table)), [2, 6])


func test_sum_of_three_cards() -> void:
	var table := _table([[C, 1], [H, 2], [S, 3]])
	assert_eq(_ranks(BasraRules.capture_for(Card.new(D, 6), table)), [1, 2, 3])


func test_one_card_takes_every_group_at_once() -> void:
	var table := _table([[C, 8], [H, 2], [S, 6], [C, 3], [H, 5], [S, 12]])
	assert_eq(_ranks(BasraRules.capture_for(Card.new(S, 8), table)), [2, 3, 5, 6, 8])


func test_overlapping_groups_keep_the_largest_capture() -> void:
	# 1+4 and 2+3 are disjoint, so both groups are taken.
	var table := _table([[C, 1], [H, 4], [S, 2], [C, 3]])
	assert_eq(_ranks(BasraRules.capture_for(Card.new(H, 5), table)), [1, 2, 3, 4])


func test_overlap_cannot_use_a_card_twice() -> void:
	var table := _table([[C, 1], [H, 2], [S, 2]])
	assert_eq(_ranks(BasraRules.capture_for(Card.new(H, 3), table)), [1, 2])


func test_ace_counts_as_one_in_sums() -> void:
	var table := _table([[C, 1], [H, 3]])
	assert_eq(_ranks(BasraRules.capture_for(Card.new(D, 4), table)), [1, 3])


func test_faces_never_join_sums() -> void:
	var table := _table([[C, 12], [H, 13], [S, 11]])
	assert_true(BasraRules.capture_for(Card.new(D, 10), table).is_empty())


func test_queen_only_takes_queens() -> void:
	var table := _table([[C, 12], [H, 13], [S, 5]])
	assert_eq(_ranks(BasraRules.capture_for(Card.new(D, 12), table)), [12])


func test_no_match_captures_nothing() -> void:
	var table := _table([[C, 9], [H, 8]])
	assert_true(BasraRules.capture_for(Card.new(D, 4), table).is_empty())


func test_jack_sweeps_everything() -> void:
	var table := _table([[C, 9], [H, 13], [S, 1]])
	assert_eq(BasraRules.capture_for(Card.new(D, Card.JACK), table).size(), 3)


func test_seven_of_diamonds_is_an_ordinary_seven() -> void:
	assert_false(BasraRules.is_sweeper(Card.new(D, 7)))
	assert_true(BasraRules.capture_for(Card.new(D, 7), _table([[C, 9], [H, 13]])).is_empty())
	assert_eq(_ranks(BasraRules.capture_for(Card.new(D, 7), _table([[C, 7], [H, 4], [S, 3]]))), [3, 4, 7])
	assert_true(BasraRules.is_basra(Card.new(D, 7), _table([[C, 7]])))


func test_sweeper_on_empty_table_captures_nothing() -> void:
	var empty: Array[Card] = []
	assert_true(BasraRules.capture_for(Card.new(D, Card.JACK), empty).is_empty())


func test_basra_is_matching_a_lone_card() -> void:
	assert_true(BasraRules.is_basra(Card.new(D, 5), _table([[C, 5]])))


func test_clearing_the_table_by_adding_up_is_a_basra() -> void:
	assert_true(BasraRules.is_basra(Card.new(D, 8), _table([[C, 2], [H, 6]])))
	assert_true(BasraRules.is_basra(Card.new(D, 10), _table([[C, 7], [H, 3]])))


func test_clearing_with_matches_and_sums_together_is_a_basra() -> void:
	assert_true(BasraRules.is_basra(Card.new(D, 5), _table([[C, 5], [H, 5]])))
	assert_true(BasraRules.is_basra(Card.new(D, 8), _table([[C, 8], [H, 2], [S, 6]])))


func test_a_sum_that_does_not_add_up_takes_nothing() -> void:
	var table := _table([[C, 10], [H, 3]])
	assert_true(BasraRules.capture_for(Card.new(H, 7), table).is_empty())
	assert_false(BasraRules.is_basra(Card.new(H, 7), table))


func test_jack_never_scores_basra() -> void:
	assert_false(BasraRules.is_basra(Card.new(D, Card.JACK), _table([[C, Card.JACK]])))
	assert_false(BasraRules.is_basra(Card.new(D, Card.JACK), _table([[C, 4], [H, 9]])))


func test_leaving_any_card_behind_is_not_a_basra() -> void:
	assert_false(BasraRules.is_basra(Card.new(D, 8), _table([[C, 2], [H, 6], [S, 4]])))
	assert_false(BasraRules.is_basra(Card.new(D, 5), _table([[C, 5], [H, 13]])))


func test_playing_onto_an_empty_table_is_not_a_basra() -> void:
	var empty: Array[Card] = []
	assert_false(BasraRules.is_basra(Card.new(D, 5), empty))


func test_can_be_cleared() -> void:
	assert_true(BasraRules.can_be_cleared(_table([[C, 2], [H, 6]])))
	assert_true(BasraRules.can_be_cleared(_table([[C, 12]])))
	assert_false(BasraRules.can_be_cleared(_table([[C, 9], [H, 6]])))
	assert_false(BasraRules.can_be_cleared(_table([[C, 12], [H, 13]])))
	assert_false(BasraRules.can_be_cleared(_table([[C, 11]])), "a lone jack can only be swept")


func test_card_points() -> void:
	assert_eq(BasraRules.card_points(Card.new(D, 10)), 3)
	assert_eq(BasraRules.card_points(Card.new(H, 10)), 0)
	assert_eq(BasraRules.card_points(Card.new(C, 2)), 2)
	assert_eq(BasraRules.card_points(Card.new(S, 2)), 0)
	assert_eq(BasraRules.card_points(Card.new(H, 1)), 1)
	assert_eq(BasraRules.card_points(Card.new(H, 11)), 1)
	assert_eq(BasraRules.card_points(Card.new(D, 7)), 0)


func test_round_score_breakdown() -> void:
	var mine := _table([[D, 10], [C, 2], [H, 1], [S, 11], [S, 4]])
	var theirs := _table([[S, 1], [H, 9]])
	var results := BasraRules.score_round([mine, theirs], [2, 0])
	assert_eq(results[0].ten_of_diamonds, 3)
	assert_eq(results[0].two_of_clubs, 2)
	assert_eq(results[0].aces, 1)
	assert_eq(results[0].jacks, 1)
	assert_eq(results[0].majority, 3)
	assert_eq(results[0].basra_points, 20)
	assert_eq(results[0].total, 30)
	assert_eq(results[1].total, 1)


func test_tied_card_count_gives_no_majority() -> void:
	var results := BasraRules.score_round([_table([[S, 4]]), _table([[H, 4]])], [0, 0])
	assert_eq(results[0].majority, 0)
	assert_eq(results[1].majority, 0)

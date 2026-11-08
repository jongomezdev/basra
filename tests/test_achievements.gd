@tool
extends McpTestSuite

const C := Card.Suit.CLUBS
const D := Card.Suit.DIAMONDS
const H := Card.Suit.HEARTS
const S := Card.Suit.SPADES
const SAVE_PATH := "user://test_achievements.cfg"

var tracker: AchievementTracker


func suite_name() -> String:
	return "achievements"


func setup() -> void:
	tracker = AchievementTracker.new()
	tracker.on_match_start()
	tracker.on_round_start()


func suite_teardown() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _cards(specs: Array) -> Array[Card]:
	var out: Array[Card] = []
	for spec: Array in specs:
		out.append(Card.new(spec[0], spec[1]))
	return out


## A play result shaped like BasraGame.play_card's.
func _play(card_spec: Array, captured: Array, basra: bool, team: int = 0, round_over: bool = false) -> Dictionary:
	return {
		"team": team, "player": team, "card": Card.new(card_spec[0], card_spec[1]),
		"captured": _cards(captured), "basra": basra, "round_over": round_over,
	}


## A finished round where team 0 holds `mine` and team 1 holds `theirs`.
func _finished_round(mine: Array, theirs: Array, scores: Array = [0, 0], basras: Array = [0, 0]) -> BasraGame:
	var game := BasraGame.new()
	game.piles = [_cards(mine), _cards(theirs)]
	game.basras = basras
	game.last_round_result = BasraRules.score_round(game.piles, basras)
	game.scores = scores
	return game


func test_first_basra_unlocks_once() -> void:
	assert_eq(tracker.on_play(_play([H, 5], [[C, 5]], true)), ["first_basra"] as Array[String])
	assert_true(tracker.on_play(_play([D, 5], [[S, 5]], true)).has("basra_streak"))
	assert_false(tracker.on_play(_play([D, 4], [[S, 4]], true)).has("first_basra"))
	assert_eq(tracker.stats.basras, 3)


func test_streak_is_broken_by_your_own_non_basra_play() -> void:
	tracker.on_play(_play([H, 5], [[C, 5]], true))
	tracker.on_play(_play([S, 9], [[C, 2]], false, 1))
	assert_true(tracker.on_play(_play([D, 7], [[C, 7]], true)).has("basra_streak"),
		"opponent turns in between don't break it")
	tracker = AchievementTracker.new()
	tracker.on_round_start()
	tracker.on_play(_play([H, 5], [[C, 5]], true))
	tracker.on_play(_play([H, 13], [], false))
	assert_false(tracker.on_play(_play([D, 7], [[C, 7]], true)).has("basra_streak"))


func test_hat_trick_needs_three_in_one_round() -> void:
	tracker.on_play(_play([H, 5], [[C, 5]], true))
	tracker.on_play(_play([H, 13], [], false))
	tracker.on_play(_play([D, 6], [[C, 6]], true))
	tracker.on_round_start()
	assert_false(tracker.on_play(_play([D, 7], [[C, 7]], true)).has("hat_trick"))
	tracker.on_play(_play([H, 13], [], false))
	tracker.on_play(_play([D, 8], [[C, 8]], true))
	tracker.on_play(_play([H, 12], [], false))
	assert_true(tracker.on_play(_play([D, 9], [[C, 9]], true)).has("hat_trick"))


func test_big_haul_and_jack_sweeps() -> void:
	var six := [[C, 1], [C, 2], [C, 3], [C, 4], [C, 6], [C, 9]]
	var earned := tracker.on_play(_play([H, Card.JACK], six, false))
	assert_true(earned.has("big_haul"))
	assert_true(earned.has("clean_sweep"))
	assert_true(earned.has("broom"))


func test_small_jack_sweep_is_not_a_broom() -> void:
	var earned := tracker.on_play(_play([H, Card.JACK], [[C, 4], [S, 9]], false))
	assert_true(earned.has("clean_sweep"))
	assert_false(earned.has("broom"))


func test_jack_on_an_empty_table_is_not_a_sweep() -> void:
	assert_false(tracker.on_play(_play([H, Card.JACK], [], false)).has("clean_sweep"))


func test_mathematician_counts_only_summed_cards() -> void:
	assert_true(tracker.on_play(_play([H, 9], [[C, 2], [S, 3], [D, 4]], true)).has("mathematician"))
	tracker = AchievementTracker.new()
	assert_false(tracker.on_play(_play([H, 8], [[C, 8], [S, 2], [D, 6]], true)).has("mathematician"),
		"a matched 8 plus a 2+6 pair is only two summed cards")


func test_last_word_is_a_basra_with_the_final_card() -> void:
	assert_true(tracker.on_play(_play([H, 5], [[C, 5]], true, 0, true)).has("last_word"))


func test_opponent_plays_unlock_nothing() -> void:
	var six := [[C, 1], [C, 2], [C, 3], [C, 4], [C, 6], [C, 9]]
	assert_true(tracker.on_play(_play([H, Card.JACK], six, false, 1)).is_empty())
	assert_eq(tracker.stats.basras, 0)


func test_round_collections() -> void:
	var mine := [[C, 1], [D, 1], [H, 1], [S, 1], [D, 10], [C, 2], [S, 5]]
	var earned := tracker.on_round_end(_finished_round(mine, [[H, 9]]))
	assert_true(earned.has("four_aces"))
	assert_true(earned.has("big_two"))
	assert_true(earned.has("most_cards"))
	assert_true(earned.has("shutout"))
	assert_false(earned.has("four_jacks"))


func test_four_jacks() -> void:
	var mine := [[C, 11], [D, 11], [H, 11], [S, 11]]
	assert_true(tracker.on_round_end(_finished_round(mine, [[H, 9]])).has("four_jacks"))


func test_no_shutout_when_opponent_scores() -> void:
	var earned := tracker.on_round_end(_finished_round([[S, 5]], [[H, 1]]))
	assert_false(earned.has("shutout"))
	assert_false(earned.has("most_cards"), "1-1 is a tie")


func _won_match(rounds: int) -> BasraGame:
	var game := _finished_round([[S, 5]], [[H, 9]], [101, 60])
	game.winner = 0
	game.round_number = rounds
	return game


func test_match_win_achievements() -> void:
	var trailing := _finished_round([[S, 5]], [[H, 9]], [10, 70])
	tracker.on_round_end(trailing)
	var earned := tracker.on_match_end(_won_match(4))
	assert_true(earned.has("first_win"))
	assert_true(earned.has("comeback"))
	assert_true(earned.has("locked_down"))
	assert_true(earned.has("quick_finish"))
	assert_eq(tracker.stats.wins, 1)
	assert_eq(tracker.stats.matches, 1)


func test_opponent_basra_spoils_locked_down() -> void:
	tracker.on_play(_play([H, 5], [[C, 5]], true, 1))
	var earned := tracker.on_match_end(_won_match(8))
	assert_false(earned.has("locked_down"))
	assert_false(earned.has("quick_finish"))
	assert_false(earned.has("comeback"))


func test_new_match_resets_match_state() -> void:
	tracker.on_play(_play([H, 5], [[C, 5]], true, 1))
	tracker.on_match_start()
	assert_true(tracker.on_match_end(_won_match(8)).has("locked_down"))


func test_a_loss_counts_the_match_but_not_a_win() -> void:
	var game := _won_match(5)
	game.winner = 1
	assert_true(tracker.on_match_end(game).is_empty())
	assert_eq(tracker.stats.matches, 1)
	assert_eq(tracker.stats.wins, 0)


func test_lifetime_milestones() -> void:
	tracker.stats.basras = 24
	assert_true(tracker.on_play(_play([H, 5], [[C, 5]], true)).has("basra_regular"))
	tracker.stats.wins = 9
	assert_true(tracker.on_match_end(_won_match(8)).has("seasoned"))


func test_world_traveller() -> void:
	for i in 6:
		assert_true(tracker.on_felt_seen(i, 7).is_empty())
	assert_true(tracker.on_felt_seen(0, 7).is_empty(), "repeats don't count")
	assert_true(tracker.on_felt_seen(6, 7).has("world_traveller"))


func test_card_backs_unlock_with_their_achievements() -> void:
	assert_true(tracker.card_back_owned(0))
	assert_false(tracker.card_back_owned(1))
	assert_false(tracker.select_card_back(1))
	assert_eq(AchievementTracker.card_back_for("first_basra"), 1)
	tracker.on_play(_play([H, 5], [[C, 5]], true))
	assert_true(tracker.select_card_back(1))
	assert_eq(tracker.card_back, 1)


func test_every_card_back_unlock_is_a_real_achievement() -> void:
	for back: Dictionary in AchievementTracker.CARD_BACKS:
		if not (back.unlock as String).is_empty():
			assert_false(AchievementTracker.achievement(back.unlock).is_empty(), back.unlock)


func test_progress_saves_and_loads() -> void:
	tracker.on_play(_play([H, 5], [[C, 5]], true))
	tracker.on_felt_seen(3, 7)
	tracker.select_card_back(1)
	tracker.save_to(SAVE_PATH)
	var loaded := AchievementTracker.new()
	loaded.load_from(SAVE_PATH)
	assert_true(loaded.is_unlocked("first_basra"))
	assert_eq(loaded.stats.basras, 1)
	assert_eq(loaded.felts_seen, [3] as Array[int])
	assert_eq(loaded.card_back, 1)


func test_missing_save_file_starts_fresh() -> void:
	var loaded := AchievementTracker.new()
	loaded.load_from("user://does_not_exist.cfg")
	assert_true(loaded.unlocked.is_empty())
	assert_eq(loaded.card_back, 0)

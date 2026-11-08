@tool
class_name AchievementTracker
extends RefCounted
## Watches what happens in matches and unlocks achievements for the human
## player (team 0). Also keeps lifetime stats and the chosen card back, and
## saves all of it to a ConfigFile. Each on_* call returns the ids it unlocked.

const HUMAN_TEAM := 0

const BIG_HAUL_CARDS := 6
const BROOM_CARDS := 5
const SUM_CARDS := 3
const COMEBACK_DEFICIT := 50
const QUICK_FINISH_ROUNDS := 4
const REGULAR_BASRAS := 25
const LEGEND_BASRAS := 100
const SEASONED_WINS := 10

## In display order. Secret ones show as "???" until earned.
const ACHIEVEMENTS := [
	{"id": "first_basra", "name": "First Basra", "description": "Score your first Basra."},
	{"id": "first_win", "name": "Winner", "description": "Win a match."},
	{"id": "most_cards", "name": "Collector", "description": "Finish a round with the most cards."},
	{"id": "clean_sweep", "name": "Clean Sweep", "description": "Sweep the table with a jack."},
	{"id": "basra_streak", "name": "Back to Back", "description": "Score Basras on two of your turns in a row."},
	{"id": "hat_trick", "name": "Hat Trick", "description": "Score three Basras in one round."},
	{"id": "big_haul", "name": "Big Haul", "description": "Take 6 or more cards from the table in one play."},
	{"id": "broom", "name": "Broom", "description": "Sweep 5 or more cards with a jack."},
	{"id": "mathematician", "name": "Mathematician", "description": "Score a Basra by adding up 3 or more cards."},
	{"id": "four_aces", "name": "Ace Collector", "description": "Capture all four aces in one round."},
	{"id": "four_jacks", "name": "Jack of All Trades", "description": "Capture all four jacks in one round."},
	{"id": "big_two", "name": "The Big Two", "description": "Capture the 10 of diamonds and the 2 of clubs in one round."},
	{"id": "shutout", "name": "Shutout", "description": "Hold the opponent to 0 points in a round."},
	{"id": "comeback", "name": "Comeback", "description": "Win a match after trailing by 50 or more."},
	{"id": "locked_down", "name": "Locked Down", "description": "Win a match without the opponent scoring a Basra."},
	{"id": "quick_finish", "name": "Quick Finish", "description": "Win a match in 4 rounds or fewer."},
	{"id": "last_word", "name": "Last Word", "description": "Score a Basra with the last card of a round.", "secret": true},
	{"id": "basra_regular", "name": "Basra Regular", "description": "Score 25 Basras in total."},
	{"id": "seasoned", "name": "Seasoned", "description": "Win 10 matches."},
	{"id": "world_traveller", "name": "World Traveller", "description": "Play on every table color."},
	{"id": "basra_legend", "name": "Basra Legend", "description": "Score 100 Basras in total.", "secret": true},
]

## Index matches CardView's back styles. An empty unlock means always owned.
const CARD_BACKS := [
	{"name": "Star Mosaic", "unlock": ""},
	{"name": "Diamond Lattice", "unlock": "first_basra"},
	{"name": "Cedar", "unlock": "first_win"},
	{"name": "Midnight", "unlock": "basra_streak"},
	{"name": "Zellige", "unlock": "big_two"},
	{"name": "Gold", "unlock": "seasoned"},
]

var unlocked := {}
var stats := {"basras": 0, "wins": 0, "matches": 0}
var felts_seen: Array[int] = []
var card_back := 0

var _round_basras := 0
var _streak := 0
var _opponent_match_basras := 0
var _worst_deficit := 0


# --- Events ---------------------------------------------------------------------

func on_match_start() -> void:
	_opponent_match_basras = 0
	_worst_deficit = 0


func on_round_start() -> void:
	_round_basras = 0
	_streak = 0


## Call with each result BasraGame.play_card returns, for every player.
func on_play(result: Dictionary) -> Array[String]:
	var earned: Array[String] = []
	var captured: Array[Card] = result.captured
	if result.team != HUMAN_TEAM:
		if result.basra:
			_opponent_match_basras += 1
		return earned

	var card: Card = result.card
	if result.basra:
		stats.basras += 1
		_round_basras += 1
		_streak += 1
		_unlock("first_basra", earned)
		if _streak >= 2:
			_unlock("basra_streak", earned)
		if _round_basras >= 3:
			_unlock("hat_trick", earned)
		if result.round_over:
			_unlock("last_word", earned)
		var summed := captured.filter(func(taken: Card) -> bool: return taken.rank != card.rank)
		if summed.size() >= SUM_CARDS:
			_unlock("mathematician", earned)
		if stats.basras >= REGULAR_BASRAS:
			_unlock("basra_regular", earned)
		if stats.basras >= LEGEND_BASRAS:
			_unlock("basra_legend", earned)
	else:
		_streak = 0

	if captured.size() >= BIG_HAUL_CARDS:
		_unlock("big_haul", earned)
	if card.rank == Card.JACK and not captured.is_empty():
		_unlock("clean_sweep", earned)
		if captured.size() >= BROOM_CARDS:
			_unlock("broom", earned)
	return earned


## Call once the round is scored (game.last_round_result is filled in).
func on_round_end(game: BasraGame) -> Array[String]:
	var earned: Array[String] = []
	var mine: Dictionary = game.last_round_result[HUMAN_TEAM]
	var theirs: Dictionary = game.last_round_result[1 - HUMAN_TEAM]
	var pile: Array = game.piles[HUMAN_TEAM]

	if mine.majority > 0:
		_unlock("most_cards", earned)
	if theirs.total == 0:
		_unlock("shutout", earned)
	if _count(pile, func(card: Card) -> bool: return card.rank == Card.ACE) == 4:
		_unlock("four_aces", earned)
	if _count(pile, func(card: Card) -> bool: return card.rank == Card.JACK) == 4:
		_unlock("four_jacks", earned)
	if mine.ten_of_diamonds > 0 and mine.two_of_clubs > 0:
		_unlock("big_two", earned)

	var deficit: int = game.scores[1 - HUMAN_TEAM] - game.scores[HUMAN_TEAM]
	_worst_deficit = maxi(_worst_deficit, deficit)
	return earned


## Call when a match has a winner, after on_round_end for its last round.
func on_match_end(game: BasraGame) -> Array[String]:
	var earned: Array[String] = []
	stats.matches += 1
	if game.winner != HUMAN_TEAM:
		return earned
	stats.wins += 1
	_unlock("first_win", earned)
	if _worst_deficit >= COMEBACK_DEFICIT:
		_unlock("comeback", earned)
	if _opponent_match_basras == 0:
		_unlock("locked_down", earned)
	if game.round_number <= QUICK_FINISH_ROUNDS:
		_unlock("quick_finish", earned)
	if stats.wins >= SEASONED_WINS:
		_unlock("seasoned", earned)
	return earned


func on_felt_seen(index: int, palette_count: int) -> Array[String]:
	var earned: Array[String] = []
	if index not in felts_seen:
		felts_seen.append(index)
	if felts_seen.size() >= palette_count:
		_unlock("world_traveller", earned)
	return earned


# --- Queries ----------------------------------------------------------------------

static func achievement(id: String) -> Dictionary:
	for entry: Dictionary in ACHIEVEMENTS:
		if entry.id == id:
			return entry
	return {}


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


func card_back_owned(index: int) -> bool:
	var unlock: String = CARD_BACKS[index].unlock
	return unlock.is_empty() or is_unlocked(unlock)


## The card back an achievement unlocks, or -1.
static func card_back_for(id: String) -> int:
	for i in CARD_BACKS.size():
		if CARD_BACKS[i].unlock == id:
			return i
	return -1


func select_card_back(index: int) -> bool:
	if not card_back_owned(index):
		return false
	card_back = index
	return true


# --- Saving -----------------------------------------------------------------------

func save_to(path: String) -> void:
	var config := ConfigFile.new()
	config.set_value("achievements", "unlocked", unlocked.keys())
	config.set_value("stats", "values", stats)
	config.set_value("stats", "felts_seen", felts_seen)
	config.set_value("cosmetics", "card_back", card_back)
	config.save(path)


func load_from(path: String) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	unlocked.clear()
	for id: String in config.get_value("achievements", "unlocked", []):
		unlocked[id] = true
	var saved_stats: Dictionary = config.get_value("stats", "values", {})
	for key: String in stats:
		stats[key] = int(saved_stats.get(key, 0))
	felts_seen.assign(config.get_value("stats", "felts_seen", []))
	card_back = int(config.get_value("cosmetics", "card_back", 0))
	if card_back < 0 or card_back >= CARD_BACKS.size() or not card_back_owned(card_back):
		card_back = 0


func _unlock(id: String, earned: Array[String]) -> void:
	if not unlocked.has(id):
		unlocked[id] = true
		earned.append(id)


func _count(cards: Array, matches: Callable) -> int:
	return cards.filter(matches).size()

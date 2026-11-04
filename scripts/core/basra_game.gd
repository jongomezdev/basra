@tool
class_name BasraGame
extends RefCounted
## State of a whole match: deals, turns, captures and the running score.
## Works for 2 players, or 4 in partnerships (seats 0+2 against 1+3).

enum Phase { PLAYING, ROUND_OVER, MATCH_OVER }

const TEAM_COUNT := 2

var player_count := 2
var phase := Phase.ROUND_OVER
var round_number := 0
var dealer := 0
var current_player := 0
var deck: Array[Card] = []
var table: Array[Card] = []
var hands: Array = []
var piles: Array = []
var basras: Array = []
var scores: Array = []
var last_capture_team := -1
var last_round_result: Array[Dictionary] = []
var winner := -1

var _rng := RandomNumberGenerator.new()


func start_match(players: int = 2, rng_seed: int = 0) -> void:
	assert(players == 2 or players == 4, "Basra is played by 2 or 4 players")
	player_count = players
	_rng.seed = rng_seed
	scores = [0, 0]
	round_number = 0
	winner = -1
	dealer = _rng.randi_range(0, players - 1)
	start_round()


## Deals a fresh round. The deal passes on each round after the first.
func start_round() -> void:
	if round_number > 0:
		dealer = (dealer + 1) % player_count
	round_number += 1
	phase = Phase.PLAYING
	deck = _shuffled_deck()
	table = []
	piles = []
	basras = [0, 0]
	last_capture_team = -1
	last_round_result = []
	for team in TEAM_COUNT:
		var pile: Array[Card] = []
		piles.append(pile)
	hands = []
	for player in player_count:
		var hand: Array[Card] = []
		hands.append(hand)
	for i in BasraRules.TABLE_DEAL:
		table.append(deck.pop_back())
	_deal_hands()
	current_player = (dealer + 1) % player_count


func team_of(player: int) -> int:
	return player % TEAM_COUNT


## Plays a card from the player's hand and advances the game. The returned
## dictionary describes what happened, for the UI to animate. Returns an empty
## dictionary if the move is not legal.
func play_card(player: int, hand_index: int) -> Dictionary:
	if phase != Phase.PLAYING or player != current_player:
		return {}
	var hand: Array[Card] = hands[player]
	if hand_index < 0 or hand_index >= hand.size():
		return {}

	var card: Card = hand[hand_index]
	var captured := BasraRules.capture_for(card, table)
	var basra := BasraRules.is_basra(card, table)
	var team := team_of(player)
	hand.remove_at(hand_index)

	if captured.is_empty():
		table.append(card)
	else:
		for taken in captured:
			table.erase(taken)
		var pile: Array[Card] = piles[team]
		pile.append_array(captured)
		pile.append(card)
		last_capture_team = team
		if basra:
			basras[team] += 1

	var result := {
		"player": player,
		"team": team,
		"card": card,
		"captured": captured,
		"basra": basra,
		"dealt": false,
		"leftovers": [] as Array[Card],
		"round_over": false,
	}

	current_player = (player + 1) % player_count
	if _hands_empty():
		if deck.is_empty():
			result.leftovers = _finish_round()
			result.round_over = true
		else:
			_deal_hands()
			result.dealt = true
	return result


func _deal_hands() -> void:
	for i in BasraRules.HAND_SIZE:
		for player in player_count:
			var hand: Array[Card] = hands[player]
			hand.append(deck.pop_back())


func _hands_empty() -> bool:
	for hand: Array in hands:
		if not hand.is_empty():
			return false
	return true


func _finish_round() -> Array[Card]:
	var leftovers: Array[Card] = table.duplicate()
	if last_capture_team >= 0:
		var pile: Array[Card] = piles[last_capture_team]
		pile.append_array(leftovers)
		table.clear()

	last_round_result = BasraRules.score_round(piles, basras)
	for team in TEAM_COUNT:
		scores[team] += last_round_result[team].total

	phase = Phase.ROUND_OVER
	var someone_reached_target: bool = scores.max() >= BasraRules.TARGET_SCORE
	if someone_reached_target and scores[0] != scores[1]:
		winner = 0 if scores[0] > scores[1] else 1
		phase = Phase.MATCH_OVER
	return leftovers


func _shuffled_deck() -> Array[Card]:
	var cards: Array[Card] = []
	for suit in Card.Suit.values():
		for rank in range(Card.ACE, Card.KING + 1):
			cards.append(Card.new(suit, rank))
	for i in range(cards.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := cards[i]
		cards[i] = cards[j]
		cards[j] = swap
	return cards

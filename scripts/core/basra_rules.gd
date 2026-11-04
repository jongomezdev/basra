@tool
class_name BasraRules
extends RefCounted
## Pure rules for the Lebanese variant: what a card captures and what a round
## scores. Nothing here touches game state or the scene tree.

const TARGET_SCORE := 101
const TABLE_DEAL := 4
const HAND_SIZE := 6

const TEN_OF_DIAMONDS_POINTS := 3
const TWO_OF_CLUBS_POINTS := 2
const ACE_POINTS := 1
const JACK_POINTS := 1
const MAJORITY_POINTS := 3
const BASRA_POINTS := 10


## Jacks and the 7 of diamonds clear the whole table.
static func is_sweeper(card: Card) -> bool:
	return card.rank == Card.JACK or (card.rank == 7 and card.suit == Card.Suit.DIAMONDS)


## Every table card this card takes. Capturing is mandatory, so this is also
## what will happen if the card is played. An empty result means it is laid down.
static func capture_for(card: Card, table: Array[Card]) -> Array[Card]:
	var captured: Array[Card] = []
	if is_sweeper(card):
		captured.assign(table)
		return captured

	for table_card in table:
		if table_card.rank == card.rank:
			captured.append(table_card)
	if not card.is_number():
		return captured

	# Sum groups only use cards lower than the played card, so they can never
	# overlap the same-rank matches taken above.
	var pool: Array[Card] = []
	for table_card in table:
		if table_card.is_number() and table_card.rank < card.rank:
			pool.append(table_card)

	var groups: Array[int] = []
	_collect_sum_groups(pool, 0, card.rank, 0, groups)
	var best_mask := _best_packing(pool, groups, 0, 0)
	for i in pool.size():
		if best_mask & (1 << i):
			captured.append(pool[i])
	return captured


## A Basra is taking a single lone table card by matching it, without a sweeper.
static func is_basra(card: Card, table: Array[Card]) -> bool:
	return table.size() == 1 and not is_sweeper(card) and table[0].rank == card.rank


## Points a card is worth in a capture pile, before majority and Basra bonuses.
static func card_points(card: Card) -> int:
	if card.rank == 10 and card.suit == Card.Suit.DIAMONDS:
		return TEN_OF_DIAMONDS_POINTS
	if card.rank == 2 and card.suit == Card.Suit.CLUBS:
		return TWO_OF_CLUBS_POINTS
	if card.rank == Card.ACE:
		return ACE_POINTS
	if card.rank == Card.JACK:
		return JACK_POINTS
	return 0


## Breakdown per team. piles[team] is that team's captured cards and
## basras[team] its Basra count. A tie for most cards awards nobody the bonus.
static func score_round(piles: Array, basras: Array) -> Array[Dictionary]:
	var most_cards := 0
	var leaders := 0
	for pile: Array in piles:
		if pile.size() > most_cards:
			most_cards = pile.size()
			leaders = 1
		elif pile.size() == most_cards:
			leaders += 1

	var results: Array[Dictionary] = []
	for team in piles.size():
		var pile: Array = piles[team]
		var result := {
			"cards": pile.size(),
			"ten_of_diamonds": 0,
			"two_of_clubs": 0,
			"aces": 0,
			"jacks": 0,
			"majority": 0,
			"basras": basras[team],
			"basra_points": basras[team] * BASRA_POINTS,
		}
		for card: Card in pile:
			var points := card_points(card)
			if card.rank == Card.ACE:
				result.aces += points
			elif card.rank == Card.JACK:
				result.jacks += points
			elif card.rank == 10:
				result.ten_of_diamonds += points
			elif card.rank == 2:
				result.two_of_clubs += points
		if leaders == 1 and most_cards > 0 and pile.size() == most_cards:
			result.majority = MAJORITY_POINTS
		result["total"] = (
			result.ten_of_diamonds + result.two_of_clubs + result.aces + result.jacks
			+ result.majority + result.basra_points
		)
		results.append(result)
	return results


static func _collect_sum_groups(
	pool: Array[Card], start: int, remaining: int, mask: int, out: Array[int]
) -> void:
	if remaining == 0:
		out.append(mask)
		return
	for i in range(start, pool.size()):
		if pool[i].rank <= remaining:
			_collect_sum_groups(pool, i + 1, remaining - pool[i].rank, mask | (1 << i), out)


## Picks the non-overlapping groups that take the most cards, breaking ties in
## favour of the most points.
static func _best_packing(pool: Array[Card], groups: Array[int], start: int, used: int) -> int:
	var best := 0
	for i in range(start, groups.size()):
		if groups[i] & used:
			continue
		var candidate := groups[i] | _best_packing(pool, groups, i + 1, used | groups[i])
		if _mask_value(pool, candidate) > _mask_value(pool, best):
			best = candidate
	return best


static func _mask_value(pool: Array[Card], mask: int) -> int:
	var value := 0
	for i in pool.size():
		if mask & (1 << i):
			value += 100 + card_points(pool[i])
	return value

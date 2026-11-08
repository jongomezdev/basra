@tool
class_name BasraAI
extends RefCounted
## Greedy opponent: scores each card in hand by what it takes now and what it
## leaves on the table for the next player.

## Penalty for leaving a table the next player could clear for a Basra.
const BASRA_RISK := 3.0
const SWEEPER_COST := 2.0
const EMPTY_TABLE_BONUS := 1.0
const CARD_VALUE := 0.25


static func choose_card(hand: Array[Card], table: Array[Card]) -> int:
	var best_index := 0
	var best_value := -INF
	for i in hand.size():
		var value := _evaluate(hand[i], table)
		if value > best_value:
			best_value = value
			best_index = i
	return best_index


static func _evaluate(card: Card, table: Array[Card]) -> float:
	var captured := BasraRules.capture_for(card, table)
	if captured.is_empty():
		return _evaluate_discard(card, table)

	var value := BasraRules.card_points(card) + (captured.size() + 1) * CARD_VALUE
	for taken in captured:
		value += BasraRules.card_points(taken)
	if BasraRules.is_basra(card, table):
		value += BasraRules.BASRA_POINTS
	if BasraRules.is_sweeper(card):
		value -= SWEEPER_COST

	var left_behind: Array[Card] = []
	for table_card in table:
		if table_card not in captured:
			left_behind.append(table_card)
	if left_behind.is_empty():
		value += EMPTY_TABLE_BONUS
	elif BasraRules.can_be_cleared(left_behind):
		value -= BASRA_RISK
	return value


## Laying a card down hands it to the opponent, so anything worth points is
## costly. Queens and kings are the safest: they can only be taken by rank.
static func _evaluate_discard(card: Card, table: Array[Card]) -> float:
	var value := -3.0 * BasraRules.card_points(card)
	if BasraRules.is_sweeper(card):
		value -= SWEEPER_COST * 3.0
	if not card.is_number():
		value += 0.5
	var after: Array[Card] = table.duplicate()
	after.append(card)
	if BasraRules.can_be_cleared(after):
		value -= BASRA_RISK
	return value

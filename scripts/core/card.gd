@tool
class_name Card
extends RefCounted
## One playing card. Ranks run 1 (Ace) to 13 (King).

enum Suit { CLUBS, DIAMONDS, HEARTS, SPADES }

const ACE := 1
const JACK := 11
const QUEEN := 12
const KING := 13

const RANK_NAMES := {1: "A", 11: "J", 12: "Q", 13: "K"}
const SUIT_NAMES := ["clubs", "diamonds", "hearts", "spades"]

var suit: Suit
var rank: int


func _init(card_suit: Suit, card_rank: int) -> void:
	suit = card_suit
	rank = card_rank


## Aces and 2-10 have a numeric value; J, Q and K can never be part of a sum.
func is_number() -> bool:
	return rank <= 10


func is_red() -> bool:
	return suit == Suit.DIAMONDS or suit == Suit.HEARTS


func rank_text() -> String:
	return RANK_NAMES.get(rank, str(rank))


func describe() -> String:
	return "%s of %s" % [rank_text(), SUIT_NAMES[suit]]

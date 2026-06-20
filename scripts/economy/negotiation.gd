class_name Negotiation
extends RefCounted
## A deterministic, stateful haggle session with one BuyerPersona.
##
## This is the offline negotiation path that the exhibit build always has (PRD
## MKT-R7 / Invariant §4-O): no RNG and no network, so the same inputs always
## produce the same buyer behaviour and tests are stable. The buyer opens with an
## offer below its private ceiling, the player accepts it or counters with an asking
## price, and the buyer concedes toward the ceiling, accepts a reachable ask, or —
## once out of patience — walks away. The later LLM `/api/negotiate` proxy can swap
## in behind the same accept()/counter() surface.
##
## Achievable price rises with restoration condition and a preferred category
## (MKT-R2). The ceiling is clamped to the persona's budget, so a low-budget buyer
## simply cannot pay collector money.

var persona: BuyerPersona
var base_value: int = 0
var condition: int = 0  ## 0..100 restoration condition.
var honest: bool = true
var category: String = ""

var ceiling: int = 0  ## The most this buyer will ever pay (private).
var current_offer: int = 0  ## The buyer's standing offer.
var round_index: int = 0
var patience_left: int = 0
var closed: bool = false
var walked: bool = false
var final_price: int = 0
var history: Array = []  ## [{role: "buyer"|"player", text: String, offer: int}]


## Opens a fresh session and computes the buyer's opening offer + line.
static func open(
	buyer: BuyerPersona, item_value: int, item_condition: int, item_category: String, is_honest: bool = true
) -> Negotiation:
	var n := Negotiation.new()
	n.persona = buyer
	n.base_value = maxi(0, item_value)
	n.condition = clampi(item_condition, 0, 100)
	n.category = item_category
	n.honest = is_honest
	n.patience_left = buyer.patience
	n.ceiling = n._compute_ceiling()
	n.current_offer = clampi(int(round(n.ceiling * buyer.open_factor)), 1, maxi(1, n.ceiling))
	n._say_buyer("open", n.current_offer)
	return n


## The buyer's private maximum, from value, restoration condition, category fit, and
## honesty, clamped to its budget. Public so the service/UI can show a fair hint.
func _compute_ceiling() -> int:
	var c := float(condition) / 100.0
	# Condition swings the price around the base value by ±condition_weight.
	var condition_mult := lerpf(1.0 - persona.condition_weight, 1.0 + persona.condition_weight * 0.25, c)
	var category_mult := 1.0 + persona.category_bonus if persona.likes_category(category) else 1.0
	var honesty_mult := 1.0 if honest else 0.75
	var raw := float(base_value) * condition_mult * category_mult * honesty_mult
	return clampi(int(round(raw)), 1, maxi(1, persona.budget_range.y))


## Player accepts the buyer's standing offer. Returns the agreed price.
func accept() -> int:
	if closed:
		return final_price
	final_price = current_offer
	closed = true
	_say_buyer("accept", final_price)
	return final_price


## Player walks away — no sale.
func decline() -> void:
	if closed:
		return
	closed = true
	walked = true


## Player counters, asking `player_price`. The buyer accepts a reachable ask, raises
## its offer toward the ceiling, or walks once patience runs out. Returns
## {accepted: bool, walked: bool, offer: int, message: String}.
func counter(player_price: int) -> Dictionary:
	if closed:
		return _result()
	round_index += 1
	_say_player(player_price)

	# Asking at or below the standing offer: the buyer happily takes the cheaper deal.
	if player_price <= current_offer:
		final_price = player_price
		current_offer = player_price
		closed = true
		_say_buyer("accept", final_price)
		return _result()

	# Concede toward the ceiling.
	var step := maxi(1, int(round(float(ceiling - current_offer) * persona.concession_rate)))
	var raised := mini(ceiling, current_offer + step)

	# A reachable ask (within what the buyer would now pay) closes the deal.
	if player_price <= raised:
		current_offer = player_price
		final_price = player_price
		closed = true
		_say_buyer("accept", final_price)
		return _result()

	# Still apart. The buyer raises its offer; greed (asking above the ceiling) and a
	# maxed-out offer both cost patience.
	current_offer = raised
	if player_price > ceiling:
		patience_left -= 1
	if patience_left <= 0:
		closed = true
		walked = true
		_say_buyer("walk", current_offer)
		return _result()
	_say_buyer("counter", current_offer)
	return _result()


func is_closed() -> bool:
	return closed


func _result() -> Dictionary:
	return {
		"accepted": closed and not walked,
		"walked": walked,
		"offer": current_offer,
		"price": final_price,
		"message": history.back()["text"] if not history.is_empty() else "",
	}


func _say_buyer(phase: String, offer: int) -> void:
	history.append({"role": "buyer", "text": persona.line(phase, offer, round_index), "offer": offer})


func _say_player(price: int) -> void:
	history.append({"role": "player", "text": "How about ₱%d?" % price, "offer": price})

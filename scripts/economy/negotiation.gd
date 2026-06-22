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
## Hard cap from the buyer's remaining wallet — they can never offer more than they have.
## Effectively unlimited for Mr. Maverick.
var cash_cap: int = 1 << 30
var current_offer: int = 0  ## The buyer's standing offer.
var round_index: int = 0
var patience_left: int = 0
var closed: bool = false
var walked: bool = false
var final_price: int = 0
var history: Array = []  ## [{role: "buyer"|"player", text: String, offer: int}]

## Conversational banter (MKT-R2): chat moves that shift the buyer's mood, which
## scales the ceiling up or down before the numeric haggle. `mood` is a multiplier
## delta; each move is usable once. Reactions are persona-specific (a reseller warms
## to "press hard"; a sentimental buyer is put off by it). This is the OFFLINE banter;
## the later LLM proxy generates richer replies behind the same banter() surface.
var mood: float = 0.0
var used_moves: Array[String] = []
## Set when the player's free-text message was offensive/NSFW: the buyer is disgusted,
## walks, and should be ghosted (never offered this item again).
var offended: bool = false

## Friendly words that warm a buyer a touch on free-text banter.
const _FRIENDLY_WORDS := [
	"please",
	"thank",
	"thanks",
	"sorry",
	"nice",
	"beautiful",
	"lovely",
	"story",
	"history",
	"heritage",
	"family",
	"appreciate",
	"care",
	"deal",
	"fair",
]
const _OFFENDED_LINE := "Excuse me? That's vile — we're done here. Don't message me again."

## move id -> {label (player button), say (player utterance)}.
const BANTER_MOVES := {
	"history": {"label": "Talk up its history", "say": "This piece has real history behind it."},
	"honest": {"label": "Be honest about flaws", "say": "I'll be straight with you about its condition."},
	"charm": {"label": "Charm them", "say": "For someone with your eye, it's perfect."},
	"press": {"label": "Press hard", "say": "Come on — it's worth far more than that."},
}

## negotiation_style -> per-move mood delta. Favourable moves warm the buyer (raise the
## ceiling); off-putting ones cool them. Unknown styles use DEFAULT_BIAS.
const BANTER_BIAS := {
	"appraising": {"history": 0.10, "honest": 0.06, "charm": 0.05, "press": -0.07},
	"aggressive": {"history": -0.05, "honest": 0.05, "charm": -0.05, "press": 0.10},
	"earnest": {"history": 0.03, "honest": 0.07, "charm": 0.08, "press": -0.06},
	"sentimental": {"history": 0.08, "honest": 0.06, "charm": 0.12, "press": -0.10},
	"exacting": {"history": 0.07, "honest": 0.08, "charm": -0.04, "press": 0.0},
	"guarded": {"history": 0.08, "honest": 0.02, "charm": 0.02, "press": -0.06},
}
const DEFAULT_BIAS := {"history": 0.03, "honest": 0.05, "charm": 0.03, "press": -0.02}
const MOOD_MIN := -0.25
const MOOD_MAX := 0.3


## Opens a fresh session and computes the buyer's opening offer + line.
static func open(
	buyer: BuyerPersona,
	item_value: int,
	item_condition: int,
	item_category: String,
	is_honest: bool = true,
	max_cash: int = 1 << 30
) -> Negotiation:
	var n := Negotiation.new()
	n.persona = buyer
	n.base_value = maxi(0, item_value)
	n.condition = clampi(item_condition, 0, 100)
	n.category = item_category
	n.honest = is_honest
	n.cash_cap = maxi(1, max_cash)
	n.patience_left = buyer.patience
	n._recompute_ceiling()
	n.current_offer = clampi(int(round(n.ceiling * buyer.open_factor)), 1, maxi(1, n.ceiling))
	n._say_buyer("open", n.current_offer)
	return n


## The buyer's private maximum before mood, from value, restoration condition,
## category fit, and honesty (no budget clamp).
func _raw_ceiling() -> float:
	var c := float(condition) / 100.0
	# Condition swings the price around the base value by ±condition_weight.
	var condition_mult := lerpf(1.0 - persona.condition_weight, 1.0 + persona.condition_weight * 0.25, c)
	var category_mult := 1.0 + persona.category_bonus if persona.likes_category(category) else 1.0
	var honesty_mult := 1.0 if honest else 0.75
	return float(base_value) * condition_mult * category_mult * honesty_mult


## Applies mood to the raw ceiling and clamps to the persona's budget AND their remaining
## cash — a buyer simply cannot offer more than they can afford.
func _recompute_ceiling() -> void:
	var cap := mini(maxi(1, persona.budget_range.y), maxi(1, cash_cap))
	ceiling = clampi(int(round(_raw_ceiling() * (1.0 + mood))), 1, cap)


# --- Conversational banter ---------------------------------------------------


## Banter moves the player hasn't used yet (for the haggle UI).
func available_moves() -> Array[String]:
	var out: Array[String] = []
	for move_id in BANTER_MOVES.keys():
		if not used_moves.has(move_id):
			out.append(move_id)
	return out


## Plays one banter move: shifts the buyer's mood (persona-specific), re-derives the
## ceiling/standing offer, and records the exchange. Each move is usable once and does
## not close the deal. Returns the standard result dict (with the buyer's reply).
func banter(move_id: String) -> Dictionary:
	if closed or not BANTER_MOVES.has(move_id) or used_moves.has(move_id):
		return _result()
	used_moves.append(move_id)
	if move_id == "honest":
		honest = true  # coming clean removes any misrepresentation penalty
	history.append(
		{"role": "player", "text": str(BANTER_MOVES[move_id]["say"]), "offer": current_offer}
	)
	# A robotic / all-business buyer is unmoved by banter — their price never shifts.
	var delta := 0.0 if persona.ignores_banter else _banter_delta(move_id)
	mood = clampf(mood + delta, MOOD_MIN, MOOD_MAX)
	_recompute_ceiling()
	# A warmer mood can lift the standing offer; a colder one caps it to the ceiling.
	var warmed := int(round(ceiling * persona.open_factor))
	current_offer = clampi(maxi(current_offer, warmed), 1, maxi(1, ceiling))
	var phase := "banter_warm" if delta >= 0.0 else "banter_cool"
	history.append(
		{"role": "buyer", "text": persona.line(phase, current_offer, used_moves.size()), "offer": current_offer}
	)
	return _result()


func _banter_delta(move_id: String) -> float:
	var bias: Dictionary = BANTER_BIAS.get(persona.negotiation_style, DEFAULT_BIAS)
	return float(bias.get(move_id, 0.0))


## Free-text banter: the player types anything. Offensive/NSFW input disgusts the
## buyer — they get angry, the deal closes (walked), and `offended` is set so the
## caller can ghost them. Friendly, on-topic chat warms the mood a little; anything
## else nudges it slightly. Returns the standard result dict.
func chat(text: String) -> Dictionary:
	if closed:
		return _result()
	history.append({"role": "player", "text": text, "offer": current_offer})
	if ContentModeration.is_inappropriate(text):
		offended = true
		walked = true
		closed = true
		mood = MOOD_MIN
		_recompute_ceiling()
		history.append({"role": "buyer", "text": _OFFENDED_LINE, "offer": 0})
		return _result()
	var delta := 0.16 if _sounds_friendly(text) else 0.04
	mood = clampf(mood + delta, MOOD_MIN, MOOD_MAX)
	_recompute_ceiling()
	var warmed := int(round(ceiling * persona.open_factor))
	current_offer = clampi(maxi(current_offer, warmed), 1, maxi(1, ceiling))
	# A varied, topic-aware offline reply (the LLM upgrades it online) so the buyer
	# doesn't just repeat two canned lines.
	history.append(
		{"role": "buyer", "text": BanterBot.reply(text), "offer": current_offer}
	)
	return _result()


func _sounds_friendly(text: String) -> bool:
	var lower := text.to_lower()
	for word in _FRIENDLY_WORDS:
		if lower.contains(word):
			return true
	return false


## Closes the deal as offended/walked after the fact — used when the AI's contextual
## moderation flags a message the keyword filter let through (e.g. being hit on). The
## buyer's reaction line is appended by the caller.
func force_offended() -> void:
	if closed:
		return
	offended = true
	walked = true
	closed = true
	mood = MOOD_MIN
	_recompute_ceiling()


# --- Free-text driven haggle (price + reply come from one typed message) ---------


## Deterministic fallback decision for a price the player named in free text (used when
## no on-device AI is loaded). PURE: mutates nothing and NEVER closes the sale — only the
## Accept button finalizes. Returns {agreed, counter}: `agreed` = the buyer would pay the
## seller's price; otherwise `counter` is the peso amount the buyer offers instead.
func propose_price(player_price: int) -> Dictionary:
	if player_price <= current_offer:
		return {"agreed": true, "counter": player_price}
	var step := maxi(1, int(round(float(ceiling - current_offer) * persona.concession_rate)))
	var reach := mini(ceiling, current_offer + step)
	if player_price <= reach:
		return {"agreed": true, "counter": player_price}
	return {"agreed": false, "counter": reach}


## Moves the standing offer to the haggled price WITHOUT closing the sale (only accept()
## via the Accept button finalizes). `agreed` = the buyer takes the seller's price;
## otherwise `counter_price` (the buyer's number, e.g. from the AI's reply) becomes the
## offer, clamped to a sane range.
## The buyer never pays above `ceiling` (value + condition + mood, capped by their wallet),
## so an unreasonable ask is silently capped — this is what stops a buyer from agreeing to
## pay far above an item's worth just because the seller asserts it.
func set_offer_from_haggle(agreed: bool, seller_price: int, counter_price: int) -> void:
	if closed:
		return
	if agreed:
		current_offer = clampi(seller_price, 1, ceiling)
	elif counter_price > 0:
		current_offer = clampi(counter_price, 1, mini(maxi(1, seller_price), ceiling))


## Mood-only banter (no price): warms/cools the buyer and may nudge the standing offer.
## No dialogue line is added — the caller appends the AI/offline reply.
func banter_mood_only(text: String) -> void:
	if closed or persona.ignores_banter:
		return  # robotic buyers don't warm to anything the seller says
	var delta := 0.16 if _sounds_friendly(text) else 0.04
	mood = clampf(mood + delta, MOOD_MIN, MOOD_MAX)
	_recompute_ceiling()
	var warmed := int(round(ceiling * persona.open_factor))
	current_offer = clampi(maxi(current_offer, warmed), 1, maxi(1, ceiling))


func add_player_line(text: String) -> void:
	history.append({"role": "player", "text": text, "offer": current_offer})


func add_buyer_line(text: String) -> void:
	history.append({"role": "buyer", "text": text, "offer": current_offer})


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
		"offended": offended,
		"offer": current_offer,
		"price": final_price,
		"mood": mood,
		"message": history.back()["text"] if not history.is_empty() else "",
	}


func _say_buyer(phase: String, offer: int) -> void:
	history.append({"role": "buyer", "text": persona.line(phase, offer, round_index), "offer": offer})


func _say_player(price: int) -> void:
	history.append({"role": "player", "text": "How about ₱%d?" % price, "offer": price})

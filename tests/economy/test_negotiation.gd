extends GutTest
## The deterministic haggle engine: opening offers, accepting, countering, walking,
## and how condition / preferred category / budget move the buyer's private ceiling.

func _persona(overrides: Dictionary = {}) -> BuyerPersona:
	var base := {
		"id": "t",
		"display_name": "Test Buyer",
		"budget_range": [10, 1000],
		"open_factor": 0.5,
		"concession_rate": 0.3,
		"patience": 2,
		"category_bonus": 0.2,
		"condition_weight": 0.4,
		"preferred_categories": ["jewelry"],
		"lines": {"open": ["₱{offer}"], "counter": ["₱{offer}"], "accept": ["ok"], "walk": ["no"]},
	}
	for key in overrides:
		base[key] = overrides[key]
	return BuyerPersona.from_dictionary(base)


func test_open_offers_below_the_ceiling_with_a_line() -> void:
	var n := Negotiation.open(_persona(), 200, 100, "metal")
	assert_gt(n.ceiling, 0)
	assert_lt(n.current_offer, n.ceiling, "open_factor 0.5 opens below the ceiling")
	assert_eq(n.history.size(), 1, "the buyer's opening line is recorded")


func test_accept_returns_standing_offer_and_closes() -> void:
	var n := Negotiation.open(_persona(), 200, 100, "metal")
	var price := n.accept()
	assert_eq(price, n.current_offer)
	assert_true(n.is_closed())
	assert_false(n.walked)


func test_asking_below_the_offer_takes_the_cheaper_deal() -> void:
	var n := Negotiation.open(_persona(), 200, 100, "metal")
	var low := n.current_offer - 1
	var result := n.counter(low)
	assert_true(result.accepted)
	assert_eq(n.final_price, low)


func test_reachable_ask_closes_the_deal() -> void:
	# concession_rate 1.0 lets the buyer jump straight to its ceiling.
	var n := Negotiation.open(_persona({"concession_rate": 1.0}), 200, 100, "metal")
	var result := n.counter(n.ceiling)
	assert_true(result.accepted)
	assert_eq(n.final_price, n.ceiling)


func test_repeated_greedy_asks_make_the_buyer_walk() -> void:
	var n := Negotiation.open(_persona({"patience": 2}), 200, 100, "metal")
	var greedy := n.ceiling * 5
	n.counter(greedy)
	var result := n.counter(greedy)
	assert_true(result.walked)
	assert_true(n.is_closed())
	assert_eq(n.final_price, 0, "a walk means no sale")


func test_better_condition_raises_the_ceiling() -> void:
	var poor := Negotiation.open(_persona(), 200, 0, "metal")
	var pristine := Negotiation.open(_persona(), 200, 100, "metal")
	assert_gt(pristine.ceiling, poor.ceiling)


func test_preferred_category_raises_the_ceiling() -> void:
	var plain := Negotiation.open(_persona(), 200, 100, "metal")
	var liked := Negotiation.open(_persona(), 200, 100, "jewelry")
	assert_gt(liked.ceiling, plain.ceiling)


func test_budget_clamps_the_ceiling() -> void:
	var n := Negotiation.open(_persona({"budget_range": [10, 50]}), 1000, 100, "jewelry")
	assert_eq(n.ceiling, 50, "a buyer never pays past its budget")


# --- Conversational banter ---------------------------------------------------


func test_favorable_banter_raises_the_ceiling() -> void:
	var n := Negotiation.open(_persona({"negotiation_style": "appraising"}), 200, 100, "metal")
	var before := n.ceiling
	n.banter("history")  # an appraiser warms to provenance
	assert_gt(n.ceiling, before)


func test_offputting_banter_lowers_the_ceiling() -> void:
	var n := Negotiation.open(_persona({"negotiation_style": "sentimental"}), 200, 100, "metal")
	var before := n.ceiling
	n.banter("press")  # a sentimental buyer is put off by pressure
	assert_lt(n.ceiling, before)


func test_a_banter_move_is_usable_once() -> void:
	var n := Negotiation.open(_persona({"negotiation_style": "appraising"}), 200, 100, "metal")
	n.banter("history")
	var mood_after := n.mood
	n.banter("history")  # second time is a no-op
	assert_eq(n.mood, mood_after)
	assert_false(n.available_moves().has("history"))


func test_honest_banter_recovers_a_misrepresentation_penalty() -> void:
	var n := Negotiation.open(_persona({"negotiation_style": "exacting"}), 200, 100, "metal", false)
	var before := n.ceiling
	n.banter("honest")
	assert_true(n.honest, "coming clean sets the deal honest")
	assert_gt(n.ceiling, before)


func test_banter_records_the_exchange() -> void:
	var n := Negotiation.open(_persona(), 200, 100, "metal")
	var before := n.history.size()
	n.banter("history")
	assert_eq(n.history.size(), before + 2, "the player's line and the buyer's reply")

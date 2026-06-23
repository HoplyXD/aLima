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


# --- free-text price haggling (decision + offer; never closes on its own) ----


func test_propose_reachable_price_is_agreed_without_closing() -> void:
	var n := Negotiation.open(_persona({"concession_rate": 1.0}), 200, 100, "metal")
	var decision := n.propose_price(n.ceiling)
	assert_true(decision["agreed"], "a price the buyer can reach is agreed to")
	assert_false(n.is_closed(), "agreeing does NOT finalize — only accept() (the button) sells")
	assert_eq(n.history.size(), 1, "propose_price is pure: no dialogue line, no offer change")


func test_propose_greedy_price_counters_with_a_lower_number() -> void:
	var n := Negotiation.open(_persona(), 200, 100, "metal")
	var decision := n.propose_price(n.ceiling * 5)
	assert_false(decision["agreed"], "an out-of-reach price is not agreed to")
	assert_gt(int(decision["counter"]), 0)
	assert_lt(
		int(decision["counter"]), n.ceiling * 5, "the counter sits below what the seller asked"
	)


func test_set_offer_uses_the_buyers_own_number() -> void:
	# Player asks ₱60, the buyer (AI or engine) says ₱50 — the standing offer becomes ₱50.
	var n := Negotiation.open(_persona(), 200, 100, "metal")
	n.set_offer_from_haggle(false, 60, 50)
	assert_eq(n.current_offer, 50, "the buyer's stated number becomes the offer")
	assert_false(n.is_closed(), "still open until the player taps Accept")


func test_set_offer_agreed_moves_to_the_sellers_price() -> void:
	var n := Negotiation.open(_persona(), 200, 100, "metal")
	n.set_offer_from_haggle(true, 70, 0)
	assert_eq(n.current_offer, 70, "agreeing moves the offer to the seller's asking price")
	assert_false(n.is_closed())


func test_cash_cap_limits_the_ceiling() -> void:
	# A buyer with only ₱90 in their wallet cannot value a ₱200 piece above ₱90.
	var n := Negotiation.open(_persona(), 200, 100, "metal", true, 90)
	assert_true(n.ceiling <= 90, "the ceiling is capped by the buyer's remaining cash")


func test_offer_never_exceeds_a_cash_capped_ceiling() -> void:
	# Even if the seller asks ₱200 and the buyer "agrees", a ₱90 wallet caps the offer.
	var n := Negotiation.open(_persona(), 200, 100, "metal", true, 90)
	n.set_offer_from_haggle(true, 200, 0)
	assert_true(n.current_offer <= 90, "an unaffordable ask is capped to what the buyer can pay")


func test_all_business_buyer_ignores_flattery_but_responds_to_substance() -> void:
	var n := Negotiation.open(_persona({"ignores_banter": true}), 200, 100, "metal")
	var before := n.ceiling
	n.banter_mood_only("You're so lovely and kind, what a sweet, generous person!")
	assert_eq(n.ceiling, before, "pure flattery doesn't move an all-business buyer")
	n.banter_mood_only("This is a rare antique with real provenance and craftsmanship.")
	assert_gt(n.ceiling, before, "but solid points about the item raise what they'll pay")


func test_all_business_buyer_charm_move_does_nothing_history_move_helps() -> void:
	var n := Negotiation.open(_persona({"ignores_banter": true}), 200, 100, "metal")
	var before := n.ceiling
	n.banter("charm")
	assert_eq(n.ceiling, before, "the charm (flattery) move doesn't sway them")
	n.banter("history")
	assert_gt(n.ceiling, before, "talking up the history does")


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

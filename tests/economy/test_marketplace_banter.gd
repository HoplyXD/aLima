extends GutTest
## Free-text banter moderation, buyer ghosting, and Mr. Maverick's always-present rule.


var _repo: DataRepository


func before_each() -> void:
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()


func after_each() -> void:
	MarketplaceService._on_loop_reset(0)  # clear ghosts so tests don't pollute each other


func _negotiation() -> Negotiation:
	return Negotiation.open(_repo.get_buyer("collector"), 200, 80, "jewelry")


# --- Content moderation ------------------------------------------------------


func test_moderation_flags_offensive_but_not_innocent_substrings() -> void:
	assert_true(ContentModeration.is_inappropriate("that is shit"), "profanity is flagged")
	assert_true(ContentModeration.is_inappropriate("Fuck off"), "case-insensitive")
	assert_true(ContentModeration.is_inappropriate("I love you date me pls"), "advances are flagged")
	assert_true(ContentModeration.is_inappropriate("will you go out with me?"), "asking out is flagged")
	assert_false(ContentModeration.is_inappropriate("a fine class of ceramics"), "'class' is fine")
	assert_false(ContentModeration.is_inappropriate("I love this piece"), "item talk is fine")
	assert_false(ContentModeration.is_inappropriate("please, a fair deal?"), "polite text is fine")


# --- Free-text chat ----------------------------------------------------------


func test_offensive_chat_offends_and_closes_the_deal() -> void:
	var n := _negotiation()
	var result := n.chat("fuck you")
	assert_true(result["offended"], "the buyer is offended")
	assert_true(n.walked, "they walk")
	assert_true(n.is_closed(), "the deal is closed")


func test_civil_chat_warms_without_offending() -> void:
	var n := _negotiation()
	var before := n.mood
	var result := n.chat("This piece has a lovely family history I appreciate.")
	assert_false(result["offended"])
	assert_false(n.is_closed(), "a civil message keeps haggling")
	assert_gt(n.mood, before, "friendly banter warms the buyer")


# --- Ghosting + Mr. Maverick -------------------------------------------------


func test_failed_banter_day_ghosts_a_normal_buyer() -> void:
	var uid := "ghost_test_item"
	MarketplaceService.ghost_failed_banter(uid, "collector")
	assert_true(MarketplaceService.is_ghosted(uid, "collector"), "a day-ghost hides them today")
	assert_true(
		MarketplaceService.is_ghosted("other_item", "collector"),
		"a day ghost applies to every item, not just this one"
	)


func test_offensive_loop_ghosts_a_normal_buyer() -> void:
	MarketplaceService.ghost_offensive("any_item", "reseller")
	assert_true(MarketplaceService.is_ghosted("any_item", "reseller"))
	assert_true(MarketplaceService.is_ghosted("another_item", "reseller"), "loop ghost is global")


func test_maverick_arrives_at_once_others_arrive_over_time() -> void:
	DayClock.reset()  # a fresh in-game clock (day 1, 07:00)
	var uid := "arrival_test_item"
	var arrived := MarketplaceService.arrived_buyers(uid)
	var ids: Array = []
	for persona in arrived:
		ids.append(persona.id)
	assert_has(ids, MarketplaceService.MAVERICK_ID, "Mr. Maverick is there immediately")
	assert_lt(
		arrived.size(),
		MarketplaceService.interested_buyers(uid).size(),
		"the other buyers haven't arrived yet — they trickle in over in-game time"
	)


func test_maverick_only_ever_artifact_ghosts() -> void:
	var uid := "maverick_item"
	# Even an offensive message only artifact-ghosts Maverick.
	MarketplaceService.ghost_offensive(uid, MarketplaceService.MAVERICK_ID)
	assert_true(MarketplaceService.is_ghosted(uid, MarketplaceService.MAVERICK_ID), "skips this artifact")
	assert_false(
		MarketplaceService.is_ghosted("other_item", MarketplaceService.MAVERICK_ID),
		"Mr. Maverick still buys every other artifact"
	)


# --- Buyer wallets (per-loop cash) -------------------------------------------


func test_wallet_starts_from_persona_and_maverick_is_unlimited() -> void:
	MarketplaceService._on_loop_reset(0)
	var student := _repo.get_buyer("student")
	assert_eq(
		MarketplaceService.buyer_cash("student"), student.wallet_start(), "wallet seeds from persona"
	)
	assert_gt(
		MarketplaceService.buyer_cash(MarketplaceService.MAVERICK_ID),
		100000,
		"Mr. Maverick has unlimited cash"
	)


func test_daily_allowance_tops_up_the_wallet() -> void:
	MarketplaceService._on_loop_reset(0)
	var before := MarketplaceService.buyer_cash("student")
	MarketplaceService._add_daily_allowance()
	var student := _repo.get_buyer("student")
	assert_eq(
		MarketplaceService.buyer_cash("student"),
		before + student.daily_allowance,
		"a new day tops the wallet up by the daily allowance"
	)


func test_selling_draws_down_the_wallet_but_not_mavericks() -> void:
	MarketplaceService._on_loop_reset(0)
	var before := MarketplaceService.buyer_cash("student")
	MarketplaceService._deduct_cash("student", 50)
	assert_eq(
		MarketplaceService.buyer_cash("student"), before - 50, "a purchase spends the buyer's cash"
	)
	var mav_before := MarketplaceService.buyer_cash(MarketplaceService.MAVERICK_ID)
	MarketplaceService._deduct_cash(MarketplaceService.MAVERICK_ID, 5000)
	assert_eq(
		MarketplaceService.buyer_cash(MarketplaceService.MAVERICK_ID),
		mav_before,
		"Mr. Maverick's unlimited cash never drops"
	)


func test_artifact_ghosted_maverick_leaves_that_items_buyer_list() -> void:
	var uid := "maverick_leaves_item"
	MarketplaceService.ghost_failed_banter(uid, MarketplaceService.MAVERICK_ID)
	var ids: Array = []
	for persona in MarketplaceService.interested_buyers(uid):
		ids.append(persona.id)
	assert_does_not_have(ids, MarketplaceService.MAVERICK_ID, "ghosted Maverick is gone for this item")
	var other_ids: Array = []
	for persona in MarketplaceService.interested_buyers("a_different_item"):
		other_ids.append(persona.id)
	assert_has(other_ids, MarketplaceService.MAVERICK_ID, "but he's still on other items")

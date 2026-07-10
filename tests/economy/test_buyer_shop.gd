extends GutTest

## v3 buyer evening stall (story.md §16): deterministic daily offers inside the
## authored price/rarity bands, one purchase per day, and the buy-all-five gate
## on Maverick's Day-5 fragment sale.

const TEST_SAVE := "user://test_buyer_shop_save.json"
const TEST_TEMP := "user://test_buyer_shop_save.tmp"

var _service: BuyerShopService


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("buyer-shop-test")
	GameState.new_run(4242)
	_service = BuyerShopService.new()


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)
	DataRepository.singleton().load_from_filesystem()


func test_offer_stays_inside_the_day_band_and_is_deterministic() -> void:
	var offer := _service.offer_for_day(1)
	assert_false(offer.is_empty(), "Day 1 has an offer")
	assert_between(int(offer["price"]), 300, 700, "Day 1 price band")
	assert_has(["white", "green"], str(offer["rarity_name"]), "Day 1 rarity band")
	var again := _service.offer_for_day(1)
	assert_eq(offer, again, "The same evening always shows the same offer")


func test_day4_band_is_pricier_and_rarer() -> void:
	var offer := _service.offer_for_day(4)
	if offer.is_empty():
		pass_test("no blue/purple sceneful template authored yet — band empty")
		return
	assert_between(int(offer["price"]), 1400, 1600)
	assert_has(["blue", "purple"], str(offer["rarity_name"]))


func test_buy_today_deducts_grants_and_marks() -> void:
	GameState.save_state.loop.money = 2000
	var offer := _service.offer_for_day(1)
	var result := _service.buy_today(1)
	assert_true(result.ok, "Purchase succeeds with enough pesos")
	assert_eq(GameState.save_state.loop.money, 2000 - int(offer["price"]))
	var carried := false
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("template_id") == offer["template_id"]:
			carried = true
	assert_true(carried, "The bought piece lands (dirty) in the inventory")
	assert_true(_service.is_bought(1))
	assert_false(_service.buy_today(1).ok, "One piece per evening")


func test_buy_needs_money() -> void:
	GameState.save_state.loop.money = 0
	assert_false(_service.buy_today(1).ok)
	assert_false(_service.is_bought(1))


func test_fragment_needs_all_five_days_and_day5() -> void:
	assert_false(_service.fragment_available(5), "Locked until all five offers are bought")
	GameState.save_state.loop.buyer_shop_days_bought = [1, 2, 3, 4, 5]
	assert_true(_service.all_days_bought())
	assert_false(_service.fragment_available(4), "Only on the Day-5 visit")
	assert_true(_service.fragment_available(5))


func test_buy_fragment_pays_and_grants_the_ledger() -> void:
	GameState.save_state.loop.buyer_shop_days_bought = [1, 2, 3, 4, 5]
	GameState.save_state.loop.money = 6000
	var result := _service.buy_fragment(5)
	assert_true(result.ok)
	assert_eq(GameState.save_state.loop.money, 1000)
	assert_has(GameState.save_state.persistent.legacy_items, "encoded_ledger")
	# The RELEASE -> Found -> Portal chain belongs to the caller (the shop),
	# so the service leaves the fragment untouched.
	assert_true(FragmentService.is_locked("fragment_05"))


func test_fragment_needs_money_too() -> void:
	GameState.save_state.loop.buyer_shop_days_bought = [1, 2, 3, 4, 5]
	GameState.save_state.loop.money = 4999
	assert_false(_service.buy_fragment(5).ok)
	assert_eq(GameState.save_state.loop.money, 4999, "No partial charge")

extends GutTest
## The phone scene: home/app navigation, pause ownership, and buying through the
## Marketplace app.

const PHONE_SCENE := preload("res://scenes/ui/phone.tscn")
const TEST_SAVE := "user://test_phone_save.json"
const TEST_TEMP := "user://test_phone_save.tmp"

var _tools: ToolService


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("phone-player")
	GameState.new_run()
	GameState.save_state.loop.money = 300
	GameState.save_state.loop.current_day = 1
	GameState.save_state.loop.current_hour = 7
	_tools = ToolService.new(GameState, DataRepository.singleton())
	DayClock.reset()


func after_each() -> void:
	DayClock.reset()
	MarketplaceService._on_loop_reset(0)  # clear any buyer ghosts so tests don't pollute
	EventDirector.disable_debug_force()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _open_phone() -> Phone:
	var phone: Phone = PHONE_SCENE.instantiate()
	add_child_autofree(phone)
	await wait_physics_frames(1)
	phone.open()
	return phone


func test_opens_on_home_without_pausing() -> void:
	# The phone no longer pauses the clock (only dialogue + the pause menu do), so time
	# keeps running while you browse and new buyers can arrive.
	assert_false(DayClock.is_paused())
	var phone := await _open_phone()
	assert_false(phone.owns_pause(), "the phone does not own a clock pause")
	assert_false(DayClock.is_paused(), "time keeps running while the phone is open")
	assert_eq(phone.get_current_app(), "", "phone opens on the home screen")


func test_open_and_back_to_home() -> void:
	var phone := await _open_phone()
	phone.open_app("marketplace")
	assert_eq(phone.get_current_app(), "marketplace")
	phone.show_home()
	assert_eq(phone.get_current_app(), "", "Home returns to the app grid")


func test_buying_in_tools_shop_app_deducts_and_ships() -> void:
	var phone := await _open_phone()
	phone.open_app("tools_shop")

	phone.buy("stain_lifter")  # cost 60, ship_hours 2

	assert_eq(GameState.save_state.loop.money, 240)
	assert_eq(MarketplaceService.get_pending_shipments().size(), 1)
	assert_eq(_tools.get_owned_tools().size(), 0, "not delivered yet")


func test_close_leaves_clock_running() -> void:
	var phone := await _open_phone()
	phone.close()
	assert_false(phone.owns_pause())
	assert_false(DayClock.is_paused(), "the phone never paused the clock")


func _add_clean_item(uid: String, value: int = 200) -> void:
	var inst := ObjectInstance.new()
	inst.template_id = "tarnished_pendant"
	inst.uid = uid
	inst.condition = 85
	inst.state = ModelEnums.ObjState.CLEAN
	inst.authenticity = ModelEnums.Verdict.AUTHENTIC  # scanned & judged, so it's sellable
	inst.value = value
	inst.storage_cost = 1
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func test_item_is_not_sellable_until_scanned_and_judged() -> void:
	var inst := ObjectInstance.new()
	inst.template_id = "tarnished_pendant"
	inst.uid = "unscanned1"
	inst.condition = 90
	inst.state = ModelEnums.ObjState.CLEAN
	inst.value = 200
	inst.storage_cost = 1  # authenticity left UNKNOWN — not yet scanned/judged
	var inv: Array = GameState.save_state.loop.inventory
	inv.append(inst.to_dictionary())

	assert_eq(
		MarketplaceService.get_sellable().size(), 0, "a clean but unscanned item can't be sold"
	)

	inst.authenticity = ModelEnums.Verdict.AUTHENTIC  # the player scans + commits a verdict
	inv[inv.size() - 1] = inst.to_dictionary()

	assert_eq(MarketplaceService.get_sellable().size(), 1, "scanning + judging unlocks selling")


func test_marketplace_sell_flow_accepts_an_offer() -> void:
	_add_clean_item("c1", 200)
	var phone := await _open_phone()
	phone.open_app("marketplace")
	phone.open_buyers("c1")
	phone.begin_haggle("collector")
	var before := GameState.save_state.loop.money

	phone.accept_offer()

	assert_gt(GameState.save_state.loop.money, before, "accepting pays out")
	assert_eq(MarketplaceService.get_sellable().size(), 0, "the item was sold")


func test_marketplace_walk_keeps_the_item() -> void:
	_add_clean_item("c1", 200)
	var phone := await _open_phone()
	phone.open_app("marketplace")
	phone.open_buyers("c1")
	phone.begin_haggle("reseller")

	phone.haggle_walk()

	assert_eq(MarketplaceService.get_sellable().size(), 1, "walking away keeps the item")


func test_typed_price_updates_the_offer_but_only_accept_sells() -> void:
	_add_clean_item("c1", 200)
	var phone := await _open_phone()
	phone.open_app("marketplace")
	phone.open_buyers("c1")
	phone.begin_haggle("collector")
	var before := GameState.save_state.loop.money

	await phone.haggle_chat("It's a lovely piece — I'll let it go for 1 peso")

	assert_eq(GameState.save_state.loop.money, before, "typing a price does NOT auto-sell")
	assert_eq(MarketplaceService.get_sellable().size(), 1, "the item is still held")
	assert_eq(phone._negotiation.current_offer, 1, "the offer moves to the agreed price")

	phone.accept_offer()

	assert_gt(GameState.save_state.loop.money, before, "only tapping Accept finalizes the sale")
	assert_eq(MarketplaceService.get_sellable().size(), 0, "the item sold after Accept")


func test_civil_chat_without_a_price_keeps_haggling() -> void:
	_add_clean_item("c1", 200)
	var phone := await _open_phone()
	phone.open_app("marketplace")
	phone.open_buyers("c1")
	phone.begin_haggle("collector")

	await phone.haggle_chat("What a beautiful little thing this is.")

	assert_false(phone._negotiation.is_closed(), "a civil non-price message keeps the deal open")
	assert_eq(MarketplaceService.get_sellable().size(), 1, "nothing sells from banter alone")


func test_offensive_chat_ends_the_deal() -> void:
	_add_clean_item("c1", 200)
	var phone := await _open_phone()
	phone.open_app("marketplace")
	phone.open_buyers("c1")
	phone.begin_haggle("collector")

	await phone.haggle_chat("fuck you")

	assert_null(phone._negotiation, "an offensive message ends the deal")
	assert_true(MarketplaceService.is_ghosted("c1", "collector"), "the buyer is ghosted")
	assert_eq(MarketplaceService.get_sellable().size(), 1, "the item is kept, not sold")


func test_marketplace_app_blocked_during_brownout() -> void:
	EventDirector.enable_debug_force()
	assert_true(EventDirector.force_event("sudden_brownout"))

	var phone := await _open_phone()
	phone.open_app("marketplace")

	assert_eq(phone.get_current_app(), "marketplace")
	var found := false
	for child in phone._app_content.get_children():
		if child is Label and (child as Label).text.find("No connection") >= 0:
			found = true
			break
	assert_true(found, "marketplace shows the brownout no-connection message")


func test_flashlight_app_available_during_brownout() -> void:
	EventDirector.enable_debug_force()
	assert_true(EventDirector.force_event("sudden_brownout"))

	var phone := await _open_phone()
	phone.open_app("flashlight")

	assert_eq(phone.get_current_app(), "flashlight", "flashlight opens during brownout")
	var found := false
	for child in phone._app_content.get_children():
		if child is Label and (child as Label).text.find("Flashlight: OFF") >= 0:
			found = true
			break
	assert_true(found, "flashlight shows its off state")


func test_flashlight_toggles_loop_state() -> void:
	var phone := await _open_phone()
	phone.open_app("flashlight")
	assert_false(GameState.save_state.loop.flashlight_on)

	phone.toggle_flashlight()

	assert_true(GameState.save_state.loop.flashlight_on, "toggle turns flashlight on")
	var on_label_found := false
	for child in phone._app_content.get_children():
		if child is Label and (child as Label).text.find("Flashlight: ON") >= 0:
			on_label_found = true
			break
	assert_true(on_label_found, "flashlight UI shows ON after toggle")

	phone.toggle_flashlight()
	assert_false(GameState.save_state.loop.flashlight_on, "toggle turns flashlight off")


func test_haggle_persists_when_shopping_around_and_returning() -> void:
	_add_clean_item("c1", 200)
	var a := MarketplaceService.haggle_for("c1", "collector")
	a.set_offer_from_haggle(true, 80, 0)  # banter the offer to ₱80
	# Shop around (open another buyer) then come back to the first.
	MarketplaceService.haggle_for("c1", "reseller")
	var b := MarketplaceService.haggle_for("c1", "collector")
	assert_eq(b, a, "returning to a buyer restores the very same session")
	assert_eq(b.current_offer, 80, "their standing offer is preserved while you shop around")


func test_buyer_offer_is_capped_by_their_wallet() -> void:
	MarketplaceService._on_loop_reset(0)
	_add_clean_item("c1", 1000)  # a pricey piece, well above a student's wallet
	var n := MarketplaceService.haggle_for("c1", "student")
	assert_true(
		n.ceiling <= MarketplaceService.buyer_cash("student"),
		"a buyer's ceiling can never exceed the cash they hold"
	)


# ---------------------------------------------------------------------------
# Backend banter tier tests (injected fake NegotiationClient)
# ---------------------------------------------------------------------------


class _FakeBanter:
	extends RefCounted
	var live := true
	var reply := "Backend says hello."
	var offended := false

	func is_live() -> bool:
		return live

	func model_name() -> String:
		return "gemini-2.0-flash"

	func fetch_banter(_p, _o, _s, _m, _h) -> Dictionary:
		return {"ok": true, "reply": reply, "offended": offended}


func _haggle_with_fake() -> Phone:
	_add_clean_item("c1", 200)
	var phone := await _open_phone()
	phone.open_app("marketplace")
	phone.open_buyers("c1")
	phone.begin_haggle("collector")
	return phone


func test_backend_banter_reply_used_when_live() -> void:
	var phone := await _haggle_with_fake()
	var fake := _FakeBanter.new()
	fake.live = true
	phone.set_banter_client(fake)

	var resp := await phone._buyer_response("hi", 0)

	assert_eq(resp.get("reply"), "Backend says hello.", "live backend reply is used")
	assert_false(resp.get("offended", false), "offended defaults to false")


func test_offline_banter_fallback_when_backend_not_live() -> void:
	var phone := await _haggle_with_fake()
	var fake := _FakeBanter.new()
	fake.live = false
	phone.set_banter_client(fake)

	var resp := await phone._buyer_response("hi", 0)

	var reply: String = str(resp.get("reply", ""))
	assert_false(reply.is_empty(), "offline fallback returns a line")
	assert_ne(reply, "Backend says hello.", "offline reply is not the backend string")


func test_backend_offended_flag_propagates() -> void:
	var phone := await _haggle_with_fake()
	var fake := _FakeBanter.new()
	fake.offended = true
	phone.set_banter_client(fake)

	var resp := await phone._buyer_response("hi", 0)

	assert_true(resp.get("offended", false), "offended flag from backend propagates")


func test_backend_never_sets_price_number_stays_deterministic() -> void:
	var phone := await _haggle_with_fake()
	var fake := _FakeBanter.new()
	fake.reply = "I'll pay anything you ask."
	phone.set_banter_client(fake)

	var price := 50
	var expected := phone._negotiation.propose_price(price)
	var resp := await phone._buyer_response("How about %d?" % price, price)

	assert_eq(
		int(resp.get("counter", 0)),
		int(expected.get("counter", 0)),
		"counter comes only from the deterministic Negotiation engine"
	)
	assert_eq(
		bool(resp.get("agreed", false)),
		bool(expected.get("agreed", false)),
		"agreed comes only from the deterministic Negotiation engine"
	)

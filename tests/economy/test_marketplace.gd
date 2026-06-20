extends GutTest
## Phone Marketplace: buying a tool spends money and schedules a shipment that
## arrives after the tool's ship_hours of in-game time.

const TEST_SAVE := "user://test_market_save.json"
const TEST_TEMP := "user://test_market_save.tmp"

var _repo: DataRepository
var _tools: ToolService


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()
	GameState.initialize("market-player")
	GameState.new_run()
	GameState.save_state.loop.money = 300
	GameState.save_state.loop.current_day = 1
	GameState.save_state.loop.current_hour = 7
	_tools = ToolService.new(GameState, _repo)


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func test_catalog_lists_only_buyable_tools() -> void:
	var catalog := MarketplaceService.get_catalog()
	assert_gt(catalog.size(), 0)
	for tool in catalog:
		assert_true((tool as ToolDefinition).buyable)


func test_buying_deducts_money_and_schedules_a_shipment() -> void:
	# stain_lifter: cost 60, ship_hours 2.
	var result := MarketplaceService.buy("stain_lifter")

	assert_true(result.ok)
	assert_eq(GameState.save_state.loop.money, 240)
	assert_eq(MarketplaceService.get_pending_shipments().size(), 1)
	# arrival = day*24 + hour + ship_hours = 1*24 + 7 + 2 = 33.
	assert_eq(result.arrival_index, 33)
	# Nothing has arrived yet.
	assert_eq(_tools.get_owned_tools().size(), 0)


func test_shipment_arrives_only_after_ship_hours() -> void:
	MarketplaceService.buy("stain_lifter")  # arrives at index 33

	assert_eq(MarketplaceService.deliver_due(1, 8), 0, "too early (index 32)")
	assert_eq(_tools.get_owned_tools().size(), 0)

	var delivered := MarketplaceService.deliver_due(1, 9)  # index 33
	assert_eq(delivered, 1)
	assert_eq(_tools.get_owned_tools().size(), 1)
	assert_eq(_tools.get_owned_tools()[0].tool_id, "stain_lifter")
	assert_eq(MarketplaceService.get_pending_shipments().size(), 0)


func test_insufficient_money_is_rejected() -> void:
	GameState.save_state.loop.money = 10

	var result := MarketplaceService.buy("photo_kit")  # cost 120

	assert_false(result.ok)
	assert_eq(GameState.save_state.loop.money, 10)
	assert_eq(MarketplaceService.get_pending_shipments().size(), 0)


func test_non_buyable_tool_is_rejected() -> void:
	var result := MarketplaceService.buy("soft_cloth")  # free legacy basic, not buyable

	assert_false(result.ok)
	assert_eq(GameState.save_state.loop.money, 300)


func test_buying_multiple_yields_multiple_instances() -> void:
	MarketplaceService.buy("solvent")
	MarketplaceService.buy("solvent")

	MarketplaceService.deliver_due(2, 0)  # well past arrival

	assert_eq(_tools.get_owned_tools().size(), 2, "two purchases produce two instances")


# --- Selling (deterministic haggle) ------------------------------------------


func _add_item(uid: String, state: int, value: int = 0, condition: float = 80.0) -> void:
	var inst := ObjectInstance.new()
	inst.template_id = "tarnished_pendant"  # jewelry
	inst.uid = uid
	inst.condition = condition
	inst.state = state
	inst.value = value
	inst.storage_cost = 1
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func test_get_sellable_only_returns_restored_items() -> void:
	_add_item("d1", ModelEnums.ObjState.DIRTY)
	_add_item("c1", ModelEnums.ObjState.CLEAN)
	var sellable := MarketplaceService.get_sellable()
	assert_eq(sellable.size(), 1)
	assert_eq(sellable[0].uid, "c1")


func test_assessed_value_uses_the_instance_value() -> void:
	_add_item("c1", ModelEnums.ObjState.CLEAN, 275)
	assert_eq(MarketplaceService.assessed_value("c1"), 275)


func test_interested_buyers_excludes_those_who_cannot_afford() -> void:
	_add_item("c1", ModelEnums.ObjState.CLEAN, 1000)
	var ids: Array = []
	for raw in MarketplaceService.interested_buyers("c1"):
		ids.append((raw as BuyerPersona).id)
	assert_does_not_have(ids, "student", "the low-budget student can't afford a ₱1000 piece")
	assert_has(ids, "collector")


func test_start_negotiation_is_null_for_an_unrestored_item() -> void:
	_add_item("d1", ModelEnums.ObjState.DIRTY, 200)
	assert_null(MarketplaceService.start_negotiation("d1", "collector"))


func test_complete_sale_credits_removes_and_records_best() -> void:
	_add_item("c1", ModelEnums.ObjState.CLEAN, 250, 90.0)
	watch_signals(EventBus)
	var before := GameState.save_state.loop.money

	var result := MarketplaceService.complete_sale("c1", 250, "collector")

	assert_true(result.ok)
	assert_eq(GameState.save_state.loop.money, before + 250)
	assert_eq(MarketplaceService.get_sellable().size(), 0, "the item leaves inventory")
	assert_signal_emitted(EventBus, "sale_completed")
	var best: Dictionary = GameState.save_state.persistent.best_sale
	assert_eq(ModelUtils.as_int(best.get("price")), 250)
	assert_eq(best.get("buyer_id"), "collector")


func test_cannot_sell_the_same_item_twice() -> void:
	_add_item("c1", ModelEnums.ObjState.CLEAN, 250)
	assert_true(MarketplaceService.complete_sale("c1", 250, "collector").ok)
	assert_false(MarketplaceService.complete_sale("c1", 250, "collector").ok, "already sold (DISP-R5)")


func test_best_sale_keeps_the_highest_price() -> void:
	_add_item("c2", ModelEnums.ObjState.CLEAN, 400)
	_add_item("c3", ModelEnums.ObjState.CLEAN, 50)
	MarketplaceService.complete_sale("c2", 400, "collector")
	MarketplaceService.complete_sale("c3", 50, "reseller")
	assert_eq(ModelUtils.as_int(GameState.save_state.persistent.best_sale.get("price")), 400)

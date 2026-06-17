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

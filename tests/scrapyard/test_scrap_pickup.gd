extends GutTest

## Headless tests for the unified proximity-E scrap pickup.

const SCRAP_ITEM_SCENE := preload("res://scenes/scrapyard/scrap_item.tscn")


func before_each() -> void:
	GameState.initialize("scrap-pickup-test")
	DayClock.reset()


func after_each() -> void:
	DayClock.reset()


func test_activating_scrap_increments_pool_and_emits_collected() -> void:
	var item: ScrapItem = SCRAP_ITEM_SCENE.instantiate()
	item.set_rarity("blue")
	add_child_autofree(item)
	watch_signals(item)

	item.activate()

	assert_signal_emitted(item, "collected", "scrap should emit collected")
	assert_eq(
		GameState.save_state.loop.scrap_pool.get("blue", 0),
		1,
		"blue scrap should be added to the loop pool"
	)


func test_activating_scrap_despawns_item() -> void:
	var item: ScrapItem = SCRAP_ITEM_SCENE.instantiate()
	add_child_autofree(item)

	item.activate()

	assert_true(item.is_queued_for_deletion(), "scrap should queue_free after pickup")


func test_each_tier_increments_its_own_slot() -> void:
	for rarity_name in ModelEnums.RARITY_NAMES:
		GameState.initialize("scrap-pickup-test-%s" % rarity_name)
		var item: ScrapItem = SCRAP_ITEM_SCENE.instantiate()
		item.set_rarity(rarity_name)
		add_child_autofree(item)

		item.activate()

		for check_name in ModelEnums.RARITY_NAMES:
			var expected := 1 if check_name == rarity_name else 0
			assert_eq(
				GameState.save_state.loop.scrap_pool.get(check_name, 0),
				expected,
				"only the %s slot should increment" % rarity_name
			)

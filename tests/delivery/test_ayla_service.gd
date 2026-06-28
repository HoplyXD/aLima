extends GutTest

## Tests for the RV2-B scrap-foraging / Ayla delivery loop: scrap pool persistence,
## the ~1-hour sort timer, the pure scrap-bias function, seeded distribution bias,
## determinism, and the removal of the free auto-delivery path.

const TEST_SAVE := "user://test_ayla_service_save.json"
const TEST_TEMP := "user://test_ayla_service_save.tmp"

var _repo: DataRepository


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("ayla-test-player")
	GameState.set_debug_seed_override(12345)
	GameState.new_run()
	DayClock.reset()
	DayClock.start_day(1)
	_repo = DataRepository.singleton()


func after_each() -> void:
	DayClock.reset()
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _make_service() -> Node:
	# AylaService is an autoload; return the production instance directly.
	return AylaService


func _add_scrap(pool: Dictionary, rarity: String, count: int) -> void:
	pool[rarity] = pool.get(rarity, 0) + count


func test_scrap_pool_serializes_and_resets() -> void:
	var pool: Dictionary = GameState.save_state.loop.scrap_pool
	_add_scrap(pool, "white", 3)
	_add_scrap(pool, "blue", 1)

	var saved := SaveService.save_game()
	assert_true(saved.ok)

	var loaded := SaveService.load_game()
	assert_true(loaded.ok)
	var loaded_pool: Dictionary = GameState.save_state.loop.scrap_pool
	assert_eq(ModelUtils.as_int(loaded_pool.get("white")), 3)
	assert_eq(ModelUtils.as_int(loaded_pool.get("blue")), 1)

	GameState.reset_loop_state()
	assert_true(GameState.save_state.loop.scrap_pool.is_empty())


func test_pending_sort_serializes_and_resets() -> void:
	var pool: Dictionary = GameState.save_state.loop.scrap_pool
	_add_scrap(pool, "green", 2)
	var svc := _make_service()
	assert_true(svc.submit_scrap({"green": 2}))

	var saved := SaveService.save_game()
	assert_true(saved.ok)
	var loaded := SaveService.load_game()
	assert_true(loaded.ok)
	var pending: Dictionary = GameState.save_state.loop.pending_sort
	assert_true(pending.get("active", false))
	assert_eq(ModelUtils.as_int(pending.get("ready_index")), 32)  # Day 1 hour 7 + 1.

	GameState.reset_loop_state()
	assert_true(GameState.save_state.loop.pending_sort.is_empty())


func test_submit_scrap_deducts_from_pool() -> void:
	var pool: Dictionary = GameState.save_state.loop.scrap_pool
	_add_scrap(pool, "white", 5)
	_add_scrap(pool, "purple", 2)

	var svc := _make_service()
	assert_true(svc.submit_scrap({"white": 3, "purple": 1}))

	assert_eq(pool.get("white"), 2)
	assert_eq(pool.get("purple"), 1)
	var pending: Dictionary = GameState.save_state.loop.pending_sort
	assert_true(pending.get("active", false))
	assert_eq(ModelUtils.as_int(pending.get("ready_index")), 32)
	assert_eq(ModelUtils.as_int(pending["submitted"].get("white")), 3)
	assert_eq(ModelUtils.as_int(pending["submitted"].get("purple")), 1)


func test_submit_scrap_refuses_overdraft() -> void:
	_add_scrap(GameState.save_state.loop.scrap_pool, "white", 1)
	var svc := _make_service()
	assert_false(svc.submit_scrap({"white": 2}))


func test_submit_scrap_refuses_second_sort_same_day() -> void:
	_add_scrap(GameState.save_state.loop.scrap_pool, "white", 4)
	var svc := _make_service()
	assert_true(svc.submit_scrap({"white": 2}))
	assert_false(svc.submit_scrap({"white": 2}))


func test_sort_timer_knocks_after_one_hour_not_before() -> void:
	_add_scrap(GameState.save_state.loop.scrap_pool, "green", 2)
	var svc := _make_service()
	watch_signals(svc)
	assert_true(svc.submit_scrap({"green": 2}))

	# Advance to 7:30 (still before 8:00 ready time).
	_assert_not_ready_yet(svc)
	_set_loop_hour(1, 8)
	EventBus.hour_changed.emit(1, 8)
	assert_true(svc.is_sort_ready())
	assert_signal_emitted(svc, "sort_ready")


func test_sort_timer_knocks_after_reloading_past_ready() -> void:
	_add_scrap(GameState.save_state.loop.scrap_pool, "blue", 1)
	var svc := _make_service()
	assert_true(svc.submit_scrap({"blue": 1}))
	SaveService.save_game()

	# Simulate returning to the shop at 10:00; the sort should already be ready.
	DayClock.start_day(1)
	_set_loop_hour(1, 10)
	EventBus.hour_changed.emit(1, 10)
	assert_true(svc.is_sort_ready())


func _assert_not_ready_yet(svc: Node) -> void:
	_set_loop_hour(1, 7)
	EventBus.hour_changed.emit(1, 7)
	assert_false(svc.is_sort_ready())
	assert_signal_not_emitted(svc, "sort_ready")


func _set_loop_hour(day: int, hour: int) -> void:
	# LoopController normally mirrors DayClock into the save loop; bypass it here
	# so emitted EventBus.hour_changed ticks match AylaService's is_sort_ready().
	GameState.save_state.loop.current_day = day
	GameState.save_state.loop.current_hour = hour


func test_bias_shifts_higher_tier_weights_up() -> void:
	var base := {"white": 40.0, "green": 25.0, "blue": 18.0, "purple": 10.0, "gold": 3.0}
	var impulses := DataRepository.singleton().get_scrap_config().bias_impulses
	var scalar := 30.0

	var poor := AylaService.apply_scrap_bias(base, {"white": 5}, impulses, scalar)
	var rich := AylaService.apply_scrap_bias(base, {"purple": 5}, impulses, scalar)

	# Rich purple input should raise purple/gold weights compared to poor white input.
	assert_gt(rich["purple"], poor["purple"], "purple weight should rise with purple scrap")
	assert_gt(rich["gold"], poor["gold"], "gold weight should rise with purple scrap")
	# White weight should be much higher for the poor input.
	assert_gt(poor["white"], rich["white"], "white weight should stay high with white scrap")


func test_bias_never_forces_a_tier_to_probability_one() -> void:
	var base := {"white": 40.0, "green": 25.0, "blue": 18.0, "purple": 10.0, "gold": 3.0}
	var impulses := DataRepository.singleton().get_scrap_config().bias_impulses
	var scalar := 1000.0  # Extreme scalar to stress the guarantee.

	var rich := AylaService.apply_scrap_bias(base, {"gold": 20}, impulses, scalar)
	var total := 0.0
	for w in rich.values():
		total += w
	for rarity_name in rich.keys():
		var weight: float = rich[rarity_name]
		assert_lt(
			weight, total, "rarity '%s' reached probability 1.0 (weight >= total)" % rarity_name
		)


func test_seeded_distribution_is_biased_by_scrap() -> void:
	var generator := DeliveryGenerator.new(_repo, GameState)
	var base_cfg := _repo.get_delivery_config()
	var impulses := _repo.get_scrap_config().bias_impulses
	var scalar := _repo.get_scrap_config().bias_scalar

	var poor_submission := {"white": 3}
	var rich_submission := {"purple": 3}
	var poor_weights := AylaService.apply_scrap_bias(
		base_cfg.rarity_weights, poor_submission, impulses, scalar
	)
	var rich_weights := AylaService.apply_scrap_bias(
		base_cfg.rarity_weights, rich_submission, impulses, scalar
	)

	var poor_cfg := _clone_config(base_cfg, poor_weights)
	var rich_cfg := _clone_config(base_cfg, rich_weights)

	# Measure "better than common" (anything above white) so the assertion is robust to which exact
	# rarity tiers have templates — designers freely re-tier artifacts in their scenes.
	var poor_high := 0
	var rich_high := 0
	var runs := 40
	for seed in range(runs):
		GameState.initialize("ayla-test-player")
		GameState.set_debug_seed_override(seed)
		GameState.new_run()
		var poor_delivery := generator.generate_day_delivery(1, poor_cfg)
		var rich_delivery := generator.generate_day_delivery(1, rich_cfg)
		poor_high += _count_above_white(poor_delivery)
		rich_high += _count_above_white(rich_delivery)

	# The bias weights themselves must favour the richer tier...
	assert_gt(
		rich_weights.get("purple", 0.0) + rich_weights.get("blue", 0.0),
		poor_weights.get("purple", 0.0) + poor_weights.get("blue", 0.0),
		"rich scrap raises the high-tier rarity weights"
	)
	# ...and that must translate into more above-common items delivered.
	assert_gt(rich_high, poor_high, "rich scrap should raise the frequency of better-than-common items")


## Count of delivered instances whose rarity is above white (green/blue/purple/gold).
func _count_above_white(delivery: Array) -> int:
	var total := 0
	for rarity in [
		ModelEnums.Rarity.GREEN,
		ModelEnums.Rarity.BLUE,
		ModelEnums.Rarity.PURPLE,
		ModelEnums.Rarity.GOLD
	]:
		total += _count_rarity(delivery, rarity)
	return total


func test_same_seed_and_scrap_produces_same_batch() -> void:
	var generator := DeliveryGenerator.new(_repo, GameState)
	var base_cfg := _repo.get_delivery_config()
	var impulses := _repo.get_scrap_config().bias_impulses
	var scalar := _repo.get_scrap_config().bias_scalar
	var submission := {"blue": 2}
	var biased_weights := AylaService.apply_scrap_bias(
		base_cfg.rarity_weights, submission, impulses, scalar
	)
	var cfg := _clone_config(base_cfg, biased_weights)

	GameState.initialize("ayla-test-player")
	GameState.set_debug_seed_override(9999)
	GameState.new_run()
	var first_generator := DeliveryGenerator.new(_repo, GameState)
	var first := first_generator.generate_day_delivery(1, cfg)
	var first_ids := _uids_of(first)

	GameState.initialize("ayla-test-player")
	GameState.set_debug_seed_override(9999)
	GameState.new_run()
	var second_generator := DeliveryGenerator.new(_repo, GameState)
	var second := second_generator.generate_day_delivery(1, cfg)
	var second_ids := _uids_of(second)

	assert_eq(first_ids, second_ids)


func test_no_free_auto_delivery_path() -> void:
	# Without a sort, Ayla is not ready and no batch should be generated through
	# the morning-delivery fallback. The old auto-knock on day change is gone.
	var svc := _make_service()
	assert_false(svc.is_sort_active())
	assert_false(svc.is_sort_ready())

	# Simulate a new day; nothing should become ready.
	watch_signals(svc)
	EventBus.day_changed.emit(2)
	EventBus.hour_changed.emit(2, 8)
	assert_false(svc.is_sort_ready())
	assert_signal_not_emitted(svc, "sort_ready")


func test_scrap_sort_batch_size_is_small() -> void:
	_add_scrap(GameState.save_state.loop.scrap_pool, "green", 1)
	var svc := _make_service()
	assert_true(svc.submit_scrap({"green": 1}))

	var base_cfg := _repo.get_delivery_config()
	var biased_cfg: DeliveryConfig = svc.get_biased_delivery_config(base_cfg)
	assert_eq(biased_cfg.batch_min, 1, "scrap-sort batches start at 1")
	assert_eq(biased_cfg.batch_max, 3, "scrap-sort batches cap at 3")


func _clone_config(base_cfg: DeliveryConfig, rarity_weights: Dictionary) -> DeliveryConfig:
	var cfg := DeliveryConfig.new()
	cfg.schema_version = base_cfg.schema_version
	cfg.batch_min = base_cfg.batch_min
	cfg.batch_max = base_cfg.batch_max
	cfg.storage_cap = base_cfg.storage_cap
	cfg.rarity_weights = rarity_weights.duplicate()
	return cfg


func _count_rarity(delivery: Array[ObjectInstance], rarity: int) -> int:
	var count := 0
	for inst in delivery:
		var template: ScrapObjectTemplate = _repo.get_template(inst.template_id)
		if template != null and template.base_rarity == rarity:
			count += 1
	return count


func _uids_of(instances: Array[ObjectInstance]) -> Array[String]:
	var out: Array[String] = []
	for inst in instances:
		out.append(inst.uid)
	return out

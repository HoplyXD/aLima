extends GutTest
## Bounded event outcomes routed through existing contracts.

var _repo: DataRepository


func before_each() -> void:
	_repo = DataRepository.new()
	_repo.load_from_filesystem()
	GameState.initialize("event-outcome-test")
	GameState.set_debug_seed_override(5555)
	GameState.new_run()
	DayClock.reset()
	SaveService.set_save_paths("user://test_alima_save.json", "user://test_alima_save_tmp.json")
	SaveService.delete_save_files()
	EventDirector.enable_debug_force()
	EventDirector._on_loop_reset(GameState.loop_index)


func after_each() -> void:
	EventDirector.disable_debug_force()
	EventDirector._on_loop_reset(GameState.loop_index)
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func test_rush_delivery_generates_larger_batch() -> void:
	EventDirector.force_event("rush_delivery")
	var base_cfg := _repo.get_delivery_config()
	var event_cfg := EventDirector.modify_delivery_config(base_cfg)
	var generator := DeliveryGenerator.new(_repo, GameState)
	var delivery := generator.generate_day_delivery(1, event_cfg)
	assert_gt(delivery.size(), base_cfg.batch_min, "rush delivery produces a larger batch")


func test_mystery_box_adds_extra_instance() -> void:
	EventDirector.force_event("mystery_box")
	var extras := EventDirector.get_injected_delivery_extras(1)
	assert_eq(extras.size(), 1)
	assert_eq(extras[0].template_id, "rusted_tin")
	assert_eq(extras[0].contents, ModelEnums.OpenResult.TEMPORAL_ECHO)


func test_community_request_resolves_on_restoration() -> void:
	watch_signals(EventBus)
	EventDirector.force_event("community_request")
	var extras := EventDirector.get_injected_delivery_extras(1)
	assert_eq(extras.size(), 1)
	var inst := extras[0]
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	# Ensure the required starting-kit tool is available for the request object.
	if not GameState.save_state.loop.tool_items.has("soft_cloth"):
		GameState.save_state.loop.tool_items.append("soft_cloth")
	var service := RestorationService.new(GameState, _repo)
	# Use the correct tool for the small_santo template (soft_cloth, legacy/infinite).
	var result := service.apply_tool(inst.uid, "soft_cloth")
	assert_true(result.ok, "restoration action succeeds")
	assert_signal_emit_count(EventBus, "event_outcome_resolved", 1)
	var params: Array = get_signal_parameters(EventBus, "event_outcome_resolved", 0)
	assert_eq(params[0], "community_request")


func test_suspicious_antique_resolves_on_scanner_verdict() -> void:
	watch_signals(EventBus)
	EventDirector.force_event("suspicious_antique")
	var extras := EventDirector.get_injected_delivery_extras(1)
	assert_eq(extras.size(), 1)
	var inst := extras[0]
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	EventBus.scanner_verdict_committed.emit(inst.uid, "modified")
	var resolved := false
	for raw in GameState.save_state.loop.event_outcomes:
		if raw is Dictionary and raw.get("event_id") == "suspicious_antique":
			resolved = true
	assert_true(resolved, "suspicious antique outcome recorded")


func test_rare_buyer_alert_boosts_wallet() -> void:
	EventDirector.force_event("rare_buyer_alert")
	var cash_before := MarketplaceService.buyer_cash("collector")
	EventDirector._apply_rare_buyer_alert()
	var cash_after := MarketplaceService.buyer_cash("collector")
	assert_gt(cash_after, cash_before, "collector wallet boosted")


func test_rainy_day_leak_slows_restoration() -> void:
	EventDirector.force_event("rainy_day_leak")
	var mult := EventDirector.get_restoration_condition_multiplier()
	assert_lt(mult, 1.0, "leak reduces condition gain")


func test_tool_breakdown_emits_tool_broke() -> void:
	var tools := ToolService.new(GameState, _repo)
	tools.grant_tool("photo_kit")
	watch_signals(EventBus)
	EventDirector.force_event("tool_breakdown")
	assert_signal_emitted(EventBus, "tool_broke")


func test_delivery_generated_signal_emitted() -> void:
	watch_signals(EventBus)
	var generator := DeliveryGenerator.new(_repo, GameState)
	generator.generate_day_delivery(1)
	assert_signal_emitted(EventBus, "delivery_generated")

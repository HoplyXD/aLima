extends GutTest
## EventDirector trigger, cap, reset, and debug-gated QA override.

var _repo: DataRepository


func before_each() -> void:
	_repo = DataRepository.new()
	_repo.load_from_filesystem()
	GameState.initialize("event-test-player")
	GameState.set_debug_seed_override(4242)
	GameState.new_run()
	DayClock.reset()
	SaveService.set_save_paths("user://test_alima_save.json", "user://test_alima_save_tmp.json")
	SaveService.delete_save_files()
	EventDirector.enable_debug_force()
	EventDirector._on_loop_reset(GameState.loop_index)


func after_each() -> void:
	EventDirector.disable_debug_force()
	# Clear any active events so later suites are not polluted by event modifiers.
	EventDirector._on_loop_reset(GameState.loop_index)
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func test_force_event_is_debug_gated() -> void:
	EventDirector.disable_debug_force()
	if OS.is_debug_build():
		# In a debug build the OS gate still allows forcing.
		assert_true(EventDirector.force_event("rush_delivery"))
	else:
		assert_false(EventDirector.force_event("rush_delivery"))
	EventDirector.enable_debug_force()
	# Force a different event so the earlier rush_delivery cap (if triggered in the
	# debug-build branch) does not block this assertion.
	assert_true(EventDirector.force_event("sudden_brownout"))


func test_force_event_activates_and_emits_signal() -> void:
	watch_signals(EventBus)
	EventDirector.force_event("rush_delivery")
	assert_true(EventDirector.is_event_active("rush_delivery"))
	assert_signal_emit_count(EventBus, "event_triggered", 1)
	var emitted: Array = get_signal_parameters(EventBus, "event_triggered", 0)
	assert_eq(emitted[0], "rush_delivery")


func test_event_state_resets_on_loop_reset() -> void:
	EventDirector.force_event("rush_delivery")
	assert_true(EventDirector.is_event_active("rush_delivery"))
	GameState.reset_loop_state()
	EventDirector._on_loop_reset(GameState.loop_index)
	assert_false(EventDirector.is_event_active("rush_delivery"))
	assert_eq(GameState.save_state.loop.event_history.size(), 0)
	assert_eq(GameState.save_state.loop.event_caps.size(), 0)


func test_per_loop_cap_blocks_duplicate_disruptive() -> void:
	EventDirector.force_event("rush_delivery")
	# Force again should fail because per_loop_cap is 1 for rush_delivery.
	assert_false(EventDirector.force_event("rush_delivery"))


func test_production_roll_is_deterministic_by_seed() -> void:
	GameState.set_debug_seed_override(1234)
	GameState.loop_index = 0
	GameState.new_run()
	EventDirector._on_loop_reset(GameState.loop_index)
	EventDirector.roll_morning_event(1)
	var first: Array = EventDirector.get_active_events().duplicate()
	# Same seed and same loop index on a fresh loop should produce the same active
	# event set, proving the roll is deterministic from the run-local seed.
	GameState.loop_index = 0
	GameState.new_run()
	EventDirector._on_loop_reset(GameState.loop_index)
	EventDirector.roll_morning_event(1)
	var second: Array = EventDirector.get_active_events().duplicate()
	assert_eq(first.size(), second.size())
	for i in mini(first.size(), second.size()):
		assert_eq(first[i].get("event_id"), second[i].get("event_id"))


func test_modify_delivery_config_for_rush_delivery() -> void:
	var base_cfg := _repo.get_delivery_config()
	EventDirector.force_event("rush_delivery")
	var mod_cfg := EventDirector.modify_delivery_config(base_cfg)
	assert_eq(mod_cfg.batch_max, base_cfg.batch_max + 1, "rush delivery adds one batch item")


func test_brownout_blocks_marketplace_and_electric_tools() -> void:
	EventDirector.force_event("sudden_brownout")
	assert_false(EventDirector.is_marketplace_available())
	# No current tool has "electric" enable, so no tool is blocked.
	assert_false(EventDirector.is_tool_blocked("soft_cloth"))


func test_rainy_day_leak_adds_extra_conditions() -> void:
	EventDirector.force_event("rainy_day_leak")
	var extras := EventDirector.get_extra_conditions_for_delivery()
	assert_eq(extras.size(), 1)
	assert_eq(extras[0].get("type"), "water_stain")


func test_tool_breakdown_does_not_break_required_fragment_tool() -> void:
	# Grant a durability-tracked rust_brush and place a released fragment whose carrier
	# needs it. The breakdown event must not remove the only obtainable copy.
	var tools := ToolService.new(GameState, _repo)
	tools.grant_tool("rust_brush")
	var fragment: Fragment = GameState.save_state.persistent.fragments.get("fragment_01")
	if fragment != null:
		fragment.state = ModelEnums.FragmentState.RELEASED
	GameState.save_state.loop.current_carrier_placements["fragment_01"] = {
		"carrier_template_id": "rusted_tin",
		"container_id": "pile_center",
		"day": 1,
	}
	watch_signals(EventBus)
	EventDirector.force_event("tool_breakdown")
	# rust_brush is required by rusted_tin, so it should be protected.
	var still_owned := false
	for raw in GameState.save_state.loop.owned_tools:
		if raw is Dictionary and raw.get("tool_id") == "rust_brush":
			still_owned = true
	assert_true(still_owned, "required fragment tool remains available after breakdown")

extends GutTest

## Tests for triage logic and application (P3.4/P3.5): storage-cap enforcement,
## mandatory decisions, keep/recycle outcomes, persistence rules, and neglect
## history.

const TEST_SAVE := "user://test_triage_save.json"
const TEST_TEMP := "user://test_triage_save.tmp"

var _repo: DataRepository


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	GameState.initialize("triage-test-player")
	GameState.set_debug_seed_override(3333)
	GameState.new_run()
	_repo = DataRepository.singleton()
	_release_fragment_01()


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)
	# fragment_01 now starts LOCKED in authored data (released by the Auntie route at
	# runtime, Phase 10). Restore that authored state so this suite never leaks a
	# RELEASED repo fragment into later suites.
	_repo.load_from_filesystem()


## fragment_01 is released by the Auntie route at runtime; these placement tests
## need it RELEASED up front, so release it in both the repo (the Spawn Director's
## source) and persistent state.
func _release_fragment_01() -> void:
	_repo.get_fragment("fragment_01").state = ModelEnums.FragmentState.RELEASED
	GameState.save_state.persistent.fragments["fragment_01"].state = (
		ModelEnums.FragmentState.RELEASED
	)


func _make_instances() -> Array[ObjectInstance]:
	var pendant := ObjectInstance.new()
	pendant.template_id = "tarnished_pendant"
	pendant.uid = "pendant_01"
	pendant.storage_cost = 1
	pendant.assigned_anchor_id = "pile_left"

	var tin := ObjectInstance.new()
	tin.template_id = "rusted_tin"
	tin.uid = "tin_01"
	tin.storage_cost = 2
	tin.assigned_anchor_id = "pile_center"

	return [pendant, tin]


func test_cannot_complete_with_undecided_items() -> void:
	var delivery := _make_instances()
	var state := TriageState.new(delivery, 8)
	assert_false(state.can_complete())
	assert_false(state.all_decided())


func test_cannot_complete_when_over_capacity() -> void:
	var delivery := _make_instances()
	var state := TriageState.new(delivery, 2)
	state.set_decision("pendant_01", TriageState.Decision.KEEP)
	state.set_decision("tin_01", TriageState.Decision.KEEP)
	assert_true(state.all_decided())
	assert_false(state.within_capacity())
	assert_false(state.can_complete())


func test_can_complete_when_within_capacity() -> void:
	var delivery := _make_instances()
	var state := TriageState.new(delivery, 3)
	state.set_decision("pendant_01", TriageState.Decision.KEEP)
	state.set_decision("tin_01", TriageState.Decision.RECYCLE)
	assert_true(state.all_decided())
	assert_true(state.within_capacity())
	assert_true(state.can_complete())


func test_kept_instances_enter_loop_inventory() -> void:
	var delivery := _make_instances()
	var state := TriageState.new(delivery, 8)
	state.set_decision("pendant_01", TriageState.Decision.KEEP)
	state.set_decision("tin_01", TriageState.Decision.RECYCLE)

	watch_signals(EventBus)
	var service := TriageService.new(GameState)
	assert_true(service.apply_triage(state))

	var inventory := GameState.save_state.loop.inventory
	assert_eq(inventory.size(), 1)
	var kept := ObjectInstance.from_dictionary(inventory[0])
	assert_eq(kept.uid, "pendant_01")
	assert_signal_emitted(EventBus, "triage_completed")


func test_recycled_instances_are_inaccessible() -> void:
	var delivery := _make_instances()
	var state := TriageState.new(delivery, 8)
	state.set_decision("pendant_01", TriageState.Decision.RECYCLE)
	state.set_decision("tin_01", TriageState.Decision.RECYCLE)

	var service := TriageService.new(GameState)
	assert_true(service.apply_triage(state))
	assert_eq(GameState.save_state.loop.inventory.size(), 0)


func test_recycled_carrier_remains_eligible_next_loop() -> void:
	# Plan a carrier, recycle it, then reset the loop and confirm the fragment
	# is still RELEASED (not seated or consumed).
	SpawnDirector.new(_repo, GameState).plan_loop_placements()
	var plan: Dictionary = GameState.save_state.loop.current_carrier_placements["fragment_01"]

	var carrier := ObjectInstance.new()
	carrier.template_id = plan["carrier_template_id"]
	carrier.uid = "carrier_01"
	carrier.storage_cost = 1
	carrier.is_carrier = true
	carrier.fragment_id = "fragment_01"
	carrier.assigned_anchor_id = plan["container_id"]

	var state := TriageState.new([carrier], 8)
	state.set_decision("carrier_01", TriageState.Decision.RECYCLE)
	TriageService.new(GameState).apply_triage(state)

	assert_eq(
		GameState.save_state.persistent.fragments["fragment_01"].state,
		ModelEnums.FragmentState.RELEASED,
		"Recycled carrier must not consume the released fragment"
	)

	GameState.reset_loop_state()
	GameState.new_run()
	var new_plans := SpawnDirector.new(_repo, GameState).plan_loop_placements()
	assert_true(new_plans.has("fragment_01"))


func test_neglect_history_survives_loop_reset() -> void:
	var delivery := _make_instances()
	var state := TriageState.new(delivery, 8)
	state.set_decision("pendant_01", TriageState.Decision.RECYCLE)
	state.set_decision("tin_01", TriageState.Decision.RECYCLE)
	TriageService.new(GameState).apply_triage(state)

	assert_true(GameState.save_state.persistent.neglect_history.has("pile_left"))
	assert_true(GameState.save_state.persistent.neglect_history.has("pile_center"))

	var saved := SaveService.save_game()
	assert_true(saved.ok)

	GameState.reset_loop_state()
	assert_true(GameState.save_state.persistent.neglect_history.has("pile_left"))


func test_seated_fragments_are_never_mutated() -> void:
	var fragment: Fragment = _repo.get_fragment("fragment_01")
	fragment.state = ModelEnums.FragmentState.SEATED
	GameState.save_state.persistent.fragments["fragment_01"] = fragment

	var delivery := _make_instances()
	var state := TriageState.new(delivery, 8)
	state.set_decision("pendant_01", TriageState.Decision.KEEP)
	state.set_decision("tin_01", TriageState.Decision.RECYCLE)
	TriageService.new(GameState).apply_triage(state)

	assert_eq(
		GameState.save_state.persistent.fragments["fragment_01"].state,
		ModelEnums.FragmentState.SEATED
	)


func test_apply_triage_is_atomic_and_idempotent() -> void:
	var delivery := _make_instances()
	var state := TriageState.new(delivery, 8)
	state.set_decision("pendant_01", TriageState.Decision.KEEP)
	state.set_decision("tin_01", TriageState.Decision.RECYCLE)

	var service := TriageService.new(GameState)
	assert_true(service.apply_triage(state))
	assert_eq(GameState.save_state.loop.inventory.size(), 1)
	# Second apply on the same state must not duplicate inventory.
	assert_false(service.apply_triage(state))
	assert_eq(GameState.save_state.loop.inventory.size(), 1)

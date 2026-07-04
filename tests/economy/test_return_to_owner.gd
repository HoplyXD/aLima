extends GutTest
## Return-to-owner outcomes (P14.4/P14.7, DISP-R3, CLAUDE.md §4-B/C). A return
## resolves an authored non-fragment reward and story flag and provably cannot grant
## a fragment.

const TEST_SAVE := "user://test_return_save.json"
const TEST_TEMP := "user://test_return_save.tmp"

var _repo: DataRepository


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()
	GameState.initialize("return-player")
	GameState.new_run()
	GameState.save_state.loop.current_day = 2


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _add_judged(uid: String, template_id: String) -> void:
	var inst := ObjectInstance.new()
	inst.template_id = template_id
	inst.uid = uid
	inst.condition = 85.0
	inst.state = ModelEnums.ObjState.CLEAN
	inst.authenticity = ModelEnums.Verdict.AUTHENTIC
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func _inventory_has(uid: String) -> bool:
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == uid:
			return true
	return false


func _seated_count() -> int:
	var n := 0
	for fid in GameState.save_state.persistent.fragments.keys():
		if GameState.save_state.persistent.fragments[fid].state == ModelEnums.FragmentState.SEATED:
			n += 1
	return n


# --- Eligibility --------------------------------------------------------------


func test_return_only_offered_for_an_identified_owner() -> void:
	_add_judged("owned1", "rusted_tin")  # has an authored owner (scavenger)
	_add_judged("owned2", "tarnished_pendant")  # no authored owner
	assert_true(
		DispositionRouter.eligible_dispositions("owned1").has(DispositionRouter.Disposition.RETURN),
		"an owned object can be returned"
	)
	assert_false(
		DispositionRouter.eligible_dispositions("owned2").has(DispositionRouter.Disposition.RETURN),
		"an ownerless object cannot be returned (DISP-R3)"
	)


# --- Outcome (DISP-R3) --------------------------------------------------------


func test_return_grants_reward_and_records_return() -> void:
	_add_judged("tin1", "rusted_tin")
	watch_signals(EventBus)
	var result := DispositionRouter.dispose("tin1", DispositionRouter.Disposition.RETURN)
	assert_true(result.ok)
	assert_false(_inventory_has("tin1"), "the returned object leaves loop inventory")
	assert_true(
		GameState.save_state.persistent.story_clues.has("scavenger_gratitude_clue"),
		"the authored knowledge reward is granted"
	)
	assert_true(
		GameState.save_state.persistent.dialogue_flags.has("returned_scavenger_tin"),
		"the return story flag is set"
	)
	assert_eq(GameState.save_state.persistent.returns.size(), 1, "the return persists (DISP-R6)")
	assert_signal_emitted(EventBus, "object_returned")


# --- Invariant: a return NEVER grants a fragment (§4-B/C) --------------------


func test_return_cannot_change_any_fragment_state() -> void:
	# Force a known fragment lifecycle, then return an object and prove nothing moved.
	GameState.save_state.persistent.fragments["fragment_01"].state = (
		ModelEnums.FragmentState.RELEASED
	)
	var seated_before := _seated_count()
	_add_judged("tin1", "rusted_tin")

	DispositionRouter.dispose("tin1", DispositionRouter.Disposition.RETURN)

	assert_eq(
		GameState.save_state.persistent.fragments["fragment_01"].state,
		ModelEnums.FragmentState.RELEASED,
		"a return never advances a fragment toward SEATED (§4-B/C)"
	)
	assert_eq(_seated_count(), seated_before, "no fragment becomes seated through a return")


func test_return_is_idempotent() -> void:
	_add_judged("tin1", "rusted_tin")
	assert_true(DispositionRouter.dispose("tin1", DispositionRouter.Disposition.RETURN).ok)
	assert_false(
		DispositionRouter.dispose("tin1", DispositionRouter.Disposition.RETURN).ok,
		"the same object cannot be returned twice (DISP-R5)"
	)

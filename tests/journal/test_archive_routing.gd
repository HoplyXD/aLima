extends GutTest
## End-to-end archive routing boundary tests (CLAUDE.md §4-F, JRN-R3, DISP-R4).
## Gold/Master → museum; Purple-and-below → journal; invalid dispositions rejected.

const TEST_SAVE := "user://test_archive_routing_save.json"
const TEST_TEMP := "user://test_archive_routing_save.tmp"


func before_each() -> void:
	SaveService.set_save_paths(TEST_SAVE, TEST_TEMP)
	SaveService.delete_save_files()
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("archive-player")
	GameState.new_run()


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func _add_judged(uid: String, template_id: String) -> void:
	var inst := ObjectInstance.new()
	inst.uid = uid
	inst.template_id = template_id
	inst.condition = 90.0
	inst.state = ModelEnums.ObjState.CLEAN
	inst.authenticity = ModelEnums.Verdict.AUTHENTIC
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func test_gold_preserve_routes_to_museum() -> void:
	_add_judged("g1", "oton_death_mask")

	var result := DispositionRouter.dispose("g1", DispositionRouter.Disposition.PRESERVE)

	assert_true(result.ok)
	assert_true(result.outcome_id.contains("oton_death_mask"))
	assert_true(
		GameState.save_state.persistent.museum_entries.has(result.outcome_id),
		"Gold PRESERVE creates a MuseumEntry"
	)
	assert_false(GameState.save_state.persistent.journal_entries.has("oton_death_mask"))


func test_purple_journal_routes_to_journal_not_museum() -> void:
	_add_judged("c1", "rusted_tin")

	var result := DispositionRouter.dispose("c1", DispositionRouter.Disposition.JOURNAL)

	assert_true(result.ok)
	assert_true(GameState.save_state.persistent.journal_entries.has("rusted_tin"))
	assert_true(GameState.save_state.persistent.museum_entries.is_empty())


func test_gold_cannot_be_journaled() -> void:
	_add_judged("g1", "oton_death_mask")

	var result := DispositionRouter.dispose("g1", DispositionRouter.Disposition.JOURNAL)

	assert_false(result.ok, "Gold finds cannot be journaled")


func test_purple_cannot_be_preserved() -> void:
	_add_judged("c1", "rusted_tin")

	var result := DispositionRouter.dispose("c1", DispositionRouter.Disposition.PRESERVE)

	assert_false(result.ok, "Purple-and-below cannot be preserved")

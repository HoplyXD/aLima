extends GutTest
## Tests for JournalService: stable journal-entry updates (P9.2) and rarity
## routing (P9.3). Gold-and-above route to the museum; Purple-and-below are
## archived as a single, non-duplicated journal entry.

const JournalServiceScript := preload("res://scripts/journal/journal_service.gd")

# tarnished_pendant is Blue (journal rarity) in the slice data.
const JOURNAL_TEMPLATE := "tarnished_pendant"
const SOFT_CLOTH := "soft_cloth"
const GOLD_TEMPLATE := "gold_relic_test"

var _journal: Node = null


func before_each() -> void:
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("test-player")
	SaveService.set_save_paths("user://test_save.json", "user://test_save.tmp")
	SaveService.delete_save_files()
	_journal = JournalServiceScript.new()
	add_child_autofree(_journal)


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths("user://save.json", "user://save.tmp")


func _add_instance(uid: String, template_id: String, condition: float) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.uid = uid
	inst.template_id = template_id
	inst.condition = condition
	inst.state = ModelEnums.ObjState.CLEAN
	GameState.save_state.loop.inventory.append(inst.to_dictionary())
	return inst


func _inject_gold_template() -> void:
	var t := ScrapObjectTemplate.new()
	t.id = GOLD_TEMPLATE
	t.display_name = "Test Gold Relic"
	t.category = "mechanical"
	t.base_rarity = ModelEnums.Rarity.GOLD
	t.materials = ["brass"]
	t.tags = ["small"]
	t.base_value_range = Vector2(100, 200)
	DataRepository.singleton().scrap_object_templates[GOLD_TEMPLATE] = t


# --- Rarity routing (P9.3) -------------------------------------------------


func test_is_journal_rarity_boundary() -> void:
	assert_true(JournalServiceScript.is_journal_rarity(ModelEnums.Rarity.WHITE))
	assert_true(JournalServiceScript.is_journal_rarity(ModelEnums.Rarity.GREEN))
	assert_true(JournalServiceScript.is_journal_rarity(ModelEnums.Rarity.BLUE))
	assert_true(JournalServiceScript.is_journal_rarity(ModelEnums.Rarity.PURPLE))
	assert_false(JournalServiceScript.is_journal_rarity(ModelEnums.Rarity.GOLD))


func test_gold_rarity_does_not_create_journal_entry() -> void:
	_inject_gold_template()
	var inst := _add_instance("obj_gold", GOLD_TEMPLATE, 100.0)

	var wrote: bool = _journal.record_restoration(inst, SOFT_CLOTH)

	assert_false(wrote)
	assert_eq(GameState.save_state.persistent.journal_entries.size(), 0)


# --- Entry creation and update (P9.2) --------------------------------------


func test_restoration_creates_single_entry() -> void:
	_add_instance("obj_1", JOURNAL_TEMPLATE, 80.0)

	EventBus.restoration_completed.emit("obj_1", 80.0, SOFT_CLOTH)

	var entries: Dictionary = GameState.save_state.persistent.journal_entries
	assert_eq(entries.size(), 1)
	assert_true(entries.has(JOURNAL_TEMPLATE))
	var entry: JournalEntry = entries[JOURNAL_TEMPLATE]
	assert_eq(entry.template_id, JOURNAL_TEMPLATE)
	assert_eq(entry.best_condition, 80)
	assert_false(entry.materials.is_empty())


func test_repeated_restoration_keeps_best_condition_and_no_duplicate() -> void:
	var inst := _add_instance("obj_1", JOURNAL_TEMPLATE, 60.0)

	_journal.record_restoration(inst, SOFT_CLOTH)
	inst.condition = 90.0
	_journal.record_restoration(inst, SOFT_CLOTH)
	inst.condition = 70.0
	_journal.record_restoration(inst, SOFT_CLOTH)

	var entries: Dictionary = GameState.save_state.persistent.journal_entries
	assert_eq(entries.size(), 1)
	var entry: JournalEntry = entries[JOURNAL_TEMPLATE]
	assert_eq(entry.best_condition, 90)


func test_scan_updates_annotations_without_touching_uncle_notes() -> void:
	var inst := _add_instance("obj_1", JOURNAL_TEMPLATE, 100.0)
	_journal.record_restoration(inst, SOFT_CLOTH)

	# Author an uncle note on the existing entry.
	var entry: JournalEntry = GameState.save_state.persistent.journal_entries[JOURNAL_TEMPLATE]
	entry.uncle_notes = "He kept this in the top drawer."

	# Stash a scanned record snapshot keyed by template_id.
	var record := ScannedRecord.new()
	record.template_id = JOURNAL_TEMPLATE
	record.instance_id = "obj_1"
	record.verdict = ModelEnums.Verdict.AUTHENTIC
	record.response_snapshot = {
		"type": "silver pendant",
		"period": "1900s",
		"condition_note": "light tarnish",
		"modification_signs": ["replaced clasp"],
	}
	GameState.save_state.persistent.scanned_records[JOURNAL_TEMPLATE] = record

	_journal.record_scan(inst)

	entry = GameState.save_state.persistent.journal_entries[JOURNAL_TEMPLATE]
	assert_string_contains(entry.ai_annotations, "silver pendant")
	assert_eq(entry.counterfeit_indicators, ["replaced clasp"] as Array[String])
	assert_eq(entry.uncle_notes, "He kept this in the top drawer.")
	assert_eq(GameState.save_state.persistent.journal_entries.size(), 1)


func test_scan_creates_entry_when_none_exists() -> void:
	var inst := _add_instance("obj_1", JOURNAL_TEMPLATE, 100.0)
	var record := ScannedRecord.new()
	record.template_id = JOURNAL_TEMPLATE
	record.instance_id = "obj_1"
	record.verdict = ModelEnums.Verdict.UNCERTAIN
	record.response_snapshot = {"type": "pendant", "period": "1900s", "condition_note": "clean"}
	GameState.save_state.persistent.scanned_records[JOURNAL_TEMPLATE] = record

	var wrote: bool = _journal.record_scan(inst)

	assert_true(wrote)
	assert_eq(GameState.save_state.persistent.journal_entries.size(), 1)


# --- Persistence (P9.6) ----------------------------------------------------


func test_entry_persists_through_save_and_reload() -> void:
	var inst := _add_instance("obj_1", JOURNAL_TEMPLATE, 88.0)
	_journal.record_restoration(inst, SOFT_CLOTH)

	var loaded := SaveService.load_game()
	assert_true(loaded.ok, "reload should succeed")

	var entries: Dictionary = GameState.save_state.persistent.journal_entries
	assert_true(entries.has(JOURNAL_TEMPLATE))
	assert_eq((entries[JOURNAL_TEMPLATE] as JournalEntry).best_condition, 88)


func test_entry_survives_loop_reset() -> void:
	var inst := _add_instance("obj_1", JOURNAL_TEMPLATE, 75.0)
	_journal.record_restoration(inst, SOFT_CLOTH)

	GameState.save_state.reset_loop_state()

	assert_true(GameState.save_state.persistent.journal_entries.has(JOURNAL_TEMPLATE))
	assert_true(GameState.save_state.loop.inventory.is_empty())

extends GutTest
## Tests for JournalService: stable entries, rarity routing, and scanner updates.

const JournalServiceScript := preload("res://scripts/journal/journal_service.gd")

var _service = null


func before_each() -> void:
	DataRepository.singleton().load_from_filesystem()
	GameState.initialize("test-player")
	SaveService.set_save_paths("user://test_save.json", "user://test_save.tmp")
	SaveService.delete_save_files()
	_service = JournalServiceScript.new()
	add_child_autofree(_service)


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths("user://save.json", "user://save.tmp")


func _make_instance(template_id: String, uid: String, condition: float = 50.0) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.template_id = template_id
	inst.uid = uid
	inst.condition = condition
	inst.state = ModelEnums.ObjState.CLEAN
	inst.is_carrier = false
	inst.fragment_id = ""
	inst.value = 100
	return inst


func _add_to_inventory(inst: ObjectInstance) -> void:
	GameState.save_state.loop.inventory.append(inst.to_dictionary())


func _get_entry(template_id: String) -> JournalEntry:
	return GameState.save_state.persistent.journal_entries.get(template_id) as JournalEntry


func test_restoration_creates_one_journal_entry() -> void:
	var inst := _make_instance("tarnished_pendant", "inst_001", 75.0)
	_add_to_inventory(inst)

	_service.record_restoration(inst)

	var entry: JournalEntry = _get_entry("tarnished_pendant")
	assert_not_null(entry, "A journal entry should be created for a restored object")
	assert_eq(entry.template_id, "tarnished_pendant")
	assert_eq(entry.origin, "Tarnished Pendant")
	assert_eq(entry.best_condition, 75)
	assert_false(entry.uncle_notes.is_empty(), "Uncle notes should be set")


func test_repeated_restoration_updates_the_same_entry() -> void:
	var inst := _make_instance("tarnished_pendant", "inst_001", 60.0)
	_add_to_inventory(inst)
	_service.record_restoration(inst)

	var inst2 := _make_instance("tarnished_pendant", "inst_002", 90.0)
	_add_to_inventory(inst2)
	_service.record_restoration(inst2)

	assert_eq(GameState.save_state.persistent.journal_entries.size(), 1)
	var entry: JournalEntry = _get_entry("tarnished_pendant")
	assert_eq(entry.best_condition, 90)


func test_scanner_verdict_updates_the_same_entry() -> void:
	var inst := _make_instance("tarnished_pendant", "inst_001", 80.0)
	_add_to_inventory(inst)
	_service.record_restoration(inst)

	# Pre-populate a scanned record so the service has annotations to read.
	var record := ScannedRecord.new()
	record.template_id = "tarnished_pendant"
	record.instance_id = "inst_001"
	record.verdict = ModelEnums.Verdict.AUTHENTIC
	record.response_snapshot = {
		"type": "pendant",
		"period": "early 20th century",
		"materials": ["silver"],
		"markings": ["clasp wear"],
		"condition_note": "Clean.",
		"cultural_relevance": "Test.",
		"modification_signs": [],
		"confidence": "medium"
	}
	GameState.save_state.persistent.scanned_records["tarnished_pendant"] = record

	_service.record_scan_verdict(inst, "authentic")

	var entry: JournalEntry = _get_entry("tarnished_pendant")
	assert_eq(entry.player_verdict, ModelEnums.Verdict.AUTHENTIC)
	assert_true(
		entry.ai_annotations.contains("Type: pendant"), "Scanner annotations should be stored"
	)


func test_purple_and_below_route_to_journal_entry() -> void:
	# Tarnished pendant is blue rarity (purple-and-below).
	var inst := _make_instance("tarnished_pendant", "inst_001", 50.0)
	_add_to_inventory(inst)
	_service.record_restoration(inst)
	assert_not_null(_get_entry("tarnished_pendant"))


func test_gold_object_does_not_create_journal_entry() -> void:
	# Create a fake gold template in repository data by mutating the loaded template.
	var repo := DataRepository.singleton()
	var template: ScrapObjectTemplate = repo.get_template("tarnished_pendant")
	var original_rarity: int = template.base_rarity
	template.base_rarity = ModelEnums.Rarity.GOLD

	var inst := _make_instance("tarnished_pendant", "inst_001", 50.0)
	_add_to_inventory(inst)
	_service.record_restoration(inst)

	assert_null(_get_entry("tarnished_pendant"), "Gold finds should not create journal entries")

	template.base_rarity = original_rarity


func test_carrier_fragment_does_not_create_journal_entry() -> void:
	var inst := _make_instance("tarnished_pendant", "inst_001", 50.0)
	inst.is_carrier = true
	inst.fragment_id = "fragment_01"
	_add_to_inventory(inst)
	_service.record_restoration(inst)

	assert_null(
		_get_entry("tarnished_pendant"), "Carrier fragments should route to museum, not journal"
	)


func test_no_loop_inventory_leaks_into_persistent_state() -> void:
	var inst := _make_instance("tarnished_pendant", "inst_001", 50.0)
	_add_to_inventory(inst)
	_service.record_restoration(inst)

	var entry: JournalEntry = _get_entry("tarnished_pendant")
	assert_eq(entry.template_id, "tarnished_pendant")
	# The entry must not store instance-level loop data such as uid or carrier status.
	var raw: Dictionary = entry.to_dictionary()
	assert_false(raw.has("uid"), "Journal entry must not store instance uid")
	assert_false(raw.has("is_carrier"), "Journal entry must not store carrier status")


func test_restoration_completed_event_creates_entry() -> void:
	var inst := _make_instance("tarnished_pendant", "inst_001", 50.0)
	_add_to_inventory(inst)

	EventBus.restoration_completed.emit("inst_001", 50.0, "soft_cloth")

	assert_not_null(_get_entry("tarnished_pendant"))


func test_scanner_verdict_committed_event_updates_entry() -> void:
	var inst := _make_instance("tarnished_pendant", "inst_001", 50.0)
	_add_to_inventory(inst)
	_service.record_restoration(inst)

	var record := ScannedRecord.new()
	record.template_id = "tarnished_pendant"
	record.instance_id = "inst_001"
	record.verdict = ModelEnums.Verdict.REPLICA
	record.response_snapshot = {"type": "pendant", "confidence": "low"}
	GameState.save_state.persistent.scanned_records["tarnished_pendant"] = record

	EventBus.scanner_verdict_committed.emit("inst_001", "replica")

	var entry: JournalEntry = _get_entry("tarnished_pendant")
	assert_eq(entry.player_verdict, ModelEnums.Verdict.REPLICA)

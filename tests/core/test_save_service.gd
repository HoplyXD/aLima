extends GutTest

## Tests for SaveService: isolated-path injection, schema validation, atomic
## writes, strict load validation, migration, slot selection/summary, and
## partition separation. Uses an isolated save path (set_save_paths) so it never
## writes the developer's real save.


func before_each() -> void:
	SaveService.set_save_paths("user://test_save.json", "user://test_save.tmp")
	SaveService.delete_save_files()
	GameState.initialize("save-test-player")


func after_each() -> void:
	SaveService.delete_save_files()
	SaveService.set_save_paths(SaveService.DEFAULT_SAVE_PATH, SaveService.DEFAULT_TEMP_PATH)


func test_save_and_load_round_trip() -> void:
	GameState.save_state.persistent.techniques_learned.append("pendant_cleaning")
	GameState.save_state.loop.money = 500
	var save_result := SaveService.save_game()
	assert_true(save_result.ok, "Save should succeed: %s" % save_result.get("error", ""))

	GameState.initialize("other-player")
	var load_result := SaveService.load_game()
	assert_true(load_result.ok, "Load should succeed: %s" % load_result.get("error", ""))
	assert_eq(GameState.player_id, "save-test-player")
	assert_eq(GameState.save_state.persistent.techniques_learned[0], "pendant_cleaning")
	assert_eq(GameState.save_state.loop.money, 500)


func test_run_seed_and_loop_index_round_trip() -> void:
	GameState.new_run(12345)
	GameState.save_state.loop.money = 100
	var save_result := SaveService.save_game()
	assert_true(save_result.ok, "Save should succeed: %s" % save_result.get("error", ""))

	GameState.initialize("other-player")
	var load_result := SaveService.load_game()
	assert_true(load_result.ok, "Load should succeed: %s" % load_result.get("error", ""))
	assert_eq(GameState.run_seed, 12345, "run_seed restores from save")
	assert_eq(GameState.loop_index, 1, "loop_index restores from save")
	assert_eq(GameState.save_state.run_seed, 12345)
	assert_eq(GameState.save_state.loop_index, 1)


func test_v1_migration_injects_run_seed_and_loop_index() -> void:
	var v1 := {"schema_version": 1, "player_id": "legacy", "persistent": {}, "loop": {}}
	_write_save(v1)
	var load_result := SaveService.load_game()
	assert_true(
		load_result.ok, "v1 save should migrate and load: %s" % load_result.get("error", "")
	)
	assert_eq(load_result.schema_version, 3, "Load reports the current schema")
	assert_eq(GameState.save_state.schema_version, 3)
	assert_eq(GameState.save_state.run_seed, 0, "v1 migration injects run_seed=0")
	assert_eq(GameState.save_state.loop_index, 0, "v1 migration injects loop_index=0")
	assert_true(
		GameState.save_state.persistent.tutorial_completed,
		"Chained v1 migration also marks the tutorial completed"
	)


func test_v2_migration_marks_tutorial_completed() -> void:
	# Pre-v3 saves predate Day 0 and must never enter the tutorial.
	var v2 := {
		"schema_version": 2,
		"player_id": "veteran",
		"run_seed": 7,
		"loop_index": 2,
		"persistent": {"techniques_learned": ["pendant_cleaning"]},
		"loop": {"money": 40},
	}
	_write_save(v2)
	var load_result := SaveService.load_game()
	assert_true(
		load_result.ok, "v2 save should migrate and load: %s" % load_result.get("error", "")
	)
	assert_eq(GameState.save_state.schema_version, 3)
	assert_true(GameState.save_state.persistent.tutorial_completed)
	assert_eq(GameState.save_state.persistent.tutorial_step, "")
	assert_eq(GameState.save_state.persistent.player_name, "")
	assert_eq(
		GameState.save_state.persistent.techniques_learned[0],
		"pendant_cleaning",
		"Migration preserves existing persistent knowledge"
	)


func test_tutorial_fields_round_trip() -> void:
	GameState.save_state.persistent.player_name = "Maverick"
	GameState.save_state.persistent.tutorial_completed = false
	GameState.save_state.persistent.tutorial_step = "restore_artifact"
	var save_result := SaveService.save_game()
	assert_true(save_result.ok, "Save should succeed: %s" % save_result.get("error", ""))

	GameState.initialize("other-player")
	var load_result := SaveService.load_game()
	assert_true(load_result.ok, "Load should succeed: %s" % load_result.get("error", ""))
	assert_eq(GameState.save_state.persistent.player_name, "Maverick")
	assert_false(
		GameState.save_state.persistent.tutorial_completed,
		"A fresh (non-migrated) save keeps tutorial_completed false until Day 0 ends"
	)
	assert_eq(GameState.save_state.persistent.tutorial_step, "restore_artifact")


func test_flashlight_on_round_trips_through_save() -> void:
	GameState.save_state.loop.flashlight_on = true
	var save_result := SaveService.save_game()
	assert_true(save_result.ok, "Save should succeed: %s" % save_result.get("error", ""))

	GameState.initialize("other-player")
	var load_result := SaveService.load_game()
	assert_true(load_result.ok, "Load should succeed: %s" % load_result.get("error", ""))
	assert_true(GameState.save_state.loop.flashlight_on, "flashlight_on survives save/load")


func test_rejects_malformed_save_file() -> void:
	var file := FileAccess.open(SaveService.save_path, FileAccess.WRITE)
	file.store_string("{not valid json")
	file.close()
	var load_result := SaveService.load_game()
	assert_false(load_result.ok)


func test_invalid_temp_does_not_replace_valid_save() -> void:
	GameState.save_state.loop.money = 100
	var first := SaveService.save_game()
	assert_true(first.ok)

	# Corrupt the temp file directly; the service must refuse to promote it so the
	# previous valid save.json survives (SAVE-R6).
	var temp_file := FileAccess.open(SaveService.temp_path, FileAccess.WRITE)
	temp_file.store_string("{bad}")
	temp_file.close()

	var load_result := SaveService.load_game()
	assert_true(load_result.ok, "Original valid save remains readable")
	assert_eq(GameState.save_state.loop.money, 100)


func test_load_recovers_from_missing_optional_fields() -> void:
	var minimal := {
		"schema_version": 2,
		"player_id": "minimal",
		"run_seed": 0,
		"loop_index": 0,
		"persistent": {},
		"loop": {}
	}
	_write_save(minimal)
	var load_result := SaveService.load_game()
	assert_true(
		load_result.ok, "Missing optional fields should default: %s" % load_result.get("error", "")
	)
	assert_eq(GameState.save_state.loop.current_day, 1)
	assert_eq(GameState.save_state.loop.current_hour, 7)
	assert_eq(GameState.save_state.loop.money, 0)


func test_load_rejects_out_of_range_day() -> void:
	GameState.save_state.loop.money = 42
	SaveService.save_game()  # establish a known-good in-memory + on-disk state
	_write_save(
		{
			"schema_version": 2,
			"player_id": "x",
			"run_seed": 0,
			"loop_index": 0,
			"persistent": {},
			"loop": {"current_day": 9}
		}
	)
	var load_result := SaveService.load_game()
	assert_false(load_result.ok, "current_day=9 is out of range and must be rejected")
	assert_eq(GameState.save_state.loop.money, 42, "A failed load leaves in-memory state untouched")


func test_load_rejects_unknown_fragment_state_enum() -> void:
	# The fragment is otherwise complete, so the unknown enum string is the only
	# fault and must be caught rather than silently coerced to LOCKED.
	var bad := {
		"schema_version": 2,
		"player_id": "x",
		"run_seed": 0,
		"loop_index": 0,
		"persistent":
		{
			"fragments":
			{
				"fragment_01":
				{
					"id": "fragment_01",
					"master_artifact_id": "master_artifact",
					"owning_character_id": "auntie",
					"case_slot_index": 0,
					"state": "bogus",
					"echo_set_ref": "demo_echo_set",
				}
			}
		},
		"loop": {},
	}
	_write_save(bad)
	var load_result := SaveService.load_game()
	assert_false(load_result.ok, "Unknown enum 'bogus' must not be silently accepted")


func test_load_rejects_non_numeric_scalar() -> void:
	_write_save(
		{
			"schema_version": 2,
			"player_id": "x",
			"run_seed": 0,
			"loop_index": 0,
			"persistent": {},
			"loop": {"money": "lots"}
		}
	)
	var load_result := SaveService.load_game()
	assert_false(load_result.ok, "A string where money expects a number must be rejected")


func test_load_rejects_non_numeric_run_seed() -> void:
	_write_save(
		{
			"schema_version": 2,
			"player_id": "x",
			"run_seed": "zero",
			"loop_index": 0,
			"persistent": {},
			"loop": {}
		}
	)
	var load_result := SaveService.load_game()
	assert_false(load_result.ok, "A string where run_seed expects a number must be rejected")


func test_partition_separation_keeps_loop_out_of_persistent() -> void:
	GameState.save_state.loop.inventory.append({"uid": "obj_1"})
	GameState.save_state.loop.money = 700
	var serialized := SaveService.serialize_state()
	var payload: Dictionary = serialized.payload
	assert_true(payload.has("persistent") and payload.has("loop"))
	assert_false(
		payload["persistent"].has("inventory"), "Loop inventory must not leak to persistent"
	)
	assert_false(payload["persistent"].has("money"), "Loop money must not leak to persistent")
	assert_true(payload["loop"].has("inventory"))


func test_migration_rejects_unsupported_future_schema() -> void:
	var future := {"schema_version": 99, "player_id": "x", "persistent": {}, "loop": {}}
	var migrated := SaveService.migrate_payload(future, 99)
	assert_false(migrated.ok)
	assert_true(migrated.error.find("unsupported future") >= 0)


func test_schema_validation_rejects_unsupported_version() -> void:
	var bad_save := SaveState.new()
	bad_save.schema_version = 99
	var result := bad_save.validate()
	assert_false(result.is_valid())
	assert_true(_errors_contain(result, "unsupported schema"))


# --- Slot tests ---------------------------------------------------------------


func test_slot_selection_uses_distinct_files() -> void:
	# Slot 0: known state.
	SaveService.select_slot(0)
	GameState.save_state.loop.money = 111
	SaveService.save_game()

	# Slot 1: different state.
	SaveService.select_slot(1)
	GameState.save_state.loop.money = 222
	SaveService.save_game()

	# Load slot 0 into fresh GameState.
	GameState.initialize("slot-test")
	SaveService.select_slot(0)
	var load0 := SaveService.load_game()
	assert_true(load0.ok, load0.get("error", ""))
	assert_eq(GameState.save_state.loop.money, 111)

	# Load slot 1 into fresh GameState.
	GameState.initialize("slot-test")
	SaveService.select_slot(1)
	var load1 := SaveService.load_game()
	assert_true(load1.ok, load1.get("error", ""))
	assert_eq(GameState.save_state.loop.money, 222)


func test_slot_summary_reads_metadata_without_full_load() -> void:
	SaveService.select_slot(0)
	GameState.new_run(4242)
	GameState.save_state.loop.current_day = 3
	GameState.save_state.loop.current_hour = 14
	GameState.save_state.loop.money = 777
	SaveService.save_game()

	var summary := SaveService.slot_summary(0)
	assert_eq(summary.get("run_seed"), 4242)
	assert_eq(summary.get("player_name"), "", "Summary exposes player_name (empty when unset)")
	assert_eq(summary.get("loop_index"), 1)
	assert_eq(summary.get("current_day"), 3)
	assert_eq(summary.get("current_hour"), 14)
	assert_eq(summary.get("money"), 777)
	assert_eq(SaveService.slot_summary(1), {}, "Empty slot returns empty summary")


func test_slot_exists_and_delete_slot() -> void:
	SaveService.select_slot(2)
	SaveService.save_game()
	assert_true(SaveService.slot_exists(2))
	SaveService.delete_slot(2)
	assert_false(SaveService.slot_exists(2))


func test_select_slot_out_of_range_is_ignored() -> void:
	SaveService.select_slot(0)
	var path_before := SaveService.save_path
	SaveService.select_slot(99)
	assert_eq(SaveService.save_path, path_before)


# --- Helpers ------------------------------------------------------------------


func _write_save(payload: Dictionary) -> void:
	var file := FileAccess.open(SaveService.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()


func _errors_contain(result: ValidationResult, snippet: String) -> bool:
	for err in result.errors():
		if err.find(snippet) >= 0:
			return true
	return false

extends GutTest

## Tests for SaveService: isolated-path injection, schema validation, atomic
## writes, strict load validation, migration, and partition separation. Uses an
## isolated save path (set_save_paths) so it never writes the developer's real save.


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
	var minimal := {"schema_version": 1, "player_id": "minimal", "persistent": {}, "loop": {}}
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
		{"schema_version": 1, "player_id": "x", "persistent": {}, "loop": {"current_day": 9}}
	)
	var load_result := SaveService.load_game()
	assert_false(load_result.ok, "current_day=9 is out of range and must be rejected")
	assert_eq(GameState.save_state.loop.money, 42, "A failed load leaves in-memory state untouched")


func test_load_rejects_unknown_fragment_state_enum() -> void:
	# The fragment is otherwise complete, so the unknown enum string is the only
	# fault and must be caught rather than silently coerced to LOCKED.
	var bad := {
		"schema_version": 1,
		"player_id": "x",
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
		{"schema_version": 1, "player_id": "x", "persistent": {}, "loop": {"money": "lots"}}
	)
	var load_result := SaveService.load_game()
	assert_false(load_result.ok, "A string where money expects a number must be rejected")


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

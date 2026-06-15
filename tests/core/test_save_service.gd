extends GutTest

## Tests for SaveService: schema validation, atomic writes, migration, and
## cleanup. Avoids depending on existing user save files.


func before_each() -> void:
	SaveService.delete_save_files()
	GameState.initialize("save-test-player")


func after_each() -> void:
	SaveService.delete_save_files()


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


func test_rejects_malformed_payload() -> void:
	var bad_json := "{not valid json"
	var temp_file := FileAccess.open(SaveService.TEMP_PATH, FileAccess.WRITE)
	temp_file.store_string(bad_json)
	temp_file.close()
	var load_result := SaveService.load_game()
	assert_false(load_result.ok)


func test_atomic_write_does_not_replace_valid_save_with_invalid_temp() -> void:
	GameState.save_state.loop.money = 100
	var first := SaveService.save_game()
	assert_true(first.ok)

	# Corrupt the temp file; the service should refuse to rename it.
	var temp_file := FileAccess.open(SaveService.TEMP_PATH, FileAccess.WRITE)
	temp_file.store_string("{bad}")
	temp_file.close()

	# Load should still read the original valid save.
	var load_result := SaveService.load_game()
	assert_true(load_result.ok, "Original save should remain readable")
	assert_eq(GameState.save_state.loop.money, 100)


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


func _errors_contain(result: ValidationResult, snippet: String) -> bool:
	for err in result.errors():
		if err.find(snippet) >= 0:
			return true
	return false

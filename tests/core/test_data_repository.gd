extends GutTest

## Tests for the DataRepository: valid slice fixtures, broken references,
## duplicate IDs, and accumulated validation errors. Covers P1.2 and P1.5.


func test_slice_fixtures_load_and_validate() -> void:
	var repo := DataRepository.new()
	var result := repo.load_from_filesystem()
	assert_true(result.is_valid(), "Slice fixtures should validate: %s" % str(result.errors()))
	assert_true(repo.is_loaded())
	assert_true(repo.scrap_object_templates.has("tarnished_pendant"))
	assert_true(repo.tool_definitions.has("soft_cloth"))
	assert_true(repo.technique_definitions.has("pendant_cleaning"))
	assert_true(repo.fragments.has("fragment_01"))
	assert_true(repo.master_artifacts.has("master_artifact_demo"))
	assert_true(repo.echo_sets.has("demo_echo_set"))
	assert_true(repo.placement_containers.has("pile_left"))
	assert_true(repo.scanner_cache_entries.has("tarnished_pendant"))
	assert_true(repo.object_instance_fixtures.size() >= 2)


func test_pendant_template_is_ordinary_no_carrier_flag() -> void:
	var repo := DataRepository.new()
	repo.load_from_filesystem()
	var template: ScrapObjectTemplate = repo.get_template("tarnished_pendant")
	assert_not_null(template)
	assert_eq(template.is_openable, true)
	assert_eq(template.required_clean_tool, "soft_cloth")


func test_runtime_instances_do_not_mutate_authored_templates() -> void:
	var repo := DataRepository.new()
	repo.load_from_filesystem()
	var template: ScrapObjectTemplate = repo.get_template("tarnished_pendant")
	var copy := ScrapObjectTemplate.from_dictionary(template.to_dictionary())
	copy.display_name = "Mutated"
	assert_ne(template.display_name, "Mutated")


func test_all_validation_errors_reported_together() -> void:
	var repo := _broken_repository()
	var result := repo.get_validation_result()
	assert_false(result.is_valid())
	var errors := result.errors()
	assert_gt(errors.size(), 1, "Expected multiple accumulated errors: %s" % str(errors))
	assert_true(_errors_contain(errors, "duplicate"), "Should report duplicate id")
	assert_true(_errors_contain(errors, "unknown tool"), "Should report broken tool ref")
	assert_true(_errors_contain(errors, "unknown echo"), "Should report broken echo ref")


func test_invalid_repository_state_is_not_published() -> void:
	var temp_root := _create_broken_temp_data()
	var repo := DataRepository.new()
	repo.data_root = temp_root
	var result := repo.load_from_filesystem()
	assert_false(result.is_valid())
	assert_false(repo.is_loaded())
	assert_eq(repo.scrap_object_templates.size(), 0)
	_cleanup_temp_data(temp_root)


func _broken_repository() -> DataRepository:
	var repo := DataRepository.new()
	repo._validation = ValidationResult.new()

	var dup := (
		ScrapObjectTemplate
		. from_dictionary(
			{
				"id": "tarnished_pendant",
				"display_name": "Duplicate",
				"category": "jewelry",
				"base_rarity": "blue",
				"weight_range": [1.0, 2.0],
				"materials": ["silver"],
				"tags": ["jewelry"],
				"is_openable": true,
				"openable_type": "pendant",
				"required_clean_tool": "missing_tool",
				"clean_minigame": "pendant_wipe",
				"base_value_range": [1, 2],
				"can_hold_temporal_echo": false,
			}
		)
	)
	repo.scrap_object_templates["tarnished_pendant"] = (
		ScrapObjectTemplate
		. from_dictionary(
			{
				"id": "tarnished_pendant",
				"display_name": "First",
				"category": "jewelry",
				"base_rarity": "blue",
				"weight_range": [1.0, 2.0],
				"materials": ["silver"],
				"tags": ["jewelry"],
				"is_openable": true,
				"openable_type": "pendant",
				"required_clean_tool": "soft_cloth",
				"clean_minigame": "pendant_wipe",
				"base_value_range": [1, 2],
				"can_hold_temporal_echo": false,
			}
		)
	)
	repo._add_record(repo.scrap_object_templates, dup.id, dup, "test", "template")
	repo.scrap_object_templates["bad_tool_template"] = (
		ScrapObjectTemplate
		. from_dictionary(
			{
				"id": "bad_tool_template",
				"display_name": "Bad Tool Template",
				"category": "jewelry",
				"base_rarity": "white",
				"weight_range": [1.0, 2.0],
				"materials": ["silver"],
				"tags": ["jewelry"],
				"is_openable": true,
				"openable_type": "pendant",
				"required_clean_tool": "missing_tool",
				"clean_minigame": "pendant_wipe",
				"base_value_range": [1, 2],
				"can_hold_temporal_echo": false,
			}
		)
	)
	repo.tool_definitions["soft_cloth"] = (
		ToolDefinition
		. from_dictionary(
			{
				"id": "soft_cloth",
				"display_name": "Soft Cloth",
				"enables": ["pendant_wipe"],
				"quality": 1,
				"cost": 0,
				"is_legacy": true,
			}
		)
	)
	repo.placement_containers["pile_left"] = (
		PlacementContainer
		. from_dictionary(
			{
				"id": "pile_left",
				"display_name": "Pile",
				"compatibility_tags": ["jewelry"],
				"capacity": 6,
				"is_locked_by_default": false,
				"unlock_requirement": "",
			}
		)
	)
	repo.fragments["fragment_bad"] = (
		Fragment
		. from_dictionary(
			{
				"id": "fragment_bad",
				"master_artifact_id": "missing_artifact",
				"owning_character_id": "missing_route",
				"case_slot_index": 0,
				"state": "released",
				"echo_set_ref": "missing_echo",
				"historical_fact_ref": "",
			}
		)
	)
	repo.master_artifacts["master_artifact_demo"] = (
		MasterArtifact
		. from_dictionary(
			{
				"id": "master_artifact_demo",
				"display_name": "Demo",
				"fragment_ids": ["fragment_bad"],
				"assembled_history_ref": "",
			}
		)
	)
	repo.echo_sets["demo_echo_set"] = (
		EchoSet
		. from_dictionary(
			{
				"id": "demo_echo_set",
				"hum_stream": "",
				"melody_stream": "",
				"voice_stream": "",
				"voice_caption": "caption",
				"heartbeat_stream": "",
			}
		)
	)
	repo._validate_cross_references()
	return repo


func _create_broken_temp_data() -> String:
	var root := "user://test_data"
	var dirs := ["objects", "artifacts", "echoes", "routes", "scanner-cache"]
	for dir_name in dirs:
		var dir_path := root.path_join(dir_name)
		DirAccess.make_dir_recursive_absolute(dir_path)
	# Write a syntactically valid JSON file with an unsupported schema version.
	var bad_file := root.path_join("objects/broken.json")
	var f := FileAccess.open(bad_file, FileAccess.WRITE)
	f.store_string('{"schema_version": 99}')
	f.close()
	return root


func _cleanup_temp_data(root: String) -> void:
	var dir := DirAccess.open(root)
	if dir != null:
		dir.include_navigational = false
		dir.list_dir_begin()
		var item := dir.get_next()
		while not item.is_empty():
			var full := root.path_join(item)
			if dir.current_is_dir():
				_cleanup_temp_data(full)
				DirAccess.remove_absolute(full)
			else:
				DirAccess.remove_absolute(full)
			item = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(root)


func _errors_contain(errors: Array[String], snippet: String) -> bool:
	for err in errors:
		if err.find(snippet) >= 0:
			return true
	return false

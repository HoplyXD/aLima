extends GutTest

## Tests for typed model classes: construction, validation, and round-trip
## serialization. Covers P1.1 model requirements.


func test_scrap_object_template_round_trip() -> void:
	var data := {
		"id": "tarnished_pendant",
		"display_name": "Tarnished Pendant",
		"category": "jewelry",
		"base_rarity": "blue",
		"weight_range": [8.0, 15.0],
		"materials": ["silver"],
		"tags": ["jewelry", "small"],
		"is_openable": true,
		"openable_type": "pendant",
		"required_clean_tool": "soft_cloth",
		"clean_minigame": "pendant_wipe",
		"base_value_range": [120, 280],
		"counterfeit_profile": "",
		"historical_fact_ref": "",
		"can_hold_temporal_echo": false,
	}
	var template := ScrapObjectTemplate.from_dictionary(data)
	assert_eq(template.id, "tarnished_pendant")
	assert_eq(template.base_rarity, ModelEnums.Rarity.BLUE)
	assert_eq(template.weight_range, Vector2(8.0, 15.0))

	var result := template.validate()
	assert_true(result.is_valid(), "Valid template should validate: %s" % str(result.errors()))

	var round := ScrapObjectTemplate.from_dictionary(template.to_dictionary())
	assert_eq(round.id, template.id)
	assert_eq(round.base_rarity, template.base_rarity)
	assert_eq(round.weight_range, template.weight_range)
	assert_eq(round.tags, template.tags)
	assert_eq(round.required_clean_tool, template.required_clean_tool)
	assert_eq(round.is_openable, template.is_openable)


func test_object_instance_round_trip() -> void:
	var data := {
		"template_id": "tarnished_pendant",
		"uid": "inst_001",
		"condition": 45.0,
		"state": "clean",
		"is_carrier": false,
		"fragment_id": "",
		"contents": "empty",
		"authenticity": "uncertain",
		"is_counterfeit_truth": false,
	}
	var inst := ObjectInstance.from_dictionary(data)
	assert_eq(inst.uid, "inst_001")
	assert_eq(inst.state, ModelEnums.ObjState.CLEAN)
	assert_true(inst.validate().is_valid())
	assert_eq(ObjectInstance.from_dictionary(inst.to_dictionary()).uid, "inst_001")


func test_carrier_instance_requires_fragment() -> void:
	var data := {
		"template_id": "tarnished_pendant",
		"uid": "inst_carrier",
		"condition": 80.0,
		"state": "clean",
		"is_carrier": true,
		"fragment_id": "",
		"contents": "empty",
		"authenticity": "unknown",
		"is_counterfeit_truth": false,
	}
	var inst := ObjectInstance.from_dictionary(data)
	var result := inst.validate()
	assert_false(result.is_valid())
	assert_true(_errors_contain(result, "carriers must specify"))


func test_fragment_validation() -> void:
	var data := {
		"id": "fragment_01",
		"master_artifact_id": "master_artifact_demo",
		"owning_character_id": "auntie",
		"case_slot_index": 0,
		"state": "released",
		"echo_set_ref": "demo_echo_set",
		"historical_fact_ref": "fact_01",
	}
	var fragment := Fragment.from_dictionary(data)
	assert_true(fragment.validate().is_valid())


func test_fragment_invalid_slot() -> void:
	var data := {
		"id": "fragment_bad",
		"master_artifact_id": "master_artifact_demo",
		"owning_character_id": "auntie",
		"case_slot_index": 7,
		"state": "released",
		"echo_set_ref": "demo_echo_set",
		"historical_fact_ref": "fact",
	}
	var fragment := Fragment.from_dictionary(data)
	var result := fragment.validate()
	assert_false(result.is_valid())
	assert_true(_errors_contain(result, "case_slot_index"))


func test_master_artifact_requires_exactly_five_fragments() -> void:
	var data := {
		"id": "ma_bad",
		"display_name": "Bad Artifact",
		"fragment_ids": ["a", "b", "c"],
		"assembled_history_ref": "history",
	}
	var ma := MasterArtifact.from_dictionary(data)
	var result := ma.validate()
	assert_false(result.is_valid())
	assert_true(_errors_contain(result, "exactly five"))


func test_master_artifact_requires_unique_fragments() -> void:
	var data := {
		"id": "ma_bad",
		"display_name": "Bad Artifact",
		"fragment_ids": ["a", "b", "c", "d", "a"],
		"assembled_history_ref": "history",
	}
	var ma := MasterArtifact.from_dictionary(data)
	var result := ma.validate()
	assert_false(result.is_valid())
	assert_true(_errors_contain(result, "duplicate"))


func test_echo_set_accepts_empty_audio_paths() -> void:
	var data := {
		"id": "demo_echo_set",
		"hum_stream": "",
		"melody_stream": "",
		"voice_stream": "",
		"voice_caption": "A caption.",
		"heartbeat_stream": "",
	}
	var echo := EchoSet.from_dictionary(data)
	assert_true(echo.validate().is_valid())
	assert_eq(echo.to_dictionary()["hum_stream"], "")


func test_journal_entry_and_museum_entry_round_trip() -> void:
	var j_data := {
		"template_id": "tarnished_pendant",
		"origin": "Panay region",
		"materials": ["silver"],
		"weight_range": [8.0, 15.0],
		"clean_method": "soft cloth wipe",
		"counterfeit_indicators": [],
		"historical_context": "placeholder",
		"value_range": [120, 280],
		"best_condition": 80,
		"best_sale": 250,
		"variants_found": [],
		"uncle_notes": "",
		"ai_annotations": "",
		"temporal_echoes_unlocked": [],
	}
	var entry := JournalEntry.from_dictionary(j_data)
	assert_true(entry.validate().is_valid())
	assert_eq(JournalEntry.from_dictionary(entry.to_dictionary()).best_sale, 250)

	var m_data := {
		"artifact_id": "fragment_01",
		"fact_card": "A fact.",
		"photo_ref": "",
		"timeline_entry": "",
		"regional_story": "",
		"character_memory_refs": [],
	}
	var museum := MuseumEntry.from_dictionary(m_data)
	assert_true(museum.validate().is_valid())


func test_tool_and_technique_validation() -> void:
	var tool := (
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
	assert_true(tool.validate().is_valid())

	var technique := (
		TechniqueDefinition
		. from_dictionary(
			{
				"id": "pendant_cleaning",
				"display_name": "Pendant Cleaning",
				"enables_minigame": "pendant_wipe",
				"learned_from": "shop",
			}
		)
	)
	assert_true(technique.validate().is_valid())


func test_save_state_split() -> void:
	var save := SaveState.new()
	save.persistent.techniques_learned.append("pendant_cleaning")
	save.loop.money = 500
	var copy := SaveState.from_dictionary(save.to_dictionary())
	assert_eq(copy.persistent.techniques_learned[0], "pendant_cleaning")
	assert_eq(copy.loop.money, 500)
	copy.reset_loop_state()
	assert_eq(copy.loop.money, 0)
	assert_eq(copy.persistent.techniques_learned.size(), 1)


func _errors_contain(result: ValidationResult, snippet: String) -> bool:
	for err in result.errors():
		if err.find(snippet) >= 0:
			return true
	return false

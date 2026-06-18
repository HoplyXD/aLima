extends GutTest
## Tests for the Surface Condition catalog (data/journal/surface_conditions.json)
## that the journal's Condition Guide renders: each condition belongs to a known
## category, maps to a real cleaning tool, and carries a placeholder swatch colour.

var _repo: DataRepository


func before_each() -> void:
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()


func test_repository_loads_with_journal_data() -> void:
	assert_true(_repo.is_loaded(), "repository should load with the journal catalog present")
	assert_false(_repo.surface_conditions.is_empty(), "condition catalog should not be empty")


func test_every_condition_has_a_real_cleaning_tool() -> void:
	for condition_id in _repo.surface_conditions.keys():
		var condition: SurfaceCondition = _repo.surface_conditions[condition_id]
		assert_false(condition.cleaning_tool.is_empty(), "%s needs a cleaning tool" % condition_id)
		assert_not_null(
			_repo.get_tool(condition.cleaning_tool),
			"%s references missing tool %s" % [condition_id, condition.cleaning_tool]
		)


func test_every_condition_has_a_known_category() -> void:
	for condition_id in _repo.surface_conditions.keys():
		var condition: SurfaceCondition = _repo.surface_conditions[condition_id]
		assert_true(
			SurfaceCondition.CATEGORY_LABELS.has(condition.category),
			"%s has unknown category '%s'" % [condition_id, condition.category]
		)


func test_quest_decal_types_are_documented() -> void:
	# Every decal type used by Auntie's quest objects should appear in the guide so
	# the player can look up its cleaning tool.
	for template_id in ["auntie_photo_faded", "auntie_frame_portrait", "auntie_halfphoto_torn"]:
		var template := _repo.get_template(template_id)
		assert_not_null(template, "missing template %s" % template_id)
		for decal in template.decals:
			assert_not_null(
				_repo.get_surface_condition(decal.type),
				"decal type '%s' on %s is not in the condition guide" % [decal.type, template_id]
			)


func test_conditions_sorted_is_stable_and_complete() -> void:
	var sorted := _repo.get_surface_conditions_sorted()
	assert_eq(sorted.size(), _repo.surface_conditions.size())
	var ids: Array = []
	for condition in sorted:
		ids.append((condition as SurfaceCondition).id)
	var expected := ids.duplicate()
	expected.sort()
	assert_eq(ids, expected, "guide order should be sorted by id")


func test_condition_color_parses_to_color() -> void:
	var dust: SurfaceCondition = _repo.get_surface_condition("dust")
	assert_not_null(dust)
	assert_true(dust.to_color() is Color)
	assert_ne(dust.color, "", "condition should carry a placeholder swatch colour")
	assert_eq(dust.category_label(), "Surface Soil", "dust is surface soil")

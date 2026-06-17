extends GutTest
## Tests for the Blemish Guide catalog (data/journal/blemishes.json) that the
## journal's Blemish Guide page renders: each blemish maps to a real cleaning tool
## and a placeholder swatch colour.

var _repo: DataRepository


func before_each() -> void:
	_repo = DataRepository.singleton()
	_repo.load_from_filesystem()


func test_repository_loads_with_journal_data() -> void:
	assert_true(_repo.is_loaded(), "repository should load with the journal catalog present")
	assert_false(_repo.blemish_types.is_empty(), "blemish catalog should not be empty")


func test_every_blemish_has_a_real_cleaning_tool() -> void:
	for blemish_id in _repo.blemish_types.keys():
		var blemish: BlemishType = _repo.blemish_types[blemish_id]
		assert_false(blemish.cleaning_tool.is_empty(), "%s needs a cleaning tool" % blemish_id)
		assert_not_null(
			_repo.get_tool(blemish.cleaning_tool),
			"%s references missing tool %s" % [blemish_id, blemish.cleaning_tool]
		)


func test_quest_decal_types_are_documented() -> void:
	# Every decal type used by Auntie's quest objects should appear in the guide so
	# the player can look up its cleaning tool.
	for template_id in ["auntie_photo_faded", "auntie_frame_portrait", "auntie_halfphoto_torn"]:
		var template := _repo.get_template(template_id)
		assert_not_null(template, "missing template %s" % template_id)
		for decal in template.decals:
			assert_not_null(
				_repo.get_blemish_type(decal.type),
				"decal type '%s' on %s is not in the blemish guide" % [decal.type, template_id]
			)


func test_blemish_types_sorted_is_stable_and_complete() -> void:
	var sorted := _repo.get_blemish_types_sorted()
	assert_eq(sorted.size(), _repo.blemish_types.size())
	var ids: Array = []
	for blemish in sorted:
		ids.append((blemish as BlemishType).id)
	var expected := ids.duplicate()
	expected.sort()
	assert_eq(ids, expected, "guide order should be sorted by id")


func test_blemish_color_parses_to_color() -> void:
	var dust: BlemishType = _repo.get_blemish_type("dust")
	assert_not_null(dust)
	assert_true(dust.to_color() is Color)
	assert_ne(dust.color, "", "blemish should carry a placeholder swatch colour")

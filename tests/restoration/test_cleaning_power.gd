extends GutTest
## CleaningPower: how strongly a tool cleans a condition, derived from the journal
## catalog (or an authored `cleans` override on the tool).

var _repo: DataRepository


func before_each() -> void:
	_repo = DataRepository.new()
	_repo.load_from_filesystem()


func test_catalog_tool_has_default_power_against_its_condition() -> void:
	# surface_conditions.json: rust is treated by the rust_brush.
	assert_eq(CleaningPower.power(_repo, "rust_brush", "rust"), CleaningPower.DEFAULT_POWER)


func test_wrong_tool_has_no_power() -> void:
	assert_eq(CleaningPower.power(_repo, "soft_brush", "rust"), 0)


func test_unknown_inputs_have_no_power() -> void:
	assert_eq(CleaningPower.power(_repo, "", "rust"), 0)
	assert_eq(CleaningPower.power(_repo, "rust_brush", ""), 0)


func test_conditions_for_lists_the_tools_conditions_with_power() -> void:
	var conditions := CleaningPower.conditions_for(_repo, "rust_brush")
	assert_false(conditions.is_empty(), "rust_brush fixes at least one condition")
	var found := false
	for entry in conditions:
		if entry["id"] == "rust":
			found = true
			assert_eq(int(entry["power"]), CleaningPower.DEFAULT_POWER)
			assert_true(entry.has("display_name"))
			assert_true(entry.has("color"))
	assert_true(found, "rust is in the rust_brush's fixable list")

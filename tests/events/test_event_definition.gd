extends GutTest
## EventDefinition model validation and repository loading.

var _repo: DataRepository


func before_each() -> void:
	_repo = DataRepository.new()
	_repo.load_from_filesystem()


func test_repository_loads_all_required_events() -> void:
	assert_true(_repo.is_loaded(), "data repository loads cleanly with events")
	assert_eq(_repo.event_definitions.size(), 8, "eight authored events")
	var required := [
		"rush_delivery",
		"sudden_brownout",
		"community_request",
		"suspicious_antique",
		"rare_buyer_alert",
		"mystery_box",
		"rainy_day_leak",
		"tool_breakdown",
	]
	for id in required:
		assert_not_null(_repo.get_event(id), "required event '%s' exists" % id)


func test_event_definition_round_trip() -> void:
	var data := {
		"id": "test_event",
		"display_name": "Test Event",
		"category": "opportunity",
		"trigger_conditions": {"weight": 1.5, "min_day": 1, "max_day": 3},
		"duration_hours": 2,
		"per_loop_cap": 2,
		"cooldown_hours": 1,
		"outcome_params": {"bonus": 10},
		"player_text": {"trigger_title": "T", "trigger_body": "B"},
		"accessibility_caption": "caption",
		"fallback_content": {"trigger_title": "F"},
	}
	var e := EventDefinition.from_dictionary(data)
	assert_eq(e.id, "test_event")
	assert_eq(e.display_name, "Test Event")
	assert_eq(e.category, "opportunity")
	assert_eq(e.weight(), 1.5)
	assert_true(e.can_trigger(2, 12))
	assert_false(e.can_trigger(4, 12))
	assert_eq(e.text("trigger_title"), "T")
	assert_eq(e.text("missing_key"), "")


func test_validation_catches_invalid_category_and_weight() -> void:
	var e := EventDefinition.new()
	e.id = "bad"
	e.display_name = "Bad"
	e.category = "weird"
	e.trigger_conditions = {"weight": -1.0, "eligible_days": [6]}
	var result := e.validate()
	assert_false(result.is_valid())
	assert_true(_errors_contain(result, "category"), "catches bad category")
	assert_true(_errors_contain(result, "weight"), "catches negative weight")
	assert_true(_errors_contain(result, "day 6"), "catches out-of-range day")


func _errors_contain(result: ValidationResult, snippet: String) -> bool:
	for err in result.errors():
		if err.find(snippet) >= 0:
			return true
	return false

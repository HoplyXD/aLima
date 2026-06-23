class_name EventDefinition
## Typed data contract for a mini-event (Phase 18).
##
## Events are authored in data/events/events.json, loaded by DataRepository, and
## consumed by EventDirector. They are artifact-agnostic and never hardcode object,
## buyer, or tool specifics — those references live in outcome_params and are
## validated against the repository.

const VALID_CATEGORIES: Array[String] = ["disruptive", "opportunity", "neutral"]

var id: String = ""
var display_name: String = ""
var category: String = "neutral"
## Conditions under which the event may trigger. Recognised keys:
##   "eligible_days": Array[int]     -- days 1..5 the event can fire (default all)
##   "eligible_hours": Array[int]    -- hours 0..23 the event can fire (default all)
##   "min_day": int                  -- earliest day (inclusive)
##   "max_day": int                  -- latest day (inclusive)
##   "min_hour": int                 -- earliest hour (inclusive)
##   "max_hour": int                 -- latest hour (inclusive)
##   "weight": float                 -- production selection weight
var trigger_conditions: Dictionary = {}
var duration_hours: int = 0  ## 0 means instant / one-shot.
var per_loop_cap: int = 1
var cooldown_hours: int = 0
## Event-specific parameters. Known schemas by event id:
##   rush_delivery:       {"batch_size_bonus": int, "seconds_per_hour_multiplier": float}
##   sudden_brownout:     {"blocked_tool_enables": Array[String], "condition_multiplier": float}
##   community_request:   {"request_template_id": String, "reward_money": int,
##                         "reward_lead": String}
##   suspicious_antique:  {"antique_template_id": String, "scanner_confidence_multiplier": float}
##   rare_buyer_alert:    {"buyer_persona_id": String, "wallet_bonus": int}
##   mystery_box:         {"box_template_id": String, "box_rarity_boost": String}
##   rainy_day_leak:      {"condition_multiplier": float, "shipment_delay_hours": int,
##                         "extra_condition_type": String}
##   tool_breakdown:      {" excluded_tool_ids": Array[String]}
var outcome_params: Dictionary = {}
## Player-facing copy.
var player_text: Dictionary = {}
var accessibility_caption: String = ""
## Authored fallback content per CONTENT-R8 (e.g. generic title/body when detailed
## copy is missing).
var fallback_content: Dictionary = {}


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> EventDefinition:
	var e := EventDefinition.new()
	e.id = ModelUtils.as_string(data.get("id"))
	e.display_name = ModelUtils.as_string(data.get("display_name"))
	e.category = ModelUtils.as_string(data.get("category"), "neutral").to_lower()
	e.trigger_conditions = ModelUtils.as_dictionary(data.get("trigger_conditions"))
	e.duration_hours = ModelUtils.as_int(data.get("duration_hours"), 0)
	e.per_loop_cap = ModelUtils.as_int(data.get("per_loop_cap"), 1)
	e.cooldown_hours = ModelUtils.as_int(data.get("cooldown_hours"), 0)
	e.outcome_params = ModelUtils.as_dictionary(data.get("outcome_params"))
	e.player_text = ModelUtils.as_dictionary(data.get("player_text"))
	e.accessibility_caption = ModelUtils.as_string(data.get("accessibility_caption"))
	e.fallback_content = ModelUtils.as_dictionary(data.get("fallback_content"))
	return e


func to_dictionary() -> Dictionary:
	return {
		"record_type": "event_definition",
		"id": id,
		"display_name": display_name,
		"category": category,
		"trigger_conditions": trigger_conditions.duplicate(),
		"duration_hours": duration_hours,
		"per_loop_cap": per_loop_cap,
		"cooldown_hours": cooldown_hours,
		"outcome_params": outcome_params.duplicate(),
		"player_text": player_text.duplicate(),
		"accessibility_caption": accessibility_caption,
		"fallback_content": fallback_content.duplicate(),
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "event id is required")
	if display_name.is_empty():
		result.add_field_error(file_path, id, "display_name", "event display_name is required")
	if not VALID_CATEGORIES.has(category):
		result.add_field_error(
			file_path, id, "category", "category must be disruptive/opportunity/neutral"
		)
	if duration_hours < 0:
		result.add_field_error(file_path, id, "duration_hours", "must be non-negative")
	if per_loop_cap < 0:
		result.add_field_error(file_path, id, "per_loop_cap", "must be non-negative")
	if cooldown_hours < 0:
		result.add_field_error(file_path, id, "cooldown_hours", "must be non-negative")

	var weight: float = ModelUtils.as_float(trigger_conditions.get("weight"), 0.0)
	if weight < 0.0:
		result.add_field_error(
			file_path, id, "trigger_conditions.weight", "weight must be non-negative"
		)

	var days: Array = trigger_conditions.get("eligible_days", [])
	if days is Array:
		for d in days:
			var day := ModelUtils.as_int(d)
			if day < 1 or day > 5:
				result.add_field_error(
					file_path, id, "trigger_conditions.eligible_days", "day %d out of 1..5" % day
				)

	var hours: Array = trigger_conditions.get("eligible_hours", [])
	if hours is Array:
		for h in hours:
			var hour := ModelUtils.as_int(h)
			if hour < 0 or hour > 23:
				result.add_field_error(
					file_path,
					id,
					"trigger_conditions.eligible_hours",
					"hour %d out of 0..23" % hour
				)

	var min_day := ModelUtils.as_int(trigger_conditions.get("min_day"), 1)
	var max_day := ModelUtils.as_int(trigger_conditions.get("max_day"), 5)
	if min_day > max_day:
		result.add_field_error(file_path, id, "trigger_conditions.min_day", "min_day > max_day")

	var min_hour := ModelUtils.as_int(trigger_conditions.get("min_hour"), 0)
	var max_hour := ModelUtils.as_int(trigger_conditions.get("max_hour"), 23)
	if min_hour > max_hour:
		result.add_field_error(file_path, id, "trigger_conditions.min_hour", "min_hour > max_hour")

	return result


## Stable selection weight for production rolls.
func weight() -> float:
	return maxf(ModelUtils.as_float(trigger_conditions.get("weight"), 0.0), 0.0)


## True when the event can trigger on the given day/hour.
func can_trigger(day: int, hour: int) -> bool:
	var days: Array = trigger_conditions.get("eligible_days", [])
	if days is Array and not days.is_empty():
		var found := false
		for d in days:
			if ModelUtils.as_int(d) == day:
				found = true
				break
		if not found:
			return false
	else:
		if day < ModelUtils.as_int(trigger_conditions.get("min_day"), 1):
			return false
		if day > ModelUtils.as_int(trigger_conditions.get("max_day"), 5):
			return false

	var hours: Array = trigger_conditions.get("eligible_hours", [])
	if hours is Array and not hours.is_empty():
		var found := false
		for h in hours:
			if ModelUtils.as_int(h) == hour:
				found = true
				break
		if not found:
			return false
	else:
		if hour < ModelUtils.as_int(trigger_conditions.get("min_hour"), 0):
			return false
		if hour > ModelUtils.as_int(trigger_conditions.get("max_hour"), 23):
			return false
	return true


## Player text with a safe fallback to authored fallback_content or a generic string.
func text(key: String) -> String:
	if player_text.has(key) and not str(player_text[key]).is_empty():
		return str(player_text[key])
	if fallback_content.has(key) and not str(fallback_content[key]).is_empty():
		return str(fallback_content[key])
	match key:
		"trigger_title":
			return display_name
		"trigger_body":
			return "Something unusual is happening today."
		"changed_rules":
			return "Check your tools and delivery carefully."
		"consequences":
			return "The shop will return to normal when this passes."
		_:
			return ""

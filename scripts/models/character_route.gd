class_name CharacterRoute
## Character route definition.
##
## Phase 1 only validates the data contract and references; scheduling logic
## belongs to Phase 2+.

var id: String = ""
var display_name: String = ""
var schedule: Array = []  ## VisitWindow dictionaries; kept raw here.
var prerequisites: Array[String] = []  ## Route ids / flags required.
var mutual_exclusions: Array[String] = []  ## Route ids that cannot co-occur.
var holds_fragment_id: String = ""  ## Empty for Yuyu/finale.
var rewards: Array[String] = []  ## Reward ids (tools, codes, leads).
var has_ending: bool = false
var beats: Array = []  ## Authored quest beats; raw dicts (id, day, object_template, summary).
var portrait: String = ""  ## res:// texture path for the visitor sprite.
var dialogue: Dictionary = {}  ## Key (e.g. day string or "default") -> Array of line dicts/strings.


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> CharacterRoute:
	var r := CharacterRoute.new()
	r.id = ModelUtils.as_string(data.get("id"))
	r.display_name = ModelUtils.as_string(data.get("display_name"))
	if data.get("schedule") is Array:
		for window in data["schedule"]:
			r.schedule.append(window)
	r.prerequisites = ModelUtils.as_string_array(data.get("prerequisites"))
	r.mutual_exclusions = ModelUtils.as_string_array(data.get("mutual_exclusions"))
	r.holds_fragment_id = ModelUtils.as_string(data.get("holds_fragment_id"))
	r.rewards = ModelUtils.as_string_array(data.get("rewards"))
	r.has_ending = ModelUtils.as_bool(data.get("has_ending"))
	if data.get("beats") is Array:
		for beat in data["beats"]:
			r.beats.append(beat)
	r.portrait = ModelUtils.as_string(data.get("portrait"))
	r.dialogue = ModelUtils.as_dictionary(data.get("dialogue"))
	return r


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"schedule": schedule.duplicate(),
		"prerequisites": prerequisites.duplicate(),
		"mutual_exclusions": mutual_exclusions.duplicate(),
		"holds_fragment_id": holds_fragment_id,
		"rewards": rewards.duplicate(),
		"has_ending": has_ending,
		"beats": beats.duplicate(),
		"portrait": portrait,
		"dialogue": dialogue.duplicate(true),
	}


## Returns the line list for a visit key, falling back to the "intro" set and then
## a generic "default". Lines are Strings or Dictionaries with "name"/"text" —
## exactly the shape DialogueBox.start() consumes.
func dialogue_for(key: String) -> Array:
	for candidate in [key, "intro", "default"]:
		if dialogue.has(candidate) and dialogue[candidate] is Array:
			return dialogue[candidate]
	return []


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "required id is missing")
	if display_name.is_empty():
		result.add_field_error(file_path, id, "display_name", "required display name is missing")
	var window_idx := 0
	for window in schedule:
		if window is Dictionary:
			_validate_window(window, window_idx, result, file_path)
		window_idx += 1
	var beat_idx := 0
	for beat in beats:
		if beat is Dictionary:
			_validate_beat(beat, beat_idx, result, file_path)
		else:
			result.add_field_error(
				file_path, id, "beats[%d]" % beat_idx, "beat must be a dictionary"
			)
		beat_idx += 1
	for key in dialogue.keys():
		var lines: Variant = dialogue[key]
		if not lines is Array:
			result.add_field_error(
				file_path, id, "dialogue[%s]" % key, "dialogue value must be an array of lines"
			)
			continue
		var line_idx := 0
		for line in lines:
			if not (line is String or line is Dictionary):
				result.add_field_error(
					file_path,
					id,
					"dialogue[%s][%d]" % [key, line_idx],
					"line must be a string or a dictionary"
				)
			line_idx += 1
	return result


func _validate_beat(
	beat: Dictionary, idx: int, result: ValidationResult, file_path: String
) -> void:
	if ModelUtils.as_string(beat.get("id")).is_empty():
		result.add_field_error(file_path, id, "beats[%d].id" % idx, "beat requires an id")
	var day := ModelUtils.as_int(beat.get("day"), -1)
	if day < 1 or day > 5:
		result.add_field_error(file_path, id, "beats[%d].day" % idx, "beat day must be 1..5")


func _validate_window(
	window: Dictionary, idx: int, result: ValidationResult, file_path: String
) -> void:
	if not window.has("days") or not window["days"] is Array:
		result.add_field_error(
			file_path, id, "schedule[%d].days" % idx, "visit window requires a days array"
		)
	else:
		for day in window["days"]:
			if day is int and (day < 1 or day > 5):
				result.add_field_error(file_path, id, "schedule[%d].days" % idx, "day must be 1..5")
	if not window.has("start_hour") or not window.has("end_hour"):
		result.add_field_error(
			file_path, id, "schedule[%d]" % idx, "visit window requires start_hour and end_hour"
		)
	else:
		var start_h := ModelUtils.as_int(window.get("start_hour"))
		var end_h := ModelUtils.as_int(window.get("end_hour"))
		if start_h < 0 or start_h > 23 or end_h < 0 or end_h > 23 or end_h <= start_h:
			result.add_field_error(file_path, id, "schedule[%d]" % idx, "invalid hour range")

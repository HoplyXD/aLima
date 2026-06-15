class_name EchoSet
## Four-band Cultural Echo definition for one fragment.
##
## Audio paths may be empty strings when no approved audio asset exists yet;
## empty paths are treated as intentional placeholders and are valid in Phase 1.

var id: String = ""
var hum_stream: String = ""  ## Asset ref/path.
var melody_stream: String = ""
var voice_stream: String = ""  ## Kinaray-a phrase audio.
var voice_caption: String = ""  ## Subtitle + translation.
var heartbeat_stream: String = ""


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> EchoSet:
	var e := EchoSet.new()
	e.id = ModelUtils.as_string(data.get("id"))
	e.hum_stream = ModelUtils.as_string(data.get("hum_stream"))
	e.melody_stream = ModelUtils.as_string(data.get("melody_stream"))
	e.voice_stream = ModelUtils.as_string(data.get("voice_stream"))
	e.voice_caption = ModelUtils.as_string(data.get("voice_caption"))
	e.heartbeat_stream = ModelUtils.as_string(data.get("heartbeat_stream"))
	return e


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"hum_stream": hum_stream,
		"melody_stream": melody_stream,
		"voice_stream": voice_stream,
		"voice_caption": voice_caption,
		"heartbeat_stream": heartbeat_stream,
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "required id is missing")
	if voice_caption.is_empty():
		result.add_field_error(
			file_path, id, "voice_caption", "voice caption/subtitle is required for accessibility"
		)
	return result

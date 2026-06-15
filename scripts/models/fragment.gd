class_name Fragment
## Persistent fragment of the Master Artifact.
##
## Lifecycle: LOCKED -> RELEASED -> SEATED. A RELEASED fragment is re-placed by
## the Spawn Director each loop until found (CLAUDE.md §4-B).

var id: String = ""
var master_artifact_id: String = ""  ## MasterArtifact id.
var owning_character_id: String = ""  ## CharacterRoute id that releases it.
var case_slot_index: int = 0  ## 0..4 in the journal case.
var state: int = ModelEnums.FragmentState.LOCKED
var echo_set_ref: String = ""  ## EchoSet id.
var historical_fact_ref: String = ""  ## Unlocked fact ref on discovery.


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> Fragment:
	var f := Fragment.new()
	f.id = ModelUtils.as_string(data.get("id"))
	f.master_artifact_id = ModelUtils.as_string(data.get("master_artifact_id"))
	f.owning_character_id = ModelUtils.as_string(data.get("owning_character_id"))
	f.case_slot_index = ModelUtils.as_int(data.get("case_slot_index"))
	f.state = ModelEnums.fragment_state_from_name(ModelUtils.as_string(data.get("state")))
	f.echo_set_ref = ModelUtils.as_string(data.get("echo_set_ref"))
	f.historical_fact_ref = ModelUtils.as_string(data.get("historical_fact_ref"))
	return f


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"master_artifact_id": master_artifact_id,
		"owning_character_id": owning_character_id,
		"case_slot_index": case_slot_index,
		"state": ModelEnums.fragment_state_name(state),
		"echo_set_ref": echo_set_ref,
		"historical_fact_ref": historical_fact_ref,
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "required id is missing")
	if master_artifact_id.is_empty():
		result.add_field_error(
			file_path, id, "master_artifact_id", "required master_artifact_id is missing"
		)
	if owning_character_id.is_empty():
		result.add_field_error(
			file_path, id, "owning_character_id", "required owning_character_id is missing"
		)
	if case_slot_index < 0 or case_slot_index > 4:
		result.add_field_error(file_path, id, "case_slot_index", "case_slot_index must be 0..4")
	if ModelEnums.FRAGMENT_STATE_NAMES.find(ModelEnums.fragment_state_name(state)) < 0:
		result.add_field_error(file_path, id, "state", "unknown fragment state")
	if echo_set_ref.is_empty():
		result.add_field_error(file_path, id, "echo_set_ref", "required echo_set_ref is missing")
	return result

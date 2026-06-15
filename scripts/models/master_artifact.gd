class_name MasterArtifact
## Artifact-agnostic definition of the assembled Master Artifact.
##
## The real heritage object is chosen later (README.md §8); all logic references
## this data contract so the choice drops in without a refactor.

var id: String = ""
var display_name: String = ""
var fragment_ids: Array[String] = []  ## Exactly five unique fragment IDs.
var assembled_history_ref: String = ""  ## Fact/ref unlocked when complete.


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> MasterArtifact:
	var m := MasterArtifact.new()
	m.id = ModelUtils.as_string(data.get("id"))
	m.display_name = ModelUtils.as_string(data.get("display_name"))
	m.fragment_ids = ModelUtils.as_string_array(data.get("fragment_ids"))
	m.assembled_history_ref = ModelUtils.as_string(data.get("assembled_history_ref"))
	return m


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"fragment_ids": fragment_ids.duplicate(),
		"assembled_history_ref": assembled_history_ref,
	}


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "required id is missing")
	if display_name.is_empty():
		result.add_field_error(file_path, id, "display_name", "required display name is missing")
	if fragment_ids.size() != 5:
		result.add_field_error(
			file_path,
			id,
			"fragment_ids",
			"must define exactly five fragment IDs (found %d)" % fragment_ids.size()
		)
	else:
		var seen := {}
		for fid in fragment_ids:
			if fid.is_empty():
				result.add_field_error(
					file_path, id, "fragment_ids", "fragment ID must not be empty"
				)
			elif seen.has(fid):
				result.add_field_error(
					file_path, id, "fragment_ids", "duplicate fragment ID '%s'" % fid
				)
			seen[fid] = true
	return result

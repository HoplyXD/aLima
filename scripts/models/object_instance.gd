class_name ObjectInstance
## Runtime object instance. One per delivered item; lives in LoopState.
##
## A carrier is a runtime role, never a separate template. The Spawn Director
## promotes an ordinary instance by setting is_carrier, fragment_id, and contents.

var template_id: String = ""
var uid: String = ""  ## Unique within the current loop.
var condition: float = 0.0  ## 0..100, raised by restoration.
var state: int = ModelEnums.ObjState.DIRTY
var is_carrier: bool = false
var fragment_id: String = ""  ## Payload when is_carrier is true.
var contents: int = ModelEnums.OpenResult.EMPTY
var authenticity: int = ModelEnums.Verdict.UNKNOWN
var is_counterfeit_truth: bool = false
var storage_cost: int = 1  ## Copied from the template at creation time.
var assigned_anchor_id: String = ""  ## Container/placement anchor for this instance.
var value: int = 0  ## Current assessed market value = true_value minus live condition penalties.
## The pristine market value rolled once at spawn, uniformly within the template's base value
## range. Fixed for the instance's life; `value` is derived from it via ValueModel. 0 until rolled.
var true_value: int = 0
var removed_decals: Array[String] = []  ## Decal ids cleared so far (decal-based templates).
var spawned_decals: Array = []  ## Random per-instance conditions; empty => use template decals.
var is_joined: bool = false  ## True once a join-step object has been reassembled.
var dirt_mask: PackedByteArray = PackedByteArray()
## PNG of the exact cleaned grime mask for condition-based objects; empty => rebuild from condition.


func _init() -> void:
	pass


static func from_dictionary(data: Dictionary) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.template_id = ModelUtils.as_string(data.get("template_id"))
	inst.uid = ModelUtils.as_string(data.get("uid"))
	inst.condition = ModelUtils.as_float(data.get("condition"))
	inst.state = ModelEnums.obj_state_from_name(ModelUtils.as_string(data.get("state")))
	inst.is_carrier = ModelUtils.as_bool(data.get("is_carrier"))
	inst.fragment_id = ModelUtils.as_string(data.get("fragment_id"))
	inst.contents = ModelEnums.open_result_from_name(ModelUtils.as_string(data.get("contents")))
	inst.authenticity = ModelEnums.verdict_from_name(ModelUtils.as_string(data.get("authenticity")))
	inst.is_counterfeit_truth = ModelUtils.as_bool(data.get("is_counterfeit_truth"))
	inst.storage_cost = ModelUtils.as_int(data.get("storage_cost"), 1)
	inst.assigned_anchor_id = ModelUtils.as_string(data.get("assigned_anchor_id"))
	inst.value = ModelUtils.as_int(data.get("value"))
	# Back-compat: pre-revamp saves have no true_value; fall back to the stored value.
	inst.true_value = ModelUtils.as_int(data.get("true_value"), inst.value)
	inst.removed_decals = ModelUtils.as_string_array(data.get("removed_decals"))
	if data.get("spawned_decals") is Array:
		for raw_decal in data["spawned_decals"]:
			if raw_decal is Dictionary:
				inst.spawned_decals.append(raw_decal.duplicate())
	inst.is_joined = ModelUtils.as_bool(data.get("is_joined"))
	var raw_mask: Variant = data.get("dirt_mask", "")
	if raw_mask is String and not (raw_mask as String).is_empty():
		inst.dirt_mask = Marshalls.base64_to_raw(raw_mask)
	return inst


func to_dictionary() -> Dictionary:
	return {
		"template_id": template_id,
		"uid": uid,
		"condition": condition,
		"state": ModelEnums.obj_state_name(state),
		"is_carrier": is_carrier,
		"fragment_id": fragment_id,
		"contents": ModelEnums.open_result_name(contents),
		"authenticity": ModelEnums.verdict_name(authenticity),
		"is_counterfeit_truth": is_counterfeit_truth,
		"storage_cost": storage_cost,
		"assigned_anchor_id": assigned_anchor_id,
		"value": value,
		"true_value": true_value,
		"removed_decals": removed_decals.duplicate(),
		"spawned_decals": spawned_decals.duplicate(true),
		"is_joined": is_joined,
		"dirt_mask": Marshalls.raw_to_base64(dirt_mask) if not dirt_mask.is_empty() else "",
	}


## Per-instance random conditions parsed into SurfaceDecal models (empty when this
## instance uses its template's authored decals instead).
func get_spawned_decals() -> Array[SurfaceDecal]:
	var out: Array[SurfaceDecal] = []
	for raw_decal in spawned_decals:
		if raw_decal is Dictionary:
			out.append(SurfaceDecal.from_dictionary(raw_decal))
	return out


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if uid.is_empty():
		result.add_field_error(file_path, uid, "uid", "required instance uid is missing")
	if template_id.is_empty():
		result.add_field_error(file_path, uid, "template_id", "required template_id is missing")
	if condition < 0.0 or condition > 100.0:
		result.add_field_error(file_path, uid, "condition", "condition must be between 0 and 100")
	if ModelEnums.OBJ_STATE_NAMES.find(ModelEnums.obj_state_name(state)) < 0:
		result.add_field_error(file_path, uid, "state", "unknown object state")
	if ModelEnums.OPEN_RESULT_NAMES.find(ModelEnums.open_result_name(contents)) < 0:
		result.add_field_error(file_path, uid, "contents", "unknown open result")
	if ModelEnums.VERDICT_NAMES.find(ModelEnums.verdict_name(authenticity)) < 0:
		result.add_field_error(file_path, uid, "authenticity", "unknown verdict")
	if is_carrier and fragment_id.is_empty():
		result.add_field_error(file_path, uid, "fragment_id", "carriers must specify a fragment_id")
	if not is_carrier and not fragment_id.is_empty():
		result.add_field_error(
			file_path, uid, "fragment_id", "only carriers may carry a fragment_id"
		)
	if storage_cost < 1:
		result.add_field_error(file_path, uid, "storage_cost", "storage_cost must be at least 1")
	if value < 0:
		result.add_field_error(file_path, uid, "value", "value must be non-negative")
	return result

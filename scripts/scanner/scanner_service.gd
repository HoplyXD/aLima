class_name ScannerService
## Presentation-independent scanner service.
##
## Builds a typed request from an ObjectInstance, submits it through a transport
## boundary, and returns a typed ScannerResult. The service never sets or infers
## authenticity; the player verdict is committed separately.

const REQUEST_STREAM := "scanner_request"

var _transport: ScannerTransport
var _game_state: GameState
var _repo: DataRepository


func _init(
	transport: ScannerTransport = null,
	game_state: GameState = GameState,
	repo: DataRepository = DataRepository.singleton()
) -> void:
	_transport = transport if transport != null else ScannerCacheTransport.new(repo)
	_game_state = game_state
	_repo = repo


## Builds a typed ScannerRequest from an ObjectInstance and its template.
## Excludes hidden truth fields (carrier, fragment, counterfeit truth, contents).
func create_request(instance: ObjectInstance) -> ScannerRequest:
	var request := ScannerRequest.new()
	request.request_id = _make_request_id(instance)
	request.instance_id = instance.uid
	request.template_id = instance.template_id
	request.condition = instance.condition
	request.language = "en"

	var template: ScrapObjectTemplate = _repo.get_template(instance.template_id)
	if template != null:
		request.materials = template.materials.duplicate()
		request.weight = (template.weight_range.x + template.weight_range.y) / 2.0
	else:
		request.materials = []
		request.weight = 0.0

	# Markings are observable surface features, not hidden truth. The cache response
	# provides them; the request carries any player-visible annotations (currently none).
	request.markings = []
	request.player_notes = ""
	return request


## Minimum condition (percent) needed before the scanner can read a piece. Ordinary artifacts need a
## decent clean; historical ones (gold rarity / `historical` tag) read through more grime.
const SCAN_THRESHOLD: float = 50.0
const SCAN_THRESHOLD_HISTORICAL: float = 25.0


## The clean % this instance must reach before it can be scanned.
func scan_threshold(instance: ObjectInstance) -> float:
	if instance == null:
		return SCAN_THRESHOLD
	var template: ScrapObjectTemplate = _repo.get_template(instance.template_id)
	var historical := (
		template != null
		and (template.tags.has("historical") or template.base_rarity == ModelEnums.Rarity.GOLD)
	)
	return SCAN_THRESHOLD_HISTORICAL if historical else SCAN_THRESHOLD


## True when the instance is clean enough to scan (an OPEN piece is past the gate by definition).
## Compares the *effective* clean percent (condition / clean_completion_threshold * 100) against
## the threshold, matching the percent the bench displays for non-decal openables.
func can_scan(instance: ObjectInstance) -> bool:
	if instance == null:
		return false
	if instance.state == ModelEnums.ObjState.OPEN:
		return true
	return _effective_clean_percent(instance) >= scan_threshold(instance)


## Effective clean percent for the threshold check. For pieces whose clean_completion_threshold
## differs from 100, this normalises progress so the scanner gate matches the bench meter.
func _effective_clean_percent(instance: ObjectInstance) -> float:
	var template: ScrapObjectTemplate = _repo.get_template(instance.template_id)
	var threshold := template.clean_completion_threshold if template != null else 100
	if threshold <= 0:
		threshold = 100
	return (instance.condition / float(threshold)) * 100.0


## Scans the instance and returns a typed ScannerResult.
func scan(instance: ObjectInstance) -> ScannerResult:
	if not can_scan(instance):
		var blocked := ScannerResponse.new()
		blocked.ok = false
		blocked.transport_error = "Too dirty to be scanned — clean it more first."
		blocked.request_id = _make_request_id(instance)
		return ScannerResult.new(ScannerResult.Status.NOT_CLEAN, blocked)

	var request := create_request(instance)
	var transport_result: Dictionary = _transport.submit(request)
	var status: int = transport_result.get("status", ScannerResult.Status.TRANSPORT_ERROR)
	var raw_response = transport_result.get("response", ScannerResponse.new())
	var response: ScannerResponse
	if raw_response is ScannerResponse:
		response = raw_response
	else:
		response = ScannerResponse.from_dictionary(raw_response as Dictionary)

	if not transport_result.get("ok", false):
		response.ok = false
		response.request_id = request.request_id
		if response.transport_error.is_empty():
			response.transport_error = ModelUtils.as_string(transport_result.get("error"))
		return ScannerResult.new(status, response)

	response.request_id = request.request_id
	_apply_instance_data_to_response(response, instance)
	return ScannerResult.new(status, response)


## Stores the player's verdict on the runtime instance and persists a scanned record.
## Returns true if the verdict was stored. Idempotent: repeated calls with the same
## verdict return true without duplicating records.
func commit_verdict(instance_id: String, verdict: int) -> bool:
	if not _is_valid_verdict(verdict):
		return false

	var inst := _find_instance_by_id(instance_id)
	if inst == null:
		return false

	# Scanner output must never set authenticity.
	inst.authenticity = verdict
	_write_instance_back(inst)

	var template: ScrapObjectTemplate = _repo.get_template(inst.template_id)
	var display_type := template.display_name if template != null else inst.template_id

	var record := ScannedRecord.new()
	record.template_id = inst.template_id
	record.instance_id = inst.uid
	record.verdict = verdict
	record.scanned_at_loop = _game_state.loop_index
	record.response_snapshot = _snapshot_for_record(inst, display_type)

	# Preserve the latest response snapshot if one exists in memory.
	var existing: ScannedRecord = _game_state.save_state.persistent.scanned_records.get(
		inst.template_id
	)
	if existing != null and existing.response_snapshot.has("request_id"):
		record.response_snapshot = existing.response_snapshot.duplicate()
		record.fallback = existing.fallback

	_game_state.save_state.persistent.scanned_records[inst.template_id] = record
	EventBus.scanner_verdict_committed.emit(instance_id, ModelEnums.verdict_name(verdict))
	SaveService.save_game()
	return true


func find_instance_by_id(uid: String) -> ObjectInstance:
	return _find_instance_by_id(uid)


func _is_valid_verdict(verdict: int) -> bool:
	return (
		verdict == ModelEnums.Verdict.AUTHENTIC
		or verdict == ModelEnums.Verdict.REPLICA
		or verdict == ModelEnums.Verdict.MODIFIED
		or verdict == ModelEnums.Verdict.UNCERTAIN
	)


func _find_instance_by_id(uid: String) -> ObjectInstance:
	for raw in _game_state.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == uid:
			return ObjectInstance.from_dictionary(raw)
	return null


func _write_instance_back(inst: ObjectInstance) -> void:
	var inventory := _game_state.save_state.loop.inventory
	for i in range(inventory.size()):
		var raw = inventory[i]
		if raw is Dictionary and raw.get("uid") == inst.uid:
			inventory[i] = inst.to_dictionary()
			return


func _make_request_id(instance: ObjectInstance) -> String:
	var seed := _game_state.derive_seed(REQUEST_STREAM)
	return "scan_%s_%d_%d" % [instance.uid, _game_state.loop_index, seed]


## Replaces placeholder scanner response fields with values derived from the artifact itself:
## - price_range comes from template.base_value_range.
## - markings / condition_note come from the active surface conditions (spawned or authored decals).
func _apply_instance_data_to_response(response: ScannerResponse, inst: ObjectInstance) -> void:
	var template: ScrapObjectTemplate = _repo.get_template(inst.template_id)
	if template != null:
		response.price_range_min = int(template.base_value_range.x)
		response.price_range_max = int(template.base_value_range.y)

	var active := _active_surface_decals(inst, template)
	var labels: Array[String] = []
	for decal in active:
		var condition := _repo.get_surface_condition(decal.type)
		var label := condition.display_name if condition != null else decal.type.capitalize()
		if not labels.has(label):
			labels.append(label)
	response.markings = labels
	response.condition_note = _condition_note_for_active(labels)


## Active surface decals for the instance: spawned conditions win, then template-authored decals,
## minus any the player has already removed.
func _active_surface_decals(
	inst: ObjectInstance, template: ScrapObjectTemplate
) -> Array[SurfaceDecal]:
	var all: Array[SurfaceDecal] = []
	if inst != null and not inst.spawned_decals.is_empty():
		all = inst.get_spawned_decals()
	elif template != null:
		all = template.decals
	var out: Array[SurfaceDecal] = []
	for decal in all:
		if inst == null or not inst.removed_decals.has(decal.id):
			out.append(decal)
	return out


## Player-facing condition note built from active condition labels.
func _condition_note_for_active(labels: Array[String]) -> String:
	if labels.is_empty():
		return "No significant surface conditions remain."
	if labels.size() == 1:
		return "Shows %s." % labels[0]
	if labels.size() == 2:
		return "Shows %s and %s." % [labels[0], labels[1]]
	return "Shows %s, and %s." % [", ".join(labels.slice(0, labels.size() - 1)), labels[-1]]


func _snapshot_for_record(inst: ObjectInstance, display_type: String) -> Dictionary:
	var response := ScannerResponse.new()
	var entry: ScannerCacheEntry = _repo.get_scanner_cache(inst.template_id)
	if entry != null:
		response = ScannerResponse.from_dictionary(entry.response.duplicate())
	else:
		# Minimal fallback snapshot for records created before scanning.
		response.type = display_type
		response.period = "unknown"
		response.condition_note = "No scanner response recorded."
		response.confidence = "uncertain"
		response.fallback = true
	_apply_instance_data_to_response(response, inst)
	return response.to_dictionary()

extends Node
## MuseumService owns the museum archive boundary for Gold finds and the Master
## Artifact (P16.4, MUS-R1..R3, DISP-R4, CLAUDE.md §4-F).
##
## * Synchronously persists a MuseumEntry for every verified discovery so the
##   gallery works offline (MUS-R2, MUS-R3).
## * Asynchronously posts the record to the backend Portal proxy and updates the
##   local entry when a response arrives.
## * Provides deterministic entry ids that match the backend's idempotency key
##   (`entry_<record_id>_<player_id>`), so online and offline paths converge.
## * Retrieval hydrates the gallery from the Portal when reachable and falls back
##   to persisted records otherwise (PORT-R6, §4-O).

const MUSEUM_ENDPOINT := "/api/portal/museum"

var _client: PortalClient = null


func _ready() -> void:
	_client = PortalClient.new()
	_client.museum_record_completed.connect(_on_record_completed)
	_client.museum_entries_completed.connect(_on_entries_completed)


## Test seam: inject a fake PortalClient (e.g. one that emits synchronously).
func set_client(client: PortalClient) -> void:
	if _client != null:
		_client.museum_record_completed.disconnect(_on_record_completed)
		_client.museum_entries_completed.disconnect(_on_entries_completed)
	_client = client
	_client.museum_record_completed.connect(_on_record_completed)
	_client.museum_entries_completed.connect(_on_entries_completed)


## The canonical museum entry id for a record. Matches the backend's
## deterministic id so online/offline writes and retrieval all agree.
static func entry_id_for(record_id: String, player_id: String) -> String:
	return "entry_%s_%s" % [record_id, player_id]


## Records a Gold-tier find from the disposition / PRESERVE path. Persists the
## local MuseumEntry immediately, then posts to the Portal. Idempotent: calling
## again for the same record returns the existing entry without duplicates.
func post_gold_discovery(inst: ObjectInstance, template: ScrapObjectTemplate) -> String:
	var record_id := inst.template_id
	var player_id := GameState.player_id
	var entry_id := entry_id_for(record_id, player_id)

	_ensure_local_entry(entry_id, inst, template)

	var request := _build_request(record_id, player_id, "gold", inst, template)
	_client.request_museum_record(request)
	return entry_id


## Records the assembled Master Artifact. Called by the finale flow once all five
## fragments are seated (P19.5). The artifact lock is required before the fact
## card becomes verified content.
func post_master_artifact() -> String:
	var artifact: MasterArtifact = DataRepository.singleton().master_artifact
	if artifact == null:
		push_error("MuseumService: no master artifact configured")
		return ""

	var record_id := artifact.id
	var player_id := GameState.player_id
	var entry_id := entry_id_for(record_id, player_id)

	if GameState.save_state.persistent.museum_entries.has(entry_id):
		return entry_id

	var request := MuseumRecordRequest.new()
	request.record_id = record_id
	request.player_id = player_id
	request.rarity = "master_artifact"
	request.timestamp = Time.get_datetime_string_from_system(true)
	request.condition = 100
	request.discovery_context = "assembled from five seated fragments"
	request.display_name = artifact.display_name

	var entry := _pending_master_entry(artifact)
	GameState.save_state.persistent.museum_entries[entry_id] = entry
	SaveService.save_game()

	_client.request_museum_record(request)
	return entry_id


## Returns the persisted entries currently available for the gallery. Offline-safe:
## never blocks on network.
func get_gallery_entries() -> Array[MuseumEntry]:
	var entries: Array[MuseumEntry] = []
	for key in GameState.save_state.persistent.museum_entries.keys():
		var entry: MuseumEntry = GameState.save_state.persistent.museum_entries[key]
		entries.append(entry)
	entries.sort_custom(
		func(a: MuseumEntry, b: MuseumEntry) -> bool: return a.artifact_id < b.artifact_id
	)
	return entries


## Asks the backend to list the player's museum records and merges them into the
## persisted store. Emits EventBus.museum_gallery_refreshed on completion or
## failure. The gallery stays usable because local records are never removed.
func refresh_gallery() -> void:
	if GameState.player_id.is_empty():
		return
	_client.request_museum_entries(GameState.player_id)


## Debug/test seam: send an already-built MuseumRecordRequest through the Portal
## client without constructing a stand-in game object. Used by MuseumDemoHelper.
func post_record_request(request: MuseumRecordRequest) -> String:
	var entry_id := entry_id_for(request.record_id, request.player_id)
	_client.request_museum_record(request)
	return entry_id


func _build_request(
	record_id: String,
	player_id: String,
	rarity: String,
	inst: ObjectInstance,
	template: ScrapObjectTemplate
) -> MuseumRecordRequest:
	var request := MuseumRecordRequest.new()
	request.record_id = record_id
	request.player_id = player_id
	request.rarity = rarity
	request.timestamp = Time.get_datetime_string_from_system(true)
	request.condition = clampi(int(inst.condition), 0, 100) if inst != null else 0
	request.discovery_context = "preserved from shop inventory"
	request.display_name = template.display_name if template != null else record_id
	return request


## Ensures a local MuseumEntry exists. Returns false when one already exists,
## which still counts as success (idempotent duplicate).
func _ensure_local_entry(
	entry_id: String, inst: ObjectInstance, template: ScrapObjectTemplate
) -> bool:
	var museum: Dictionary = GameState.save_state.persistent.museum_entries
	if museum.has(entry_id):
		return false

	var entry := MuseumEntry.new()
	entry.artifact_id = inst.template_id
	entry.fact_card = _local_fact_card(template)
	entry.photo_ref = ""
	entry.timeline_entry = "Provenance timeline pending source verification."
	entry.regional_story = "Regional story pending source verification."
	entry.character_memory_refs = []
	museum[entry_id] = entry
	SaveService.save_game()
	EventBus.museum_entry_recorded.emit(entry_id, inst.template_id, true)
	return true


func _pending_master_entry(artifact: MasterArtifact) -> MuseumEntry:
	var entry := MuseumEntry.new()
	entry.artifact_id = artifact.id
	entry.fact_card = (
		"SOURCE VERIFICATION PENDING — the assembled artifact record will be "
		+ "authored from verified sources after the artifact lock."
	)
	entry.photo_ref = ""
	entry.timeline_entry = "Assembled-artifact timeline pending source verification."
	entry.regional_story = "Assembled-artifact regional story pending source verification."
	entry.character_memory_refs = []
	return entry


func _local_fact_card(template: ScrapObjectTemplate) -> String:
	var name := template.display_name if template != null else "a Gold-tier find"
	return (
		(
			"SOURCE VERIFICATION PENDING — %s is preserved here; its verified "
			+ "museum fact card will be added once the source review is complete."
		)
		% name
	)


func _on_record_completed(result: MuseumResult) -> void:
	if result == null or result.record == null:
		return
	var response: MuseumRecordResponse = result.record
	var entry_id := response.museum_entry_id
	if entry_id.is_empty():
		return

	var museum: Dictionary = GameState.save_state.persistent.museum_entries
	if museum.has(entry_id):
		_merge_record_into_entry(response, museum[entry_id])
	else:
		museum[entry_id] = response.to_museum_entry()
	SaveService.save_game()
	EventBus.museum_entry_recorded.emit(entry_id, response.record_id, response.used_fallback)


func _on_entries_completed(result: MuseumResult) -> void:
	var used_fallback := result.used_fallback
	if result.is_ok():
		var museum: Dictionary = GameState.save_state.persistent.museum_entries
		for response in result.entries:
			var entry_id := response.museum_entry_id
			if entry_id.is_empty():
				continue
			if museum.has(entry_id):
				_merge_record_into_entry(response, museum[entry_id])
			else:
				museum[entry_id] = response.to_museum_entry()
		SaveService.save_game()
		used_fallback = result.used_fallback
	EventBus.museum_gallery_refreshed.emit(get_gallery_entries(), used_fallback)


func _merge_record_into_entry(response: MuseumRecordResponse, entry: MuseumEntry) -> void:
	if not response.fact_card.is_empty():
		entry.fact_card = response.fact_card
	if not response.photo_ref.is_empty():
		entry.photo_ref = response.photo_ref
	if not response.timeline_entry.is_empty():
		entry.timeline_entry = response.timeline_entry
	if not response.regional_story.is_empty():
		entry.regional_story = response.regional_story
	if response.character_memory_refs.size() > 0:
		entry.character_memory_refs = response.character_memory_refs.duplicate()

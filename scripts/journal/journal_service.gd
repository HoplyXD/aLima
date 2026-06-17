extends Node
## Business logic for persistent journal entries (P9.2 / JRN-R1..R5).
##
## Listens to restoration and scanner-verdict events, then creates or updates one
## stable JournalEntry per Purple-and-below object template. Gold finds and Master
## Artifact discoveries are intentionally not archived here: fragments seat through
## SeatingService (MuseumEntry), and non-fragment Gold objects route to the museum
## through the future disposition system.
##
## The service never duplicates entries. Repeated restoration or scanning of the
## same template updates the existing record, preserving best_condition and
## appending scanner annotations. It does not copy loop inventory into persistent
## state beyond the template-level facts required by the entry.


func _ready() -> void:
	EventBus.restoration_completed.connect(_on_restoration_completed)
	EventBus.scanner_verdict_committed.connect(_on_scanner_verdict_committed)


## Public seam for tests: force-create or refresh a journal entry from an instance.
func record_restoration(instance: ObjectInstance) -> void:
	_update_or_create_entry(instance)


## Public seam for tests: force-update a journal entry from a verdict.
func record_scan_verdict(instance: ObjectInstance, verdict_name: String) -> void:
	_update_entry_with_scan(instance, verdict_name)


func _on_restoration_completed(instance_id: String, _condition: float, _tool_id: String) -> void:
	var inst := _find_instance(instance_id)
	if inst == null:
		return
	_update_or_create_entry(inst)


func _on_scanner_verdict_committed(instance_id: String, verdict_name: String) -> void:
	var inst := _find_instance(instance_id)
	if inst == null:
		return
	_update_entry_with_scan(inst, verdict_name)


func _update_or_create_entry(instance: ObjectInstance) -> void:
	if _should_route_to_museum(instance):
		return

	var repo := DataRepository.singleton()
	var template: ScrapObjectTemplate = repo.get_template(instance.template_id)
	if template == null:
		push_warning("JournalService: unknown template '%s'" % instance.template_id)
		return

	var entries: Dictionary = GameState.save_state.persistent.journal_entries
	var entry: JournalEntry = entries.get(instance.template_id) as JournalEntry
	if entry == null:
		entry = _create_entry(template)
		entries[instance.template_id] = entry

	entry.best_condition = maxi(entry.best_condition, int(instance.condition))
	entry.variants_found = _add_unique(entry.variants_found, instance.uid)
	_save()


func _update_entry_with_scan(instance: ObjectInstance, verdict_name: String) -> void:
	if _should_route_to_museum(instance):
		return

	var repo := DataRepository.singleton()
	var template: ScrapObjectTemplate = repo.get_template(instance.template_id)
	if template == null:
		return

	var entries: Dictionary = GameState.save_state.persistent.journal_entries
	var entry: JournalEntry = entries.get(instance.template_id) as JournalEntry
	if entry == null:
		entry = _create_entry(template)
		entries[instance.template_id] = entry

	entry.player_verdict = ModelEnums.verdict_from_name(verdict_name)
	entry.ai_annotations = _build_annotation_text(instance.template_id)
	_save()


func _create_entry(template: ScrapObjectTemplate) -> JournalEntry:
	var entry := JournalEntry.new()
	entry.template_id = template.id
	entry.origin = template.display_name
	entry.materials = template.materials.duplicate()
	entry.weight_range = template.weight_range
	entry.clean_method = template.clean_minigame
	entry.counterfeit_indicators = []  # Populated from counterfeit profile in a later phase.
	entry.historical_context = ""
	entry.value_range = template.base_value_range
	entry.best_condition = 0
	entry.best_sale = 0
	entry.variants_found = []
	entry.uncle_notes = (
		"Uncle's note: a %s from the scrap stream. Worth a careful look." % template.display_name
	)
	entry.ai_annotations = ""
	entry.temporal_echoes_unlocked = []
	entry.player_verdict = ModelEnums.Verdict.UNKNOWN
	return entry


func _build_annotation_text(template_id: String) -> String:
	var record: ScannedRecord = (
		GameState.save_state.persistent.scanned_records.get(template_id) as ScannedRecord
	)
	if record == null or record.response_snapshot.is_empty():
		return ""

	var snapshot: Dictionary = record.response_snapshot
	var parts: Array[String] = []
	parts.append("Scanner analysis")
	var type: String = ModelUtils.as_string(snapshot.get("type"))
	if not type.is_empty():
		parts.append("Type: %s" % type)
	var period: String = ModelUtils.as_string(snapshot.get("period"))
	if not period.is_empty():
		parts.append("Period: %s" % period)
	var materials = snapshot.get("materials")
	if materials is Array and not (materials as Array).is_empty():
		parts.append("Materials: %s" % ", ".join(materials as Array))
	var markings = snapshot.get("markings")
	if markings is Array and not (markings as Array).is_empty():
		parts.append("Markings: %s" % ", ".join(markings as Array))
	var condition: String = ModelUtils.as_string(snapshot.get("condition_note"))
	if not condition.is_empty():
		parts.append("Condition: %s" % condition)
	var relevance: String = ModelUtils.as_string(snapshot.get("cultural_relevance"))
	if not relevance.is_empty():
		parts.append("Context: %s" % relevance)
	var signs = snapshot.get("modification_signs")
	if signs is Array and not (signs as Array).is_empty():
		parts.append("Modification signs: %s" % ", ".join(signs as Array))
	var confidence: String = ModelUtils.as_string(snapshot.get("confidence"))
	if not confidence.is_empty():
		parts.append("Confidence: %s" % confidence.capitalize())
	return "\n".join(parts)


func _should_route_to_museum(instance: ObjectInstance) -> bool:
	# Carrier/fragment discoveries are seated through SeatingService (MuseumEntry).
	if instance.is_carrier:
		return true
	var template: ScrapObjectTemplate = DataRepository.singleton().get_template(
		instance.template_id
	)
	if template == null:
		return false
	# Gold non-fragment finds belong in the museum, not the journal.
	if template.base_rarity == ModelEnums.Rarity.GOLD:
		return true
	return false


func _find_instance(instance_id: String) -> ObjectInstance:
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == instance_id:
			return ObjectInstance.from_dictionary(raw)
	return null


func _add_unique(items: Array[String], value: String) -> Array[String]:
	var out := items.duplicate()
	if not out.has(value):
		out.append(value)
	return out


func _save() -> void:
	SaveService.save_game()

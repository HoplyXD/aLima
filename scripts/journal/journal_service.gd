extends Node
## Maintains one stable persistent JournalEntry per restored template and routes
## archives by rarity (CLAUDE.md §4-F, JRN-R1..R3, P9.2/P9.3).
##
## Routing rule: carrier instances and Gold-and-above finds belong to the online
## museum (SeatingService handles fragments; the Phase 14/16 disposition flow
## handles non-fragment Gold). Purple-and-below restorations are archived here as
## journal entries. A single entry is created on first restoration and updated in
## place on later restorations and scans — it is never duplicated. Scanner
## annotations are written to a field distinct from the uncle's notes so the two
## never overwrite each other. The player's verdict is stored separately and never
## treated as a final scanner decision (CLAUDE.md §4-G).

const JOURNAL_RARITY_CEILING := ModelEnums.Rarity.GOLD  ## Gold and above route to the museum.


func _ready() -> void:
	EventBus.restoration_completed.connect(_on_restoration_completed)
	EventBus.scanner_verdict_committed.connect(_on_scanner_verdict_committed)


## True when an object of the given apparent rarity is archived in the journal
## (White..Purple). Gold and the Master Artifact route to the museum instead.
static func is_journal_rarity(rarity: int) -> bool:
	return rarity < JOURNAL_RARITY_CEILING


## Creates or updates the stable journal entry for a restored instance. Returns
## true when an entry was written. Carrier instances are skipped because they
## route to SeatingService/MuseumEntry. Gold-and-above instances are also skipped.
func record_restoration(inst: ObjectInstance, tool_id: String = "") -> bool:
	if inst.is_carrier:
		return false
	var template := DataRepository.singleton().get_template(inst.template_id)
	if template == null or not is_journal_rarity(template.base_rarity):
		return false

	var entry := _ensure_entry(inst.template_id, template)
	entry.best_condition = maxi(entry.best_condition, int(round(inst.condition)))
	if not tool_id.is_empty():
		var tool := DataRepository.singleton().get_tool(tool_id)
		if tool != null:
			entry.clean_method = tool.display_name

	GameState.save_state.persistent.journal_entries[inst.template_id] = entry
	SaveService.save_game()
	return true


## Updates the stable journal entry with the latest scanner annotations and the
## player's verdict. verdict_name is the string form of ModelEnums.Verdict; an
## empty string leaves the existing verdict unchanged. Returns true when written.
func record_scan(inst: ObjectInstance, verdict_name: String = "") -> bool:
	if inst.is_carrier:
		return false
	var template := DataRepository.singleton().get_template(inst.template_id)
	if template == null or not is_journal_rarity(template.base_rarity):
		return false

	var entry := _ensure_entry(inst.template_id, template)
	var record: ScannedRecord = GameState.save_state.persistent.scanned_records.get(
		inst.template_id
	)
	if record != null:
		entry.ai_annotations = _annotation_from_snapshot(record.response_snapshot)
		entry.counterfeit_indicators = _indicators_from_snapshot(record.response_snapshot)
	if not verdict_name.is_empty():
		entry.player_verdict = ModelEnums.verdict_from_name(verdict_name)

	GameState.save_state.persistent.journal_entries[inst.template_id] = entry
	SaveService.save_game()
	return true


func _on_restoration_completed(instance_id: String, _condition: float, tool_id: String) -> void:
	var inst := _find_instance(instance_id)
	if inst == null:
		return
	record_restoration(inst, tool_id)


func _on_scanner_verdict_committed(instance_id: String, verdict_name: String) -> void:
	var inst := _find_instance(instance_id)
	if inst == null:
		return
	record_scan(inst, verdict_name)


## Returns the existing entry for a template or a freshly seeded one. Authored
## template facts seed the entry; mutable progress (condition, annotations,
## verdict) is filled by the restoration/scan calls so existing entries are never
## reset.
func _ensure_entry(template_id: String, template: ScrapObjectTemplate) -> JournalEntry:
	var entries: Dictionary = GameState.save_state.persistent.journal_entries
	if entries.has(template_id):
		return entries[template_id]

	var entry := JournalEntry.new()
	entry.template_id = template_id
	entry.origin = template.display_name
	entry.materials = template.materials.duplicate()
	entry.weight_range = template.weight_range
	entry.value_range = template.base_value_range
	entry.historical_context = template.historical_fact_ref
	entry.uncle_notes = (
		"Uncle's note: a %s from the scrap stream. Worth a careful look." % template.display_name
	)
	return entry


## Builds a short advisory annotation string from a scanner response snapshot.
func _annotation_from_snapshot(snapshot: Dictionary) -> String:
	var parts: Array[String] = []
	var suggested_type := ModelUtils.as_string(snapshot.get("type"))
	if not suggested_type.is_empty():
		parts.append(suggested_type)
	var period := ModelUtils.as_string(snapshot.get("period"))
	if not period.is_empty():
		parts.append(period)
	var condition_note := ModelUtils.as_string(snapshot.get("condition_note"))
	if not condition_note.is_empty():
		parts.append(condition_note)
	return ", ".join(parts)


## Extracts counterfeit/modification indicators from a scanner response snapshot.
func _indicators_from_snapshot(snapshot: Dictionary) -> Array[String]:
	var signs: Variant = snapshot.get("modification_signs", [])
	if signs is Array:
		return ModelUtils.as_string_array(signs)
	return []


func _find_instance(uid: String) -> ObjectInstance:
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == uid:
			return ObjectInstance.from_dictionary(raw)
	return null

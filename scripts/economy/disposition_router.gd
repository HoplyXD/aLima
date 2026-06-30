extends Node
## The single typed disposition entry point for restored+judged objects (P14.3,
## DISP-R1..R6, CLAUDE.md §4-F/N). Registered as the `DispositionRouter` autoload.
##
## After restoration and scanner judgment, an eligible object can be routed to
## exactly one final disposition:
##   * SELL    — completes through MarketplaceService (loop money + best_sale; DISP-R2).
##   * RETURN  — hands the object to an identified owner/route for a non-fragment
##               reward via ReturnService (DISP-R3); never grants a fragment (§4-B/C).
##   * PRESERVE— routes Gold/historical finds to a museum record (DISP-R4, §4-F).
##   * JOURNAL — archives Purple-and-below objects in the journal (DISP-R4, §4-F),
##               reusing JournalService.
##
## Eligibility is validated up front (ownership, rarity, route state, artifact
## protection). Every disposition is idempotent: a routed instance is removed from
## loop inventory, so the same instance can never be disposed twice (DISP-R5). The
## router migrates the old direct Storage/Phone sell path onto this surface and
## emits EventBus.disposition_completed for every routed outcome.

enum Disposition { SELL, RETURN, PRESERVE, JOURNAL }

## Stable string forms emitted on EventBus.disposition_completed and stored in the
## loop disposition log.
const DISPOSITION_NAMES: Array[String] = ["SELL", "RETURN", "PRESERVE", "JOURNAL"]

var _return_service: ReturnService = ReturnService.new()


func disposition_name(disposition: int) -> String:
	if disposition < 0 or disposition >= DISPOSITION_NAMES.size():
		return ""
	return DISPOSITION_NAMES[disposition]


# --- Eligibility --------------------------------------------------------------


## True once an instance has been restored (CLEAN/OPEN) and judged (a verdict was
## committed). Both are required before any disposition is offered (DISP-R1).
func is_eligible(uid: String) -> bool:
	var found := _find(uid)
	if found.is_empty():
		return false
	var inst: ObjectInstance = found["inst"]
	return _is_restored(inst) and _is_judged(inst) and not inst.is_carrier


## The valid authored dispositions for an instance right now, as Disposition enum
## values. Empty when the instance is missing or not yet eligible (DISP-R1).
func eligible_dispositions(uid: String) -> Array[int]:
	var out: Array[int] = []
	if not is_eligible(uid):
		return out
	for d in [Disposition.SELL, Disposition.RETURN, Disposition.PRESERVE, Disposition.JOURNAL]:
		if can_dispose(uid, d).ok:
			out.append(d)
	return out


## Whether a specific disposition is currently valid for an instance. Returns
## {ok: bool, reason: String} — reason is player-facing when ok is false (DISP-R1).
func can_dispose(uid: String, disposition: int) -> Dictionary:
	var found := _find(uid)
	if found.is_empty():
		return {"ok": false, "reason": "That item is no longer available."}
	var inst: ObjectInstance = found["inst"]
	var template: ScrapObjectTemplate = found["template"]
	if inst.is_carrier:
		return {"ok": false, "reason": "This piece belongs to the discovery flow."}
	if not _is_restored(inst):
		return {"ok": false, "reason": "Restore the piece before deciding its fate."}
	if not _is_judged(inst):
		return {"ok": false, "reason": "Scan and judge the piece first."}

	match disposition:
		Disposition.SELL:
			return {"ok": true, "reason": ""}
		Disposition.RETURN:
			if DataRepository.singleton().get_return_for_template(inst.template_id).is_empty():
				return {"ok": false, "reason": "No owner is identified for this object."}
			return {"ok": true, "reason": ""}
		Disposition.PRESERVE:
			if not _is_gold_or_historical(template):
				return {"ok": false, "reason": "Only Gold/historical finds are preserved."}
			return {"ok": true, "reason": ""}
		Disposition.JOURNAL:
			if not _is_journal_rarity(template):
				return {"ok": false, "reason": "Gold finds are preserved, not journaled."}
			return {"ok": true, "reason": ""}
		_:
			return {"ok": false, "reason": "Unknown disposition."}


# --- Routing ------------------------------------------------------------------


## Routes an eligible instance to a disposition. `params` carries SELL's
## {price, buyer_id}. Returns {ok, error, disposition, outcome_id}. Idempotent: a
## routed (removed) instance cannot be disposed again (DISP-R5).
func dispose(uid: String, disposition: int, params: Dictionary = {}) -> Dictionary:
	var check := can_dispose(uid, disposition)
	if not check.ok:
		return _fail(disposition, check.reason)

	match disposition:
		Disposition.SELL:
			return _dispose_sell(uid, params)
		Disposition.RETURN:
			return _dispose_return(uid)
		Disposition.PRESERVE:
			return _dispose_preserve(uid)
		Disposition.JOURNAL:
			return _dispose_journal(uid)
		_:
			return _fail(disposition, "Unknown disposition.")


## Completes a marketplace sale through the router without re-applying the four-way
## eligibility gate. The phone marketplace already gates which buyers may transact
## (scan/condition/budget), so this is the migration seam for the existing sell flow
## (and Mr. Maverick's unscanned lowballs). Returns {ok, error, disposition,
## outcome_id}.
func complete_sell(uid: String, price: int, buyer_id: String) -> Dictionary:
	var found := _find(uid)
	if found.is_empty():
		return _fail(Disposition.SELL, "That item is no longer available.")
	return _finalize_sell(uid, price, buyer_id, found.get("template"))


func _dispose_sell(uid: String, params: Dictionary) -> Dictionary:
	var price := ModelUtils.as_int(params.get("price"))
	var buyer_id := ModelUtils.as_string(params.get("buyer_id"))
	var found := _find(uid)
	return _finalize_sell(uid, price, buyer_id, found.get("template"))


## Shared sale finalisation: MarketplaceService.complete_sale owns the credit/
## removal/best_sale/save and emits sale_completed; the router records the
## disposition, resolves the listing, and emits disposition_completed.
func _finalize_sell(
	uid: String, price: int, buyer_id: String, template: ScrapObjectTemplate
) -> Dictionary:
	var result := MarketplaceService.complete_sale(uid, price, buyer_id)
	if not result.ok:
		return _fail(Disposition.SELL, result.error)
	MarketplaceService.resolve_listing(uid, MarketplaceListing.Status.SOLD, price, buyer_id)
	_log_disposition(uid, template, Disposition.SELL, buyer_id, price)
	SaveService.save_game()  # persist the resolved listing + disposition log
	EventBus.disposition_completed.emit(uid, DISPOSITION_NAMES[Disposition.SELL], buyer_id)
	return {"ok": true, "error": "", "disposition": "SELL", "outcome_id": buyer_id}


func _dispose_return(uid: String) -> Dictionary:
	var found := _find(uid)
	var inst: ObjectInstance = found["inst"]
	var template: ScrapObjectTemplate = found["template"]
	var record := DataRepository.singleton().get_return_for_template(inst.template_id)
	var outcome := _return_service.apply_return(inst, template, record)
	if not outcome.ok:
		return _fail(Disposition.RETURN, outcome.error)
	MarketplaceService.resolve_listing(uid, MarketplaceListing.Status.WITHDRAWN, 0, "")
	_remove(uid)
	var reward_id := ModelUtils.as_string(outcome.reward_id)
	var owner_route_id := ModelUtils.as_string(outcome.owner_route_id)
	_log_disposition(uid, template, Disposition.RETURN, reward_id, 0)
	SaveService.save_game()
	EventBus.object_returned.emit(uid, owner_route_id, reward_id)
	EventBus.disposition_completed.emit(uid, DISPOSITION_NAMES[Disposition.RETURN], reward_id)
	return {"ok": true, "error": "", "disposition": "RETURN", "outcome_id": reward_id}


func _dispose_preserve(uid: String) -> Dictionary:
	var found := _find(uid)
	var inst: ObjectInstance = found["inst"]
	var template: ScrapObjectTemplate = found["template"]
	var museum_entry_id := "preserved_%s" % inst.template_id
	var museum: Dictionary = GameState.save_state.persistent.museum_entries
	if not museum.has(museum_entry_id):
		var entry := MuseumEntry.new()
		entry.artifact_id = inst.template_id
		entry.fact_card = _preserve_fact_card(template)
		museum[museum_entry_id] = entry
	MarketplaceService.resolve_listing(uid, MarketplaceListing.Status.WITHDRAWN, 0, "")
	_remove(uid)
	_log_disposition(uid, template, Disposition.PRESERVE, museum_entry_id, 0)
	SaveService.save_game()
	EventBus.disposition_completed.emit(
		uid, DISPOSITION_NAMES[Disposition.PRESERVE], museum_entry_id
	)
	return {"ok": true, "error": "", "disposition": "PRESERVE", "outcome_id": museum_entry_id}


func _dispose_journal(uid: String) -> Dictionary:
	var found := _find(uid)
	var inst: ObjectInstance = found["inst"]
	var template: ScrapObjectTemplate = found["template"]
	# Reuse the Phase 9 journal routing; record_restoration creates/updates the entry.
	JournalService.record_restoration(inst)
	MarketplaceService.resolve_listing(uid, MarketplaceListing.Status.WITHDRAWN, 0, "")
	_remove(uid)
	_log_disposition(uid, template, Disposition.JOURNAL, inst.template_id, 0)
	SaveService.save_game()
	EventBus.disposition_completed.emit(
		uid, DISPOSITION_NAMES[Disposition.JOURNAL], inst.template_id
	)
	return {"ok": true, "error": "", "disposition": "JOURNAL", "outcome_id": inst.template_id}


# --- Helpers ------------------------------------------------------------------


func _preserve_fact_card(template: ScrapObjectTemplate) -> String:
	if template == null:
		return "Preserved in the shop museum."
	return "Preserved in the shop museum: %s." % template.display_name


func _log_disposition(
	uid: String, template: ScrapObjectTemplate, disposition: int, outcome_id: String, price: int
) -> void:
	GameState.save_state.loop.disposition_log.append(
		{
			"uid": uid,
			"template_id": template.id if template != null else "",
			"disposition": DISPOSITION_NAMES[disposition],
			"outcome_id": outcome_id,
			"price": price,
			"day": GameState.save_state.loop.current_day,
		}
	)


func _fail(disposition: int, reason: String) -> Dictionary:
	return {
		"ok": false,
		"error": reason,
		"disposition": disposition_name(disposition),
		"outcome_id": "",
	}


func _is_restored(inst: ObjectInstance) -> bool:
	return inst.state == ModelEnums.ObjState.CLEAN or inst.state == ModelEnums.ObjState.OPEN


func _is_judged(inst: ObjectInstance) -> bool:
	return inst.authenticity != ModelEnums.Verdict.UNKNOWN


func _is_gold_or_historical(template: ScrapObjectTemplate) -> bool:
	return (
		template != null
		and (template.base_rarity == ModelEnums.Rarity.GOLD or template.tags.has("historical"))
	)


func _is_journal_rarity(template: ScrapObjectTemplate) -> bool:
	return template != null and JournalService.is_journal_rarity(template.base_rarity)


func _find(uid: String) -> Dictionary:
	var repo := DataRepository.singleton()
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == uid:
			var inst := ObjectInstance.from_dictionary(raw)
			return {"inst": inst, "template": repo.get_template(inst.template_id)}
	return {}


func _remove(uid: String) -> void:
	var kept: Array = []
	for raw in GameState.save_state.loop.inventory:
		if not (raw is Dictionary and raw.get("uid") == uid):
			kept.append(raw)
	GameState.save_state.loop.inventory = kept

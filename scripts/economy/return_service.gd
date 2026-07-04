class_name ReturnService
extends RefCounted
## Resolves return-to-owner outcomes for the disposition router (P14.4, DISP-R3).
##
## A return hands a restored object back to an identified owner/route instead of
## selling it. It resolves the authored route/community reward (knowledge, a lead,
## dialogue, or a legacy item) through RouteService, records a persistent return,
## and sets a story flag. It NEVER grants a fragment (CLAUDE.md §4-B/C): carriers
## are refused outright and authored return rewards are non-fragment by contract.
##
## The DispositionRouter owns instance removal and idempotency; this helper only
## applies the reward/flag/persistent record and returns the outcome reference.


## Applies the authored return for a restored instance. `record` is the
## data/marketplace return_owner dict. Returns {ok, owner_route_id, reward_id, error}.
## Does not remove the instance from inventory and does not save (the router does).
func apply_return(
	inst: ObjectInstance, _template: ScrapObjectTemplate, record: Dictionary
) -> Dictionary:
	if inst == null:
		return {"ok": false, "error": "No such item.", "owner_route_id": "", "reward_id": ""}
	# A carrier can never be "returned" for a reward — that would route a fragment to a
	# character, violating §4-B/C. Carriers flow through discovery/seating only.
	if inst.is_carrier:
		return {
			"ok": false,
			"error": "This piece belongs to the discovery flow, not a return.",
			"owner_route_id": "",
			"reward_id": "",
		}
	if record.is_empty():
		return {
			"ok": false,
			"error": "No owner is identified for this object.",
			"owner_route_id": "",
			"reward_id": "",
		}

	var owner_route_id := ModelUtils.as_string(record.get("owner_route_id"))
	var reward_id := ModelUtils.as_string(record.get("reward_id"))
	var story_flag := ModelUtils.as_string(record.get("story_flag"))
	var money_reward := ModelUtils.as_int(record.get("money_reward"))

	# Grant the authored non-fragment reward + story/dialogue flag through RouteService,
	# so returns reuse the same persistent reward conventions as route completion.
	if not reward_id.is_empty():
		RouteService.grant_reward_ids([reward_id])
	if not story_flag.is_empty():
		RouteService.set_dialogue_flag(story_flag)
	if not owner_route_id.is_empty():
		RouteService.mark_met(owner_route_id)
	if money_reward > 0:
		GameState.save_state.loop.money += money_reward

	# Persist the return itself (DISP-R6: returns survive the loop reset).
	GameState.save_state.persistent.returns.append(
		{
			"template_id": inst.template_id,
			"owner_route_id": owner_route_id,
			"reward_id": reward_id,
			"day": GameState.save_state.loop.current_day,
		}
	)

	return {"ok": true, "error": "", "owner_route_id": owner_route_id, "reward_id": reward_id}

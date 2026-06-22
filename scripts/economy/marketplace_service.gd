extends Node
## Phone Marketplace: buying tools and selling restored artifacts by haggling.
##
## Buying a tool spends `loop.money` and schedules a shipment that arrives after
## the tool's `ship_hours` of in-game time. Shipments are checked on every hour
## tick and, once due, are delivered as fresh ToolInstances into the player's
## owned tools.
##
## Selling runs through the deterministic haggle engine (Negotiation): the player
## lists a restored piece, an interested BuyerPersona opens an offer, and they
## accept or counter. A completed sale credits money, removes the instance, updates
## the persistent best-sale record, and emits EventBus.sale_completed (DISP-R2). The
## later LLM `/api/negotiate` proxy can slot in behind start_negotiation() without
## changing this surface; the offline path here is the mandatory fallback (MKT-R7).

## Linear in-game time index used to order shipments. Coarse on purpose: it only
## needs to advance monotonically with the clock so "arrive in N hours" works.
const HOURS_PER_DAY: int = 24

## Mr. Maverick: the one buyer who ALWAYS shows up to message you — but always lowballs.
const MAVERICK_ID: String = "suspicious"

## Buyer ghosting comes in three scopes:
##   * DAY (limited)    — a failed banter: the buyer skips you for the rest of the day.
##   * LOOP (permanent) — an offensive/NSFW message: the buyer skips you all loop.
##   * ARTIFACT         — Mr. Maverick only: he skips just the artifact you failed on.
## All are session state (the marketplace is loop-temporary): day ghosts clear on a new
## day; loop + artifact ghosts clear on loop reset.
var _day_ghosts: Dictionary = {}  ## buyer_id -> day they were ghosted on.
var _loop_ghosts: Array[String] = []  ## buyer_ids skipped for the whole loop.
var _artifact_ghosts: Dictionary = {}  ## item uid -> [buyer_ids] (Maverick only).

## Per-item buyer arrival times: uid -> {buyer_id: in-game minute index they show up}.
var _buyer_schedule: Dictionary = {}

## Per-loop buyer wallets: buyer_id -> remaining cash. A buyer can never offer more than
## they hold; spending an artifact draws this down, and each new day tops it up by the
## persona's daily_allowance. Mr. Maverick is unlimited and never tracked here. Lazily
## initialised from the persona's starting cash; cleared on loop reset.
var _wallets: Dictionary = {}

## Persistent (same-day) haggle sessions: "uid|buyer_id" -> Negotiation. Re-opening a
## buyer restores their conversation + standing offer, so the player can shop around other
## buyers and come back to accept. Cleared on a new day (cash changes) and on loop reset.
var _negotiations: Dictionary = {}

## Sentinel "unlimited" cash for Mr. Maverick.
const UNLIMITED_CASH: int = 1 << 30


func _ready() -> void:
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.loop_reset.connect(_on_loop_reset)


## A failed banter (the buyer walked, or you ghosted them). Normal buyers skip you for
## the day; Mr. Maverick only skips the one artifact (he always comes back for others).
func ghost_failed_banter(uid: String, buyer_id: String) -> void:
	if buyer_id == MAVERICK_ID:
		_ghost_artifact(uid, buyer_id)
	else:
		_day_ghosts[buyer_id] = GameState.save_state.loop.current_day


## An offensive/NSFW message. Normal buyers skip you for the whole loop; Mr. Maverick
## still only artifact-ghosts (he tolerates you, he just won't buy that piece).
func ghost_offensive(uid: String, buyer_id: String) -> void:
	if buyer_id == MAVERICK_ID:
		_ghost_artifact(uid, buyer_id)
	elif not _loop_ghosts.has(buyer_id):
		_loop_ghosts.append(buyer_id)


func _ghost_artifact(uid: String, buyer_id: String) -> void:
	var list: Array = _artifact_ghosts.get(uid, [])
	if not list.has(buyer_id):
		list.append(buyer_id)
	_artifact_ghosts[uid] = list


## True when `buyer_id` is currently hidden from `uid` under any ghost scope.
func is_ghosted(uid: String, buyer_id: String) -> bool:
	if (_artifact_ghosts.get(uid, []) as Array).has(buyer_id):
		return true
	if buyer_id == MAVERICK_ID:
		return false  # Maverick is never day/loop ghosted
	if _loop_ghosts.has(buyer_id):
		return true
	return _day_ghosts.get(buyer_id, -1) == GameState.save_state.loop.current_day


func _on_loop_reset(_loop_index: int) -> void:
	_day_ghosts.clear()
	_loop_ghosts.clear()
	_artifact_ghosts.clear()
	_buyer_schedule.clear()
	_wallets.clear()
	_negotiations.clear()


# --- Buyer wallets (per-loop cash) -------------------------------------------


## A buyer's remaining cash this loop. Mr. Maverick (unlimited_cash) returns the unlimited
## sentinel and is never capped. Lazily initialised from the persona's starting wallet.
func buyer_cash(buyer_id: String) -> int:
	var persona := DataRepository.singleton().get_buyer(buyer_id)
	if persona == null:
		return 0
	if persona.unlimited_cash:
		return UNLIMITED_CASH
	if not _wallets.has(buyer_id):
		_wallets[buyer_id] = persona.wallet_start()
	return int(_wallets[buyer_id])


## Draws an amount down from a buyer's wallet after a sale (no-op for Maverick).
func _deduct_cash(buyer_id: String, amount: int) -> void:
	var persona := DataRepository.singleton().get_buyer(buyer_id)
	if persona == null or persona.unlimited_cash:
		return
	_wallets[buyer_id] = maxi(0, buyer_cash(buyer_id) - maxi(0, amount))


## Tops every (non-Maverick) buyer's wallet up by their daily allowance — called on a new
## day, so leftover cash carries over and grows.
func _add_daily_allowance() -> void:
	for raw in DataRepository.singleton().get_buyers_sorted():
		var persona := raw as BuyerPersona
		if persona == null or persona.unlimited_cash or persona.daily_allowance <= 0:
			continue
		_wallets[persona.id] = buyer_cash(persona.id) + persona.daily_allowance


## Tools currently listed for purchase (authored `buyable`).
func get_catalog() -> Array[ToolDefinition]:
	var out: Array[ToolDefinition] = []
	var repo := DataRepository.singleton()
	for tool_id in repo.tool_definitions.keys():
		var def: ToolDefinition = repo.tool_definitions[tool_id]
		if def.buyable:
			out.append(def)
	out.sort_custom(func(a: ToolDefinition, b: ToolDefinition) -> bool: return a.id < b.id)
	return out


## Attempts to buy a tool. On success, deducts money and schedules a shipment.
## Returns {ok: bool, error: String, arrival_index: int}.
func buy(tool_id: String) -> Dictionary:
	var repo := DataRepository.singleton()
	var def := repo.get_tool(tool_id)
	if def == null or not def.buyable:
		return {"ok": false, "error": "That tool is not for sale.", "arrival_index": -1}

	var loop := GameState.save_state.loop
	if loop.money < def.cost:
		return {"ok": false, "error": "Not enough money.", "arrival_index": -1}

	loop.money -= def.cost
	var arrival := _now_index() + maxi(def.ship_hours, 0)
	loop.tool_shipments.append({"tool_id": tool_id, "arrival_index": arrival})
	SaveService.save_game()
	EventBus.tool_purchased.emit(tool_id, arrival)
	return {"ok": true, "error": "", "arrival_index": arrival}


## Pending shipments not yet delivered.
func get_pending_shipments() -> Array:
	return GameState.save_state.loop.tool_shipments.duplicate()


# --- Selling (deterministic haggle) ------------------------------------------


## Inventory instances ready to sell: restored (CLEAN or OPEN) AND scanned & judged. The
## player must Scan & Judge a piece (commit a verdict) before it can be listed — that's
## why an item only appears in the Marketplace after scanning.
func get_sellable() -> Array[ObjectInstance]:
	var out: Array[ObjectInstance] = []
	for raw in GameState.save_state.loop.inventory:
		if not (raw is Dictionary):
			continue
		var inst := ObjectInstance.from_dictionary(raw)
		if _is_restored(inst) and _is_judged(inst):
			out.append(inst)
	return out


## True once the player has committed a scan verdict on the instance.
func _is_judged(inst: ObjectInstance) -> bool:
	return inst.authenticity != ModelEnums.Verdict.UNKNOWN


## The assessed value of an instance: its recorded value if set, else the template's
## mid base value. This is the anchor the buyer negotiates around.
func assessed_value(uid: String) -> int:
	var found := _find_instance(uid)
	if found.is_empty():
		return 0
	var inst: ObjectInstance = found["inst"]
	var template: ScrapObjectTemplate = found["template"]
	if inst.value > 0:
		return inst.value
	if template == null:
		return 0
	return int(round((template.base_value_range.x + template.base_value_range.y) / 2.0))


## Buyers worth pitching this item to: those whose budget can make a meaningful offer.
## Falls back to every persona so the player can always try to sell something.
func interested_buyers(uid: String) -> Array[BuyerPersona]:
	var value := assessed_value(uid)
	var out: Array[BuyerPersona] = []
	# Mr. Maverick shows up first — unless he's artifact-ghosted for THIS item (he never
	# day/loop ghosts, but a failed banter / offence on a piece does block that piece).
	var maverick := DataRepository.singleton().get_buyer(MAVERICK_ID)
	if maverick != null and not is_ghosted(uid, MAVERICK_ID):
		out.append(maverick)
	for raw in DataRepository.singleton().get_buyers_sorted():
		var persona := raw as BuyerPersona
		if persona == null or persona.id == MAVERICK_ID:
			continue
		if is_ghosted(uid, persona.id):
			continue  # a buyer you failed/ghosted won't return for this item
		if persona.budget_range.y >= int(round(value * 0.35)):
			out.append(persona)
	if out.is_empty() and maverick != null and not is_ghosted(uid, MAVERICK_ID):
		out.append(maverick)
	return out


## Buyers who have ACTUALLY shown up for `uid` so far. Mr. Maverick is here at once;
## the rest arrive over in-game time (1-20 in-game minutes apart). Because arrival is
## time-based — not a UI timer — the set persists across opening/closing the phone, and
## new buyers keep arriving while the phone is closed (the clock keeps running). Once a
## buyer has arrived they stay (until ghosted). This is what the phone shows.
func arrived_buyers(uid: String) -> Array[BuyerPersona]:
	var eligible := interested_buyers(uid)
	_ensure_schedule(uid, eligible)
	var now := _minute_index()
	var schedule: Dictionary = _buyer_schedule[uid]
	var out: Array[BuyerPersona] = []
	for persona in eligible:
		if int(schedule.get(persona.id, 0)) <= now:
			out.append(persona)
	# Order the list by when each buyer arrived: the first to show up sits at the top,
	# the most recent at the bottom (Mr. Maverick is scheduled at "now", so he leads).
	out.sort_custom(
		func(a: BuyerPersona, b: BuyerPersona) -> bool:
			return int(schedule.get(a.id, 0)) < int(schedule.get(b.id, 0))
	)
	return out


## The buyer's current standing offer for this item, for the picker list. Uses their live
## haggle session if one is open, otherwise a fresh opening offer (without starting a
## session). 0 if the item can't be sold.
func preview_offer(uid: String, persona_id: String) -> int:
	var key := "%s|%s" % [uid, persona_id]
	if _negotiations.has(key):
		return (_negotiations[key] as Negotiation).current_offer
	var probe := start_negotiation(uid, persona_id)
	return probe.current_offer if probe != null else 0


## Assigns an arrival time (in-game minute index) to any newly-eligible buyer for `uid`
## that doesn't have one yet. Mr. Maverick is always instant (he's always the first to
## message); every OTHER buyer arrives in a RANDOMISED order, each 1-20 in-game minutes
## after the previous — so who shows up second/third differs each run. Seeded per item +
## loop so it's stable while the player shops (and re-rolls on a new loop). Stable once set.
func _ensure_schedule(uid: String, eligible: Array[BuyerPersona]) -> void:
	var schedule: Dictionary = _buyer_schedule.get(uid, {})
	var now := _minute_index()
	var others: Array = []
	for persona in eligible:
		if schedule.has(persona.id):
			continue
		if persona.id == MAVERICK_ID:
			schedule[persona.id] = now
		else:
			others.append(persona)
	if not others.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(uid) ^ (GameState.loop_index * 2654435761)
		_shuffle(others, rng)
		var latest := now
		for at in schedule.values():
			latest = maxi(latest, int(at))
		for persona in others:
			latest += rng.randi_range(1, 20)
			schedule[persona.id] = latest
	_buyer_schedule[uid] = schedule


## Seeded Fisher-Yates shuffle (so arrival order is reproducible per item + loop).
func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Monotonic in-game minute index from the global clock (pauses when the clock pauses).
func _minute_index() -> int:
	return (DayClock.get_day() * 24 + DayClock.get_hour()) * 60 + DayClock.get_minute()


## Opens a haggle session for an item with one buyer, or null if it can't be sold. The
## buyer's ceiling is capped by their remaining wallet (Maverick is unlimited).
func start_negotiation(uid: String, persona_id: String) -> Negotiation:
	var found := _find_instance(uid)
	if found.is_empty():
		return null
	var inst: ObjectInstance = found["inst"]
	var template: ScrapObjectTemplate = found["template"]
	if not _is_restored(inst):
		return null
	var persona := DataRepository.singleton().get_buyer(persona_id)
	if persona == null:
		return null
	var category := template.category if template != null else ""
	return Negotiation.open(
		persona, assessed_value(uid), int(round(inst.condition)), category, true, buyer_cash(persona_id)
	)


## The persistent (same-day) haggle session for this item + buyer — created on first open
## and reused afterwards, so a buyer's conversation and standing offer survive while the
## player shops around other buyers and comes back. Null if the item can't be sold.
func haggle_for(uid: String, persona_id: String) -> Negotiation:
	var key := "%s|%s" % [uid, persona_id]
	if _negotiations.has(key):
		return _negotiations[key]
	var n := start_negotiation(uid, persona_id)
	if n != null:
		_negotiations[key] = n
	return n


func _clear_negotiations_for(uid: String) -> void:
	for key in _negotiations.keys():
		if str(key).begins_with(uid + "|"):
			_negotiations.erase(key)


## Finalises a sale: credits money, removes the instance, updates the persistent
## best-sale record, and emits sale_completed. Idempotent — an item already gone (or
## a non-positive price) cannot be sold again (DISP-R5). Returns {ok, error, price}.
func complete_sale(uid: String, price: int, buyer_id: String) -> Dictionary:
	if price <= 0:
		return {"ok": false, "error": "No deal was reached.", "price": 0}
	var found := _find_instance(uid)
	if found.is_empty():
		return {"ok": false, "error": "That item is no longer available.", "price": 0}
	var inst: ObjectInstance = found["inst"]
	var template: ScrapObjectTemplate = found["template"]
	if not _is_restored(inst):
		return {"ok": false, "error": "Only restored pieces can be sold.", "price": 0}

	var loop := GameState.save_state.loop
	loop.money += price
	_deduct_cash(buyer_id, price)  # the buyer spends from their wallet
	_clear_negotiations_for(uid)  # the item is gone; drop its cached haggles
	_remove_instance(uid)
	_record_best_sale(price, template, buyer_id, inst.condition, loop.current_day)
	SaveService.save_game()
	EventBus.sale_completed.emit(uid, buyer_id, price)
	return {"ok": true, "error": "", "price": price}


func _is_restored(inst: ObjectInstance) -> bool:
	return inst.state == ModelEnums.ObjState.CLEAN or inst.state == ModelEnums.ObjState.OPEN


func _find_instance(uid: String) -> Dictionary:
	var repo := DataRepository.singleton()
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == uid:
			var inst := ObjectInstance.from_dictionary(raw)
			return {"inst": inst, "template": repo.get_template(inst.template_id)}
	return {}


func _remove_instance(uid: String) -> void:
	var kept: Array = []
	for raw in GameState.save_state.loop.inventory:
		if not (raw is Dictionary and raw.get("uid") == uid):
			kept.append(raw)
	GameState.save_state.loop.inventory = kept


func _record_best_sale(
	price: int, template: ScrapObjectTemplate, buyer_id: String, condition: float, day: int
) -> void:
	var best: Dictionary = GameState.save_state.persistent.best_sale
	if best.is_empty() or price > ModelUtils.as_int(best.get("price")):
		GameState.save_state.persistent.best_sale = {
			"price": price,
			"template_id": template.id if template != null else "",
			"buyer_id": buyer_id,
			"condition": int(round(condition)),
			"day": day,
		}


## Delivers every shipment whose arrival time has passed. Returns the number
## delivered. Safe to call repeatedly (idempotent once the queue is drained).
func deliver_due(day: int, hour: int) -> int:
	var now := _time_index(day, hour)
	var loop := GameState.save_state.loop
	var remaining: Array = []
	var delivered := 0
	var tools := ToolService.new(GameState, DataRepository.singleton())
	for shipment in loop.tool_shipments:
		if not shipment is Dictionary:
			continue
		if ModelUtils.as_int(shipment.get("arrival_index"), 0) <= now:
			var tool_id := ModelUtils.as_string(shipment.get("tool_id"))
			var inst := tools.grant_tool(tool_id)
			delivered += 1
			EventBus.tool_arrived.emit(tool_id, inst.uid)
		else:
			remaining.append(shipment)
	if delivered > 0:
		loop.tool_shipments = remaining
		SaveService.save_game()
	return delivered


func _on_hour_changed(day: int, hour: int) -> void:
	deliver_due(day, hour)


func _on_day_changed(day: int) -> void:
	_day_ghosts.clear()  # a new day forgives the day-scoped (failed-banter) ghosts
	_add_daily_allowance()  # buyers' wallets top up; leftover cash carries over
	_negotiations.clear()  # haggles reset each day (cash and mood are fresh)
	deliver_due(day, GameState.save_state.loop.current_hour)


func _now_index() -> int:
	var loop := GameState.save_state.loop
	return _time_index(loop.current_day, loop.current_hour)


static func _time_index(day: int, hour: int) -> int:
	return day * HOURS_PER_DAY + hour

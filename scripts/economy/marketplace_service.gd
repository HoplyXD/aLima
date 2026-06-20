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


func _ready() -> void:
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.day_changed.connect(_on_day_changed)


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


## Restorable inventory instances that are restored enough to sell (CLEAN or OPEN).
func get_sellable() -> Array[ObjectInstance]:
	var out: Array[ObjectInstance] = []
	for raw in GameState.save_state.loop.inventory:
		if not (raw is Dictionary):
			continue
		var inst := ObjectInstance.from_dictionary(raw)
		if _is_restored(inst):
			out.append(inst)
	return out


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
	for raw in DataRepository.singleton().get_buyers_sorted():
		var persona := raw as BuyerPersona
		if persona != null and persona.budget_range.y >= int(round(value * 0.35)):
			out.append(persona)
	if out.is_empty():
		for raw in DataRepository.singleton().get_buyers_sorted():
			out.append(raw as BuyerPersona)
	return out


## Opens a haggle session for an item with one buyer, or null if it can't be sold.
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
	return Negotiation.open(persona, assessed_value(uid), int(round(inst.condition)), category)


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
	deliver_due(day, GameState.save_state.loop.current_hour)


func _now_index() -> int:
	var loop := GameState.save_state.loop
	return _time_index(loop.current_day, loop.current_hour)


static func _time_index(day: int, hour: int) -> int:
	return day * HOURS_PER_DAY + hour

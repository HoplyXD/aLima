extends Node
## Phone Marketplace: buying tools (selling is deferred to the economy phase).
##
## Buying a tool spends `loop.money` and schedules a shipment that arrives after
## the tool's `ship_hours` of in-game time. Shipments are checked on every hour
## tick and, once due, are delivered as fresh ToolInstances into the player's
## owned tools. Selling restored artifacts (and the online buyer banter) is the
## Phase-14 server-side negotiation and is intentionally not implemented here.

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

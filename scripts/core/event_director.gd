extends Node
## Data-driven mini-event director for Phase 18.
##
## EventDirector is the single authority for triggering, capping, and resolving
## the eight GDD-named mini-events. It stores all event state in LoopState so it
## resets cleanly on loop_reset, and it never corrupts persistent knowledge.
##
## Outcomes are bounded and routed through existing contracts only:
##   * Rush Delivery / Mystery Box -> DeliveryGenerator/delivery config
##   * Tool Breakdown -> ToolInstance durability + EventBus.tool_broke
##   * Rainy-Day Leak / Sudden Brownout -> restoration/shop-condition modifiers
##   * Rare Buyer Alert -> MarketplaceService buyer set
##   * Community Request / Suspicious Antique -> existing object/restoration/scanner flow
##
## Production triggering uses data-tunable weighted selection from the run-local
## seed. A separate QA override (force_event) is gated behind OS.is_debug_build()
## or an explicit debug flag so it cannot fire in normal play.

const EVENT_STREAM := "event_director"
const MAX_EVENTS_PER_LOOP: int = 5
const MAX_DISRUPTIVE_PER_LOOP: int = 2
const MIN_SECONDS_PER_HOUR: float = 30.0
## Event-injected items must be REAL artifacts (a folder scene) — never scene-less placeholders.
const _ArtifactScenes := preload("res://scripts/restoration/artifact_scenes.gd")
const _ArtifactCatalog := preload("res://scripts/restoration/artifact_catalog.gd")

## Debug-only backdoor for deterministic QA. Never enabled in production.
var _debug_force_enabled: bool = false

var _repo: DataRepository
var _game_state: GameState

## Snapshot of DayClock.seconds_per_hour before an event modified it, so we can
## restore when the event expires.
var _original_seconds_per_hour: float = -1.0

static var _uid_counter: int = 0


func _ready() -> void:
	_repo = DataRepository.singleton()
	_game_state = GameState
	EventBus.hour_changed.connect(_on_hour_changed)
	# Morning events are rolled explicitly by ShopController when the morning
	# delivery is generated, not on every day_changed, so clock/shop tests that
	# call DayClock.start_day() directly are not surprised by event modifiers.
	EventBus.loop_reset.connect(_on_loop_reset)
	EventBus.restoration_completed.connect(_on_restoration_completed)
	EventBus.scanner_verdict_committed.connect(_on_scanner_verdict_committed)
	EventBus.object_opened.connect(_on_object_opened)
	EventBus.sale_completed.connect(_on_sale_completed)
	EventBus.tool_broke.connect(_on_tool_broke)


## ---------------------------------------------------------------------------
## Public queries (existing services consult these)
## ---------------------------------------------------------------------------


## Returns the authored definition, or null if unknown / repo not loaded.
func get_event_definition(event_id: String) -> EventDefinition:
	if _repo == null or not _repo.is_loaded():
		return null
	return _repo.get_event(event_id)


## True while the named event is currently active.
func is_event_active(event_id: String) -> bool:
	for raw in _game_state.save_state.loop.event_active:
		if raw is Dictionary and ModelUtils.as_string(raw.get("event_id")) == event_id:
			return true
	return false


## All currently active events as readable state dictionaries.
func get_active_events() -> Array:
	return _game_state.save_state.loop.event_active.duplicate()


## Modify a delivery config for active events (Rush Delivery + Rainy-Day Leak).
## Returns a fresh DeliveryConfig with adjusted batch bounds.
func modify_delivery_config(base_cfg: DeliveryConfig) -> DeliveryConfig:
	var cfg := DeliveryConfig.new()
	cfg.schema_version = base_cfg.schema_version
	cfg.batch_min = base_cfg.batch_min
	cfg.batch_max = base_cfg.batch_max
	cfg.storage_cap = base_cfg.storage_cap
	cfg.rarity_weights = base_cfg.rarity_weights.duplicate()

	if is_event_active("rush_delivery"):
		var bonus := ModelUtils.as_int(_get_event_param("rush_delivery", "batch_size_bonus", 1))
		cfg.batch_max = clampi(cfg.batch_max + bonus, cfg.batch_min, cfg.batch_max + bonus)

	if is_event_active("rainy_day_leak"):
		# Damp deliveries are slightly smaller but messier.
		cfg.batch_max = maxi(cfg.batch_max - 1, cfg.batch_min)

	return cfg


## Multiplier applied to DayClock.seconds_per_hour while Rush Delivery is active.
func get_seconds_per_hour_multiplier() -> float:
	if not is_event_active("rush_delivery"):
		return 1.0
	var mult := ModelUtils.as_float(
		_get_event_param("rush_delivery", "seconds_per_hour_multiplier", 1.0)
	)
	return maxf(mult, MIN_SECONDS_PER_HOUR)


## Multiplier applied to restoration condition gain while active events impose
## a condition penalty. Each active event with `condition_multiplier < 1.0` may
## also set `light_mitigates_condition: true`; when a light source is active,
## that event's penalty is ignored (e.g. phone flashlight during a brownout).
## Rainy-Day Leak / damp penalties are not flagged as mitigable, so they always
## apply. The result is clamped to a small minimum so progress never stalls.
func get_restoration_condition_multiplier() -> float:
	var mult := 1.0
	for raw in _game_state.save_state.loop.event_active:
		if not raw is Dictionary:
			continue
		var event_id := ModelUtils.as_string(raw.get("event_id"))
		var def := get_event_definition(event_id)
		if def == null:
			continue
		var event_mult := ModelUtils.as_float(def.outcome_params.get("condition_multiplier", 1.0))
		if event_mult >= 1.0:
			continue
		var mitigates := ModelUtils.as_bool(
			def.outcome_params.get("light_mitigates_condition", false)
		)
		if mitigates and is_light_source_active():
			continue
		mult = minf(mult, event_mult)
	return maxf(mult, 0.1)


## True when the player currently has an active light source. For Phase 18 this
## is just the phone flashlight; future light sources can be OR'd in here.
func is_light_source_active() -> bool:
	return _game_state.save_state.loop.flashlight_on


## True when the phone marketplace is reachable. During Sudden Brownout the
## internet is down, so the online Marketplace is unavailable (the phone itself
## still works and offline apps such as the flashlight remain usable).
func is_marketplace_available() -> bool:
	if not is_event_active("sudden_brownout"):
		return true
	return not ModelUtils.as_bool(_get_event_param("sudden_brownout", "blocks_marketplace", false))


## True when a tool is blocked by Sudden Brownout (electric tools).
func is_tool_blocked(tool_id: String) -> bool:
	if not is_event_active("sudden_brownout"):
		return false
	var def := _repo.get_tool(tool_id)
	if def == null:
		return false
	var blocked: Array = ModelUtils.as_string_array(
		_get_event_param("sudden_brownout", "blocked_tool_enables", [])
	)
	for enable in def.enables:
		if blocked.has(enable):
			return true
	return false


## Extra object instances injected by morning events (Community Request / Mystery Box).
func get_injected_delivery_extras(day: int) -> Array[ObjectInstance]:
	var extras: Array[ObjectInstance] = []
	for raw in _game_state.save_state.loop.event_active:
		if not raw is Dictionary:
			continue
		var event_id := ModelUtils.as_string(raw.get("event_id"))
		if event_id == "community_request":
			extras.append(_make_request_instance(day))
		elif event_id == "mystery_box":
			extras.append(_make_mystery_box_instance(day))
		elif event_id == "suspicious_antique":
			extras.append(_make_suspicious_antique_instance(day))
	return extras


## Returns the rare buyer persona id currently boosted, or "".
func get_rare_buyer_override() -> String:
	if not is_event_active("rare_buyer_alert"):
		return ""
	return ModelUtils.as_string(_get_event_param("rare_buyer_alert", "buyer_persona_id", ""))


## Delay (in hours) added to pending shipments by Rainy-Day Leak.
func get_shipment_delay_hours() -> int:
	if not is_event_active("rainy_day_leak"):
		return 0
	return ModelUtils.as_int(_get_event_param("rainy_day_leak", "shipment_delay_hours", 0))


## Extra surface conditions appended to ordinary delivered instances while
## Rainy-Day Leak is active.
func get_extra_conditions_for_delivery() -> Array[Dictionary]:
	if not is_event_active("rainy_day_leak"):
		return []
	var condition_id := ModelUtils.as_string(
		_get_event_param("rainy_day_leak", "extra_condition_type", "")
	)
	var count := ModelUtils.as_int(_get_event_param("rainy_day_leak", "extra_condition_count", 0))
	if condition_id.is_empty() or count <= 0:
		return []
	var condition := _repo.get_surface_condition(condition_id)
	if condition == null:
		return []
	var out: Array[Dictionary] = []
	for i in count:
		(
			out
			. append(
				{
					"id": "%s_event_%d" % [condition_id, i],
					"type": condition_id,
					"color": condition.color,
					"required_tool": condition.cleaning_tool,
				}
			)
		)
	return out


## ---------------------------------------------------------------------------
## Production triggering
## ---------------------------------------------------------------------------


## Call once at the start of each day to potentially trigger a morning event.
func roll_morning_event(day: int) -> void:
	var eligible := _eligible_events(day, 7)
	_trigger_weighted(eligible, day, 7)


## Called on every hour tick to roll random-duration events.
func roll_random_event(day: int, hour: int) -> void:
	var eligible := _eligible_events(day, hour)
	# Only events that are not morning-only fire here.
	var filtered: Array[EventDefinition] = []
	for e in eligible:
		if not e.can_trigger(day, 7):
			filtered.append(e)
		elif e.trigger_conditions.get("eligible_hours", []).is_empty():
			filtered.append(e)
	_trigger_weighted(filtered, day, hour)


## ---------------------------------------------------------------------------
## QA override (debug-gated)
## ---------------------------------------------------------------------------


## Forces a specific event to become active immediately. Only available in debug
## builds or when enable_debug_force() has been called explicitly (e.g. tests).
## The QA override bypasses day/hour eligibility but still respects the per-loop
## cap so it cannot be used to validate an impossible spam scenario.
func force_event(event_id: String) -> bool:
	if not _can_use_debug_force():
		push_warning("EventDirector.force_event blocked in production: %s" % event_id)
		return false
	var def := get_event_definition(event_id)
	if def == null:
		return false
	if _event_count_this_loop(event_id) >= def.per_loop_cap:
		return false
	_activate_event(
		def, _game_state.save_state.loop.current_day, _game_state.save_state.loop.current_hour
	)
	return true


## Enables the debug force-event API for deterministic QA. Tests must call this;
## production builds never can.
func enable_debug_force() -> void:
	_debug_force_enabled = true


func disable_debug_force() -> void:
	_debug_force_enabled = false


## ---------------------------------------------------------------------------
## Internal event lifecycle
## ---------------------------------------------------------------------------


func _on_loop_reset(_loop_index: int) -> void:
	_game_state.save_state.loop.event_active.clear()
	_game_state.save_state.loop.event_history.clear()
	_game_state.save_state.loop.event_caps.clear()
	_game_state.save_state.loop.event_outcomes.clear()
	_restore_clock_speed()


func _on_hour_changed(day: int, hour: int) -> void:
	_expire_events(day, hour)
	roll_random_event(day, hour)
	_apply_rainy_day_shipment_delay()


func _activate_event(event_def: EventDefinition, day: int, hour: int) -> void:
	if is_event_active(event_def.id):
		return
	var expires := hour + event_def.duration_hours
	if event_def.duration_hours <= 0:
		expires = -1
	(
		_game_state
		. save_state
		. loop
		. event_active
		. append(
			{
				"event_id": event_def.id,
				"day": day,
				"hour": hour,
				"expires_hour": expires,
				"resolved": false,
			}
		)
	)
	_game_state.save_state.loop.event_history.append(event_def.id)
	_bump_cap(event_def.category)
	EventBus.event_triggered.emit(
		event_def.id,
		event_def.display_name,
		event_def.text("changed_rules"),
		event_def.text("consequences"),
		event_def.accessibility_caption
	)
	_apply_immediate_outcomes(event_def, day)


func _expire_events(_day: int, hour: int) -> void:
	var kept: Array = []
	var expired_ids: Array[String] = []
	for raw in _game_state.save_state.loop.event_active:
		if not raw is Dictionary:
			continue
		var event_id := ModelUtils.as_string(raw.get("event_id"))
		var expires := ModelUtils.as_int(raw.get("expires_hour"), -1)
		if expires >= 0 and hour >= expires:
			expired_ids.append(event_id)
			var def := get_event_definition(event_id)
			if def != null:
				EventBus.event_expired.emit(event_id, def.display_name)
		else:
			kept.append(raw)
	if expired_ids.size() > 0:
		_game_state.save_state.loop.event_active = kept
		_restore_clock_speed()


func _trigger_weighted(eligible: Array[EventDefinition], day: int, hour: int) -> void:
	if eligible.is_empty():
		return
	if _game_state.save_state.loop.event_history.size() >= MAX_EVENTS_PER_LOOP:
		return
	if _cap_remaining("disruptive") <= 0:
		# Still allow opportunities if disruptive cap is exhausted.
		var still_eligible: Array[EventDefinition] = []
		for e in eligible:
			if e.category != "disruptive":
				still_eligible.append(e)
		eligible = still_eligible
		if eligible.is_empty():
			return

	var rng := _game_state.make_rng(EVENT_STREAM + "_%d_%d" % [day, hour])
	var total := 0.0
	for e in eligible:
		total += e.weight()
	if total <= 0.0:
		return
	var roll := rng.randf() * total
	for e in eligible:
		roll -= e.weight()
		if roll <= 0.0:
			_activate_event(e, day, hour)
			return
	# Fallback to last item on floating-point edge.
	_activate_event(eligible[eligible.size() - 1], day, hour)


func _eligible_events(day: int, hour: int) -> Array[EventDefinition]:
	var out: Array[EventDefinition] = []
	if _repo == null or not _repo.is_loaded():
		return out
	for event_id in _repo.event_definitions.keys():
		var def := _repo.event_definitions[event_id] as EventDefinition
		if def == null:
			continue
		if not def.can_trigger(day, hour):
			continue
		if is_event_active(event_id):
			continue
		if _event_count_this_loop(event_id) >= def.per_loop_cap:
			continue
		if _cap_remaining(def.category) <= 0:
			continue
		if _on_cooldown(event_id, day, hour):
			continue
		out.append(def)
	return out


func _event_count_this_loop(event_id: String) -> int:
	var count := 0
	for raw in _game_state.save_state.loop.event_history:
		if raw is String and raw == event_id:
			count += 1
	return count


func _bump_cap(category: String) -> void:
	var caps: Dictionary = _game_state.save_state.loop.event_caps
	caps[category] = ModelUtils.as_int(caps.get(category)) + 1


func _cap_remaining(category: String) -> int:
	var caps: Dictionary = _game_state.save_state.loop.event_caps
	var used := ModelUtils.as_int(caps.get(category))
	if category == "disruptive":
		return MAX_DISRUPTIVE_PER_LOOP - used
	return 999  # opportunities only bounded by the global loop cap


func _on_cooldown(event_id: String, day: int, hour: int) -> bool:
	var def := get_event_definition(event_id)
	if def == null or def.cooldown_hours <= 0:
		return false
	for raw in _game_state.save_state.loop.event_active:
		if not raw is Dictionary:
			continue
		if ModelUtils.as_string(raw.get("event_id")) != event_id:
			continue
		var trigger_day := ModelUtils.as_int(raw.get("day"))
		var trigger_hour := ModelUtils.as_int(raw.get("hour"))
		var elapsed := (day - trigger_day) * 24 + (hour - trigger_hour)
		if elapsed < def.cooldown_hours:
			return true
	return false


## ---------------------------------------------------------------------------
## Outcome application
## ---------------------------------------------------------------------------


func _apply_immediate_outcomes(event_def: EventDefinition, day: int) -> void:
	match event_def.id:
		"rush_delivery":
			_apply_rush_delivery()
		"tool_breakdown":
			_apply_tool_breakdown()
		"rare_buyer_alert":
			_apply_rare_buyer_alert()
		"community_request", "mystery_box", "suspicious_antique":
			# These add instances to the next delivery; handled by get_injected_delivery_extras.
			_record_outcome(event_def.id, "injected_instance", {"day": day})
		_:
			_record_outcome(
				event_def.id,
				"started",
				{"day": day, "hour": _game_state.save_state.loop.current_hour}
			)


func _apply_rush_delivery() -> void:
	var mult := ModelUtils.as_float(
		_get_event_param("rush_delivery", "seconds_per_hour_multiplier", 1.0)
	)
	var min_sph := ModelUtils.as_float(
		_get_event_param("rush_delivery", "min_seconds_per_hour", MIN_SECONDS_PER_HOUR)
	)
	mult = maxf(mult, min_sph / maxf(DayClock.seconds_per_hour, 0.001))
	if _original_seconds_per_hour < 0.0:
		_original_seconds_per_hour = DayClock.seconds_per_hour
	DayClock.seconds_per_hour = maxf(DayClock.seconds_per_hour * mult, min_sph)


func _restore_clock_speed() -> void:
	if _original_seconds_per_hour >= 0.0:
		DayClock.seconds_per_hour = _original_seconds_per_hour
		_original_seconds_per_hour = -1.0


func _apply_tool_breakdown() -> void:
	var tools := ToolService.new(_game_state, _repo)
	var owned := tools.get_owned_tools()
	var excluded: Array[String] = ModelUtils.as_string_array(
		_get_event_param("tool_breakdown", "excluded_tool_ids", [])
	)
	excluded.append_array(_required_tools_for_released_fragments())

	# Never break a tool the player has loaded on the bench — that reads as a random,
	# unfair loss. The breakdown only ever consumes a spare (owned-but-unequipped) tool.
	var equipped: Array = _game_state.save_state.loop.workbench_tools
	var candidates: Array[ToolInstance] = []
	for inst in owned:
		if inst.is_infinite() or inst.is_broken():
			continue
		if excluded.has(inst.tool_id):
			continue
		if equipped.has(inst.uid):
			continue
		candidates.append(inst)

	if candidates.is_empty():
		# Nothing safe to break; record a no-op outcome rather than making a fragment
		# unwinnable.
		_record_outcome("tool_breakdown", "no_breakable_tool", {})
		return

	var rng := _game_state.make_rng(EVENT_STREAM + "_tool_break")
	var victim := candidates[rng.randi_range(0, candidates.size() - 1)]
	_break_tool_instance(victim)


func _break_tool_instance(inst: ToolInstance) -> void:
	var owned: Array = _game_state.save_state.loop.owned_tools
	for i in range(owned.size()):
		var raw = owned[i]
		if raw is Dictionary and ModelUtils.as_string(raw.get("uid")) == inst.uid:
			# Break the tool but keep it in storage (durability 0) so it does not vanish from
			# the player's data; it only leaves the bench loadout.
			raw["durability"] = 0
			owned[i] = raw
			_game_state.save_state.loop.workbench_tools.erase(inst.uid)
			EventBus.tool_broke.emit(inst.tool_id, inst.uid)
			_record_outcome(
				"tool_breakdown", "tool_broke", {"tool_id": inst.tool_id, "uid": inst.uid}
			)
			return


func _apply_rare_buyer_alert() -> void:
	var def := get_event_definition("rare_buyer_alert")
	if def == null:
		return
	var buyer_id := ModelUtils.as_string(def.outcome_params.get("buyer_persona_id", ""))
	var bonus := ModelUtils.as_int(def.outcome_params.get("wallet_bonus", 0))
	if buyer_id.is_empty() or bonus <= 0:
		return
	# MarketplaceService exposes public seams so events can boost a buyer and make
	# them arrive immediately without rewriting the wallet/schedule logic.
	if MarketplaceService != null:
		MarketplaceService.add_wallet_top_up(buyer_id, bonus)
		if ModelUtils.as_bool(def.outcome_params.get("arrives_immediately", false)):
			MarketplaceService.force_buyer_arrival(buyer_id)
	_record_outcome("rare_buyer_alert", "buyer_boosted", {"buyer_id": buyer_id, "bonus": bonus})


func _apply_rainy_day_shipment_delay() -> void:
	if not is_event_active("rainy_day_leak"):
		return
	var delay := get_shipment_delay_hours()
	if delay <= 0:
		return
	var shipments: Array = _game_state.save_state.loop.tool_shipments
	var changed := false
	for shipment in shipments:
		if shipment is Dictionary:
			var arrival := ModelUtils.as_int(shipment.get("arrival_index"))
			if not shipment.has("event_delayed"):
				shipment["arrival_index"] = arrival + delay
				shipment["event_delayed"] = true
				changed = true
	if changed:
		_game_state.save_state.loop.tool_shipments = shipments


## ---------------------------------------------------------------------------
## Event-resolution listeners
## ---------------------------------------------------------------------------


func _on_restoration_completed(instance_id: String, _condition: float, _tool_id: String) -> void:
	_resolve_community_request(instance_id, "restored")


func _on_scanner_verdict_committed(instance_id: String, verdict: String) -> void:
	_resolve_suspicious_antique(instance_id, verdict)


func _on_object_opened(instance_id: String, result: String, _content_id: String) -> void:
	if result == "temporal_echo":
		_resolve_mystery_box_echo(instance_id)


func _on_sale_completed(instance_id: String, buyer_id: String, price: int) -> void:
	_resolve_community_request(instance_id, "sold", buyer_id, price)


func _on_tool_broke(tool_id: String, uid: String) -> void:
	# Record any externally-triggered break as an outcome if not already recorded.
	for outcome in _game_state.save_state.loop.event_outcomes:
		if (
			outcome is Dictionary
			and ModelUtils.as_string(outcome.get("event_id")) == "tool_breakdown"
		):
			var data: Dictionary = ModelUtils.as_dictionary(outcome.get("data"))
			if ModelUtils.as_string(data.get("uid")) == uid:
				return
	_record_outcome("tool_breakdown", "tool_broke", {"tool_id": tool_id, "uid": uid})


func _resolve_community_request(
	instance_id: String, resolution: String, buyer_id: String = "", price: int = 0
) -> void:
	for raw in _game_state.save_state.loop.event_active:
		if not raw is Dictionary:
			continue
		if ModelUtils.as_string(raw.get("event_id")) != "community_request":
			continue
		if ModelUtils.as_bool(raw.get("resolved")):
			continue
		var tracked_uid := ModelUtils.as_string(raw.get("request_instance_uid"))
		if tracked_uid.is_empty() or tracked_uid != instance_id:
			continue
		raw["resolved"] = true
		var def := get_event_definition("community_request")
		var reward := ModelUtils.as_int(def.outcome_params.get("reward_money", 0))
		var lead := ModelUtils.as_string(def.outcome_params.get("reward_lead", ""))
		if reward > 0:
			_game_state.save_state.loop.money += reward
		if not lead.is_empty() and not _game_state.save_state.persistent.leads.has(lead):
			_game_state.save_state.persistent.leads.append(lead)
		_record_outcome(
			"community_request",
			"fulfilled",
			{
				"instance_id": instance_id,
				"resolution": resolution,
				"buyer_id": buyer_id,
				"price": price,
				"reward_money": reward,
				"reward_lead": lead,
			}
		)
		return


func _resolve_suspicious_antique(instance_id: String, verdict: String) -> void:
	for raw in _game_state.save_state.loop.event_active:
		if not raw is Dictionary:
			continue
		if ModelUtils.as_string(raw.get("event_id")) != "suspicious_antique":
			continue
		if ModelUtils.as_bool(raw.get("resolved")):
			continue
		var tracked_uid := ModelUtils.as_string(raw.get("antique_instance_uid"))
		if tracked_uid.is_empty() or tracked_uid != instance_id:
			continue
		raw["resolved"] = true
		var def := get_event_definition("suspicious_antique")
		var correct: Array = ModelUtils.as_string_array(
			def.outcome_params.get("correct_verdicts", [])
		)
		var reward := 0
		if correct.has(verdict.to_lower()):
			reward = ModelUtils.as_int(def.outcome_params.get("reward_money_correct_judgment", 0))
			_game_state.save_state.loop.money += reward
		_record_outcome(
			"suspicious_antique",
			"judged",
			{"instance_id": instance_id, "verdict": verdict, "reward_money": reward}
		)
		return


func _resolve_mystery_box_echo(instance_id: String) -> void:
	for raw in _game_state.save_state.loop.event_active:
		if not raw is Dictionary:
			continue
		if ModelUtils.as_string(raw.get("event_id")) != "mystery_box":
			continue
		var tracked_uid := ModelUtils.as_string(raw.get("box_instance_uid"))
		if tracked_uid != instance_id:
			continue
		if ModelUtils.as_bool(raw.get("echo_resolved")):
			continue
		raw["echo_resolved"] = true
		_record_outcome("mystery_box", "echo_found", {"instance_id": instance_id})
		return


## ---------------------------------------------------------------------------
## Instance factories for injected delivery extras
## ---------------------------------------------------------------------------


func _make_request_instance(day: int) -> ObjectInstance:
	var def := get_event_definition("community_request")
	var template_id := ModelUtils.as_string(def.outcome_params.get("request_template_id", ""))
	var inst := _make_instance_from_template(template_id, day)
	if inst == null:
		return null
	inst.assigned_anchor_id = "request"
	# Track which instance belongs to the request.
	for raw in _game_state.save_state.loop.event_active:
		if raw is Dictionary and ModelUtils.as_string(raw.get("event_id")) == "community_request":
			raw["request_instance_uid"] = inst.uid
	return inst


func _make_mystery_box_instance(day: int) -> ObjectInstance:
	var def := get_event_definition("mystery_box")
	var template_id := ModelUtils.as_string(def.outcome_params.get("box_template_id", ""))
	var inst := _make_instance_from_template(template_id, day)
	if inst == null:
		return null
	inst.contents = ModelEnums.OpenResult.TEMPORAL_ECHO
	inst.is_carrier = false
	for raw in _game_state.save_state.loop.event_active:
		if raw is Dictionary and ModelUtils.as_string(raw.get("event_id")) == "mystery_box":
			raw["box_instance_uid"] = inst.uid
	return inst


func _make_suspicious_antique_instance(day: int) -> ObjectInstance:
	var def := get_event_definition("suspicious_antique")
	var template_id := ModelUtils.as_string(def.outcome_params.get("antique_template_id", ""))
	var inst := _make_instance_from_template(template_id, day)
	if inst == null:
		return null
	inst.is_counterfeit_truth = true
	for raw in _game_state.save_state.loop.event_active:
		if raw is Dictionary and ModelUtils.as_string(raw.get("event_id")) == "suspicious_antique":
			raw["antique_instance_uid"] = inst.uid
	return inst


## Resolves an authored event template id to a REAL (folder-scened) artifact. If the requested
## template has no scene (e.g. small_santo / rusted_tin), it swaps to a deterministic scened,
## deliverable template — preferring the same rarity — so an event never injects a placeholder.
func _resolve_scened_template(template_id: String) -> String:
	if _ArtifactScenes.has_scene(template_id):
		return template_id
	var wanted := _repo.get_template(template_id)
	var wanted_rarity := wanted.base_rarity if wanted != null else -1
	var same: Array[String] = []
	var any: Array[String] = []
	for tid in _ArtifactCatalog.spawnable_template_ids():
		var t := _repo.get_template(tid)
		if t == null or not t.deliverable:
			continue
		any.append(tid)
		if wanted_rarity >= 0 and t.base_rarity == wanted_rarity:
			same.append(tid)
	var pool := same if not same.is_empty() else any
	if pool.is_empty():
		return template_id  # nothing scened available; leave it (no worse than before)
	pool.sort()
	return pool[0]


func _make_instance_from_template(template_id: String, day: int) -> ObjectInstance:
	template_id = _resolve_scened_template(template_id)
	var template := _repo.get_template(template_id)
	if template == null:
		return null
	var inst := ObjectInstance.new()
	inst.template_id = template_id
	inst.uid = _make_uid(day)
	inst.condition = 0.0
	inst.state = ModelEnums.ObjState.DIRTY
	inst.is_carrier = false
	inst.fragment_id = ""
	inst.contents = ModelEnums.OpenResult.EMPTY
	inst.authenticity = ModelEnums.Verdict.UNKNOWN
	inst.is_counterfeit_truth = false
	inst.storage_cost = template.storage_cost
	inst.value = int(template.base_value_range.x)
	inst.assigned_anchor_id = _fallback_anchor(template)
	return inst


func _make_uid(day: int) -> String:
	_uid_counter += 1
	return (
		"event_obj_%d_%d_%d_%d" % [_game_state.loop_index, _game_state.run_seed, day, _uid_counter]
	)


func _fallback_anchor(template: ScrapObjectTemplate) -> String:
	for id in _repo.placement_containers.keys():
		var container: PlacementContainer = _repo.placement_containers[id]
		var candidate_tags := template.tags.duplicate()
		candidate_tags.append(template.category)
		if not template.openable_type.is_empty():
			candidate_tags.append(template.openable_type)
		for tag in candidate_tags:
			if container.compatibility_tags.has(tag):
				return id
	return ""


## ---------------------------------------------------------------------------
## Winnability guards
## ---------------------------------------------------------------------------


## Returns tool ids required by any RELEASED fragment's planned carrier this loop.
## Tool Breakdown must not break the last obtainable copy of these tools.
func _required_tools_for_released_fragments() -> Array[String]:
	var required: Array[String] = []
	var placements: Dictionary = _game_state.save_state.loop.current_carrier_placements
	for fragment_id in placements.keys():
		var fragment: Fragment = _game_state.save_state.persistent.fragments.get(fragment_id)
		if fragment == null or fragment.state != ModelEnums.FragmentState.RELEASED:
			continue
		var plan: Dictionary = placements[fragment_id]
		var template_id := ModelUtils.as_string(plan.get("carrier_template_id"))
		var template := _repo.get_template(template_id)
		if template != null and not template.required_clean_tool.is_empty():
			required.append(template.required_clean_tool)
	return required


## ---------------------------------------------------------------------------
## Helpers
## ---------------------------------------------------------------------------


func _get_event_param(event_id: String, key: String, default_value: Variant) -> Variant:
	var def := get_event_definition(event_id)
	if def == null:
		return default_value
	return def.outcome_params.get(key, default_value)


func _record_outcome(event_id: String, outcome_type: String, data: Dictionary) -> void:
	var entry := {
		"event_id": event_id,
		"outcome_type": outcome_type,
		"data": data.duplicate(),
		"day": _game_state.save_state.loop.current_day,
		"hour": _game_state.save_state.loop.current_hour,
	}
	_game_state.save_state.loop.event_outcomes.append(entry)
	EventBus.event_outcome_resolved.emit(event_id, outcome_type, entry["data"])


func _can_use_debug_force() -> bool:
	return OS.is_debug_build() or _debug_force_enabled

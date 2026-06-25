class_name DeliveryGenerator
## Generates morning deliveries of ObjectInstances from authored templates.
##
## Uses weighted rarity selection, respects batch size bounds, produces unique
## per-loop instance IDs, and injects carrier instances planned by the Spawn
## Director on their assigned day. Draws from a deterministic local RNG owned by
## GameState; never uses global random state.

const DELIVERY_STREAM := "delivery_generator"
const UID_PREFIX := "obj_"
## DEBUG: the silver artifacts read the same colour as the dust overlay, so guarantee this template
## (Gold Pendant) in every day-1 delivery while iterating on the condition overlays. Set to "" to
## disable. Replaces the first delivered slot, so batch size + uids stay unchanged.
const DEBUG_FIRST_GOLD := "tarnished_pendant"

var _repo: DataRepository
var _game_state: GameState
var _uid_counter: int = 0
var _last_loop_index: int = -1
var _last_run_seed: int = -1


func _init(repo: DataRepository, game_state: GameState) -> void:
	_repo = repo
	_game_state = game_state


## Generates today's delivery. Returns an array of ObjectInstance. Also stores
## the instance uids in GameState.save_state.loop.current_delivery_ids.
## `override_cfg` and `extra_instances` are optional event-driven modifiers (Phase 18)
## that do not change the generator's core logic.
func generate_day_delivery(
	day: int, override_cfg: DeliveryConfig = null, extra_instances: Array[ObjectInstance] = []
) -> Array[ObjectInstance]:
	var rng := _game_state.make_rng(DELIVERY_STREAM + "_day_%d" % day)
	var instances: Array[ObjectInstance] = []
	var used_uids := {}

	var cfg := override_cfg if override_cfg != null else _repo.get_delivery_config()
	var batch_size := rng.randi_range(cfg.batch_min, cfg.batch_max)
	batch_size = clampi(batch_size, cfg.batch_min, cfg.batch_max)

	var templates_by_rarity := _group_templates_by_rarity()
	var total_weight := _total_rarity_weight(cfg, templates_by_rarity)

	for i in batch_size:
		if total_weight <= 0.0:
			break
		var template := _pick_template(rng, cfg, templates_by_rarity, total_weight)
		if template == null:
			break
		var inst := _create_instance(template, day)
		_assign_random_conditions(inst, rng)
		while used_uids.has(inst.uid):
			inst.uid = _make_uid(day)
		used_uids[inst.uid] = true
		instances.append(inst)

	# DEBUG: force a Gold artifact into the first slot of day-1 deliveries (see DEBUG_FIRST_GOLD).
	# Replaces rather than appends so batch size, uids, and determinism are unaffected.
	if (
		not DEBUG_FIRST_GOLD.is_empty()
		and _game_state.debug_first_gold
		and day == 1
		and not instances.is_empty()
	):
		var gold_template := _repo.get_template(DEBUG_FIRST_GOLD)
		if gold_template != null and instances[0].template_id != DEBUG_FIRST_GOLD:
			var replacement := _create_instance(gold_template, day)
			_assign_random_conditions(replacement, rng)
			replacement.uid = instances[0].uid
			instances[0] = replacement

	_inject_carriers(instances, day, used_uids)

	for extra in extra_instances:
		if extra == null or used_uids.has(extra.uid):
			continue
		used_uids[extra.uid] = true
		instances.append(extra)

	var ids: Array[String] = []
	for inst in instances:
		ids.append(inst.uid)
	_game_state.save_state.loop.current_delivery_ids = ids
	EventBus.delivery_generated.emit(day, ids)
	return instances


func _group_templates_by_rarity() -> Dictionary:
	var groups := {}
	for id in _repo.scrap_object_templates.keys():
		var template: ScrapObjectTemplate = _repo.scrap_object_templates[id]
		if not template.deliverable:
			# Quest/given items (e.g. Auntie's photos) never enter the random pool.
			continue
		var rarity_name := ModelEnums.rarity_name(template.base_rarity)
		if not groups.has(rarity_name):
			groups[rarity_name] = []
		groups[rarity_name].append(template)
	return groups


func _total_rarity_weight(cfg: DeliveryConfig, groups: Dictionary) -> float:
	var total := 0.0
	for rarity_name in cfg.rarity_weights.keys():
		var weight: float = cfg.rarity_weights[rarity_name]
		var templates: Array = groups.get(rarity_name, [])
		if not templates.is_empty() and weight > 0.0:
			total += weight
	return total


func _pick_template(
	rng: RandomNumberGenerator, cfg: DeliveryConfig, groups: Dictionary, total_weight: float
) -> ScrapObjectTemplate:
	var roll := rng.randf() * total_weight
	for rarity_name in cfg.rarity_weights.keys():
		var weight: float = cfg.rarity_weights[rarity_name]
		var templates: Array = groups.get(rarity_name, [])
		if templates.is_empty() or weight <= 0.0:
			continue
		roll -= weight
		if roll <= 0.0:
			return templates[rng.randi_range(0, templates.size() - 1)]
	return null


func _create_instance(template: ScrapObjectTemplate, day: int) -> ObjectInstance:
	var inst := ObjectInstance.new()
	inst.template_id = template.id
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


## Scatters a random set of surface conditions onto an ordinary instance so each
## delivered artifact arrives with different marks to clean. Carriers are left
## untouched (they keep the surface-stroke clean toward their clasp). Deterministic
## via the delivery RNG. Phase 18: active events may append extra conditions.
func _assign_random_conditions(inst: ObjectInstance, rng: RandomNumberGenerator) -> void:
	var catalog := _repo.get_surface_conditions_sorted()
	if catalog.is_empty():
		return
	var count := mini(rng.randi_range(2, 4), catalog.size())
	var available: Array = range(catalog.size())
	var decals: Array = []
	for i in count:
		var pick := rng.randi_range(0, available.size() - 1)
		var condition: SurfaceCondition = catalog[available[pick]]
		available.remove_at(pick)
		(
			decals
			. append(
				{
					"id": "%s_%d" % [condition.id, i],
					"type": condition.id,
					"color": condition.color,
					"required_tool": condition.cleaning_tool,
				}
			)
		)
	if EventDirector != null:
		decals.append_array(EventDirector.get_extra_conditions_for_delivery())
	inst.spawned_decals = decals


func _make_uid(day: int) -> String:
	if _game_state.loop_index != _last_loop_index or _game_state.run_seed != _last_run_seed:
		_uid_counter = 0
		_last_loop_index = _game_state.loop_index
		_last_run_seed = _game_state.run_seed

	var candidate := ""
	while true:
		_uid_counter += 1
		candidate = (
			"%s%d_%d_%d_%d"
			% [UID_PREFIX, _game_state.loop_index, _game_state.run_seed, day, _uid_counter]
		)
		if _uid_is_available(candidate):
			return candidate
	return candidate  # Unreachable; keeps the type checker happy.


## True when the uid is not already used by an instance in the loop inventory or
## by a previously generated delivery in the current loop. This prevents collisions
## when multiple morning deliveries are generated on the same day/loop.
func _uid_is_available(uid: String) -> bool:
	for raw in _game_state.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == uid:
			return false
	for id in _game_state.save_state.loop.current_delivery_ids:
		if id == uid:
			return false
	return true


func _fallback_anchor(template: ScrapObjectTemplate, counts_by_anchor: Dictionary = {}) -> String:
	for id in _repo.placement_containers.keys():
		var container: PlacementContainer = _repo.placement_containers[id]
		var current: int = counts_by_anchor.get(id, 0)
		if current >= container.capacity:
			continue
		var candidate_tags := template.tags.duplicate()
		candidate_tags.append(template.category)
		if not template.openable_type.is_empty():
			candidate_tags.append(template.openable_type)
		for tag in candidate_tags:
			if container.compatibility_tags.has(tag):
				return id
	return (
		_repo.placement_containers.keys().front()
		if not _repo.placement_containers.is_empty()
		else ""
	)


## Injects carrier instances planned by the Spawn Director for the given day.
## Falls back to a compatible anchor if the planned anchor is invalid or full.
## Emits EventBus.carrier_activated after successful promotion.
func _inject_carriers(instances: Array[ObjectInstance], day: int, used_uids: Dictionary) -> void:
	var placements := _game_state.save_state.loop.current_carrier_placements
	var counts_by_anchor := {}
	for inst in instances:
		if not inst.assigned_anchor_id.is_empty():
			counts_by_anchor[inst.assigned_anchor_id] = (
				counts_by_anchor.get(inst.assigned_anchor_id, 0) + 1
			)

	# Carriers get random conditions too, so a promoted carrier is indistinguishable
	# from an ordinary instance of the same template (carrier-identity hiding).
	var cond_rng := _game_state.make_rng(DELIVERY_STREAM + "_carrier_cond_%d" % day)
	var director := SpawnDirector.new(_repo, _game_state)
	for fragment_id in placements.keys():
		var plan: Dictionary = placements[fragment_id]
		if plan.get("day", 0) != day:
			continue
		var template_id: String = plan["carrier_template_id"]
		var template: ScrapObjectTemplate = _repo.scrap_object_templates.get(template_id)
		if template == null:
			continue
		var container_id: String = plan["container_id"]
		container_id = _resolve_anchor(template, container_id, counts_by_anchor)

		var inst := _create_instance(template, day)
		inst.is_carrier = true
		inst.fragment_id = fragment_id
		inst.contents = ModelEnums.OpenResult.FRAGMENT
		inst.assigned_anchor_id = container_id
		_assign_random_conditions(inst, cond_rng)
		plan["carrier_instance_id"] = inst.uid
		while used_uids.has(inst.uid):
			inst.uid = _make_uid(day)
			plan["carrier_instance_id"] = inst.uid
		used_uids[inst.uid] = true
		instances.append(inst)
		counts_by_anchor[container_id] = counts_by_anchor.get(container_id, 0) + 1

		director.record_carrier_instance_id(fragment_id, inst.uid)
		EventBus.carrier_activated.emit(inst.uid, fragment_id)


## Returns a valid, non-full anchor for the template. If the requested anchor is
## invalid or at capacity, picks the first compatible fallback.
func _resolve_anchor(
	template: ScrapObjectTemplate, requested: String, counts_by_anchor: Dictionary
) -> String:
	var container: PlacementContainer = _repo.placement_containers.get(requested)
	if container != null:
		var current: int = counts_by_anchor.get(requested, 0)
		if current < container.capacity and _is_compatible(template, container):
			return requested
	return _fallback_anchor(template, counts_by_anchor)


func _is_compatible(template: ScrapObjectTemplate, container: PlacementContainer) -> bool:
	var candidate_tags := template.tags.duplicate()
	candidate_tags.append(template.category)
	if not template.openable_type.is_empty():
		candidate_tags.append(template.openable_type)
	for tag in candidate_tags:
		if container.compatibility_tags.has(tag):
			return true
	return false

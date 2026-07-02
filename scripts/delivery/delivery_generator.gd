class_name DeliveryGenerator
## Generates morning deliveries of ObjectInstances from authored templates.
##
## Uses weighted rarity selection, respects batch size bounds, produces unique
## per-loop instance IDs, and injects carrier instances planned by the Spawn
## Director on their assigned day. Draws from a deterministic local RNG owned by
## GameState; never uses global random state.

const DELIVERY_STREAM := "delivery_generator"
const UID_PREFIX := "obj_"
## Only templates with a real authored artifact scene (a model in scenes/restoration/artifacts/)
## may spawn in random deliveries — no placeholder shapes. The registry is the source of truth.
const _ArtifactScenes := preload("res://scripts/restoration/artifact_scenes.gd")
const _ArtifactCatalog := preload("res://scripts/restoration/artifact_catalog.gd")

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

	var allowed_conditions := _tutorial_allowed_conditions()
	for i in batch_size:
		if total_weight <= 0.0:
			break
		var template := _pick_template(rng, cfg, templates_by_rarity, total_weight)
		if template == null:
			break
		var inst := _create_instance(template, day)
		inst.allowed_conditions = allowed_conditions.duplicate()
		_assign_random_conditions(inst, rng)
		_apply_initial_value(inst, template, rng)
		while used_uids.has(inst.uid):
			inst.uid = _make_uid(day)
		used_uids[inst.uid] = true
		instances.append(inst)

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
	# Make sure scene-only artifacts are synthesized + registered before we snapshot the template keys.
	_ArtifactCatalog.ensure_ready()
	var required_conditions := _tutorial_allowed_conditions()
	for id in _repo.scrap_object_templates.keys():
		var template: ScrapObjectTemplate = _repo.scrap_object_templates[id]
		if not template.deliverable:
			# Quest/given items (e.g. Auntie's photos) never enter the random pool.
			continue
		if not _ArtifactScenes.has_scene(id):
			# Only artifacts with a real authored model spawn — never placeholder shapes.
			continue
		if _ArtifactCatalog.is_quest_item(id):
			# Quest-bound artifacts are handed out for their NPC step, never randomly delivered.
			continue
		# Day 0 (TUT): the taught piece must actually CARRY every whitelisted
		# condition in its authored scene, otherwise the whitelist would render it
		# spotless at the bench and the cleaning lesson could never complete.
		if not required_conditions.is_empty() and not _scene_has_conditions(id, required_conditions):
			continue
		var rarity_name := ModelEnums.rarity_name(_effective_rarity(template))
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


## Rolls the instance's pristine true value within the template range, then sets its current
## value from the live condition coverage (a freshly-delivered, dirty piece spawns below true).
func _apply_initial_value(
	inst: ObjectInstance, template: ScrapObjectTemplate, rng: RandomNumberGenerator
) -> void:
	var value_range := _effective_value_range(template)
	inst.true_value = ValueModel.roll_true_value_range(value_range.x, value_range.y, rng)
	inst.value = ValueModel.current_value(inst, template, _repo)


## The artifact's rarity: the scene-config override (ArtifactCatalog) when set, else the data template.
func _effective_rarity(template: ScrapObjectTemplate) -> int:
	var override := _ArtifactCatalog.rarity_override(template.id)
	return override if override >= 0 else template.base_rarity


## The artifact's pristine value range: the scene-config override when set (non-zero), else the
## data template's base_value_range.
func _effective_value_range(template: ScrapObjectTemplate) -> Vector2i:
	var override := _ArtifactCatalog.value_range_override(template.id)
	if override.x > 0 or override.y > 0:
		return override
	return Vector2i(int(template.base_value_range.x), int(template.base_value_range.y))


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
	# Instance-level condition filter (Day 0 grime+dust, quest constraints): only
	# the allowed condition types may spawn on this piece (TUT).
	if not inst.allowed_conditions.is_empty():
		var filtered: Array = []
		for raw in catalog:
			var candidate: SurfaceCondition = raw
			if inst.allowed_conditions.has(candidate.id):
				filtered.append(candidate)
		catalog = filtered
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


## The Day 0 condition whitelist from the tutorial config, or [] in normal play.
func _tutorial_allowed_conditions() -> Array[String]:
	if TutorialService.is_tutorial_active():
		return ModelUtils.as_string_array(TutorialService.get_config().get("allowed_conditions"))
	return [] as Array[String]


## True when the artifact's authored scene carries EVERY condition id in `required`.
## Scene slugs may be display-name based (e.g. "grime"); normalize them to journal
## condition ids before comparing.
func _scene_has_conditions(template_id: String, required: Array[String]) -> bool:
	var present := {}
	for raw_type in _ArtifactCatalog.condition_types_for(template_id):
		present[_normalize_condition_id(raw_type)] = true
	for condition_id in required:
		if not present.has(condition_id):
			return false
	return true


## Resolves a raw scene slug ("grime", "Water Stain") to its journal condition id.
func _normalize_condition_id(raw_type: String) -> String:
	var slug := raw_type.to_lower().replace(" ", "_").replace("-", "_")
	for raw in _repo.get_surface_conditions_sorted():
		var condition: SurfaceCondition = raw
		var display_slug := condition.display_name.to_lower().replace(" ", "_").replace("-", "_")
		if slug == condition.id or slug == display_slug:
			return condition.id
	return slug


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
		_apply_initial_value(inst, template, cond_rng)
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

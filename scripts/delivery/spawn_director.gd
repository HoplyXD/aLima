class_name SpawnDirector
## Minimal Phase 3 Spawn Director.
##
## Plans carrier placements for RELEASED fragments at loop start. The full Phase 5
## director will add route-aware candidate pools, tool/lock winnability filters,
## and richer neglect weighting; Phase 3 implements the contract required for
## delivery injection and anchor placement.
##
## A carrier is an ordinary openable instance promoted at runtime (CLAUDE.md §4-C).
## The director never creates a special object; it selects a template and outer
## container and lets the DeliveryGenerator instantiate it.

const PLACEMENT_STREAM := "spawn_director"

var _repo: DataRepository
var _game_state: GameState


func _init(repo: DataRepository, game_state: GameState) -> void:
	_repo = repo
	_game_state = game_state


## Plans placements for every RELEASED fragment and stores them in loop state.
## Returns the placement map (fragment_id -> Dictionary). Emits no signals.
func plan_loop_placements() -> Dictionary:
	var rng := _game_state.make_rng(PLACEMENT_STREAM)
	var plans := {}
	var placements_by_container := {}  # container_id -> count this loop.

	for fragment_id in _repo.fragments.keys():
		var fragment: Fragment = _repo.fragments[fragment_id]
		if fragment.state != ModelEnums.FragmentState.RELEASED:
			continue

		var plan := _plan_fragment(fragment_id, rng, placements_by_container)
		if plan.is_empty():
			continue
		plans[fragment_id] = plan
		var container_id: String = plan["container_id"]
		placements_by_container[container_id] = placements_by_container.get(container_id, 0) + 1

	_game_state.save_state.loop.current_carrier_placements = plans.duplicate(true)
	_record_history(plans)
	return plans


func _plan_fragment(
	fragment_id: String, rng: RandomNumberGenerator, placements_by_container: Dictionary
) -> Dictionary:
	var candidates := _build_candidates(fragment_id, placements_by_container)
	if candidates.is_empty():
		return {}

	_candidates_apply_weights(candidates)
	var total_weight: float = 0.0
	for c in candidates:
		total_weight += c["weight"]
	if total_weight <= 0.0:
		return {}

	var roll := rng.randf() * total_weight
	var selected: Dictionary = candidates[0]
	for c in candidates:
		roll -= c["weight"]
		if roll <= 0.0:
			selected = c
			break

	var day := rng.randi_range(1, DayClock.TOTAL_DAYS)
	return {
		"fragment_id": fragment_id,
		"carrier_template_id": selected["template_id"],
		"carrier_instance_id": "",
		"container_id": selected["container_id"],
		"day": day,
		"soft_reset": selected["soft_reset"],
	}


func _build_candidates(
	fragment_id: String, placements_by_container: Dictionary
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var history: Array = _game_state.save_state.persistent.spawn_history.get(fragment_id, [])
	var used_pairs := {}
	for entry in history:
		if entry is Dictionary and entry.has("carrier_template_id") and entry.has("container_id"):
			var pair_key: String = "%s|%s" % [entry["carrier_template_id"], entry["container_id"]]
			used_pairs[pair_key] = true

	for template_id in _repo.scrap_object_templates.keys():
		var template: ScrapObjectTemplate = _repo.scrap_object_templates[template_id]
		if not template.is_openable:
			continue

		for container_id in _repo.placement_containers.keys():
			var container: PlacementContainer = _repo.placement_containers[container_id]
			if not _is_compatible(template, container):
				continue
			if not _has_capacity(container_id, placements_by_container):
				continue

			var pair_key: String = "%s|%s" % [template_id, container_id]
			var soft_reset := false
			if used_pairs.has(pair_key):
				# Simple Phase 3 soft reset: if every pair is exhausted, allow the
				# most recent pair only.
				if history.size() > 0:
					var last: Dictionary = history[history.size() - 1]
					var last_key: String = (
						"%s|%s" % [last["carrier_template_id"], last["container_id"]]
					)
					if pair_key == last_key:
						soft_reset = true
					else:
						continue
				else:
					continue

			(
				candidates
				. append(
					{
						"template_id": template_id,
						"container_id": container_id,
						"weight": 1.0,
						"soft_reset": soft_reset,
					}
				)
			)

	return candidates


func _is_compatible(template: ScrapObjectTemplate, container: PlacementContainer) -> bool:
	var candidate_tags := template.tags.duplicate()
	candidate_tags.append(template.category)
	if not template.openable_type.is_empty():
		candidate_tags.append(template.openable_type)
	for tag in candidate_tags:
		if container.compatibility_tags.has(tag):
			return true
	return false


func _has_capacity(container_id: String, placements_by_container: Dictionary) -> bool:
	var container: PlacementContainer = _repo.placement_containers.get(container_id)
	if container == null:
		return false
	var current: int = placements_by_container.get(container_id, 0)
	return current < container.capacity


func _candidates_apply_weights(candidates: Array[Dictionary]) -> void:
	var neglect: Dictionary = _game_state.save_state.persistent.neglect_history
	for c in candidates:
		var container_id: String = c["container_id"]
		var bonus: float = neglect.get(container_id, 0) * 0.5
		c["weight"] = 1.0 + bonus


func _record_history(plans: Dictionary) -> void:
	for fragment_id in plans.keys():
		var plan: Dictionary = plans[fragment_id]
		var entry := {
			"loop": _game_state.loop_index,
			"seed": _game_state.run_seed,
			"fragment_id": fragment_id,
			"carrier_template_id": plan["carrier_template_id"],
			"carrier_instance_id": plan["carrier_instance_id"],
			"container_id": plan["container_id"],
			"day": plan["day"],
			"soft_reset": plan.get("soft_reset", false),
		}
		if not _game_state.save_state.persistent.spawn_history.has(fragment_id):
			_game_state.save_state.persistent.spawn_history[fragment_id] = []
		_game_state.save_state.persistent.spawn_history[fragment_id].append(entry)

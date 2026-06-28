class_name SpawnDirector
## Phase 5 Spawn Director.
##
## Implements genuine, deterministic, auditable fragment placement:
## - typed candidate enumeration (PlacementCandidate);
## - hard filters for state, compatibility, capacity, tool obtainability, and locks;
## - weighted scoring with neglect and day-spread;
## - per-player never-twice history with documented soft reset;
## - carrier promotion orchestration via DeliveryGenerator;
## - deterministic audit output.
##
## A carrier is an ordinary openable instance promoted at runtime (CLAUDE.md §4-C).
## The director never creates a special object; it selects a template and outer
## container and lets the DeliveryGenerator instantiate it.

const PLACEMENT_STREAM := "spawn_director"
const DAY_SELECTION_STREAM := "spawn_director_day"
## Carriers must be real artifacts with an authored folder scene (no scene-less placeholders).
const _ArtifactScenes := preload("res://scripts/restoration/artifact_scenes.gd")

var _repo: DataRepository
var _game_state: GameState
var _last_audit_log: Dictionary = {}


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
		if _is_seated(fragment_id):
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


## Plans a placement for a single fragment. Useful for tests and the demo.
## Records history when a plan is produced.
func plan_fragment_placement(fragment_id: String) -> Dictionary:
	var rng := _game_state.make_rng(PLACEMENT_STREAM)
	var placements_by_container := {}
	var plan := _plan_fragment(fragment_id, rng, placements_by_container)
	if not plan.is_empty():
		_record_history({fragment_id: plan})
	return plan


func _plan_fragment(
	fragment_id: String, rng: RandomNumberGenerator, placements_by_container: Dictionary
) -> Dictionary:
	var candidates := _build_candidates(fragment_id, placements_by_container)
	var eligible := _filter_eligible(candidates)

	if eligible.is_empty():
		_last_audit_log = _build_audit_log(fragment_id, candidates, null, "", 0, true)
		return {}

	_apply_weights(eligible)
	var selected: PlacementCandidate = _select_candidate(eligible, rng)
	if selected == null:
		_last_audit_log = _build_audit_log(fragment_id, candidates, null, "", 0, true)
		return {}

	var day := _select_day(fragment_id, rng)

	var plan := {
		"fragment_id": fragment_id,
		"carrier_template_id": selected.template_id,
		"carrier_instance_id": "",
		"container_id": selected.container_id,
		"day": day,
		"soft_reset": selected.soft_reset,
	}

	_last_audit_log = _build_audit_log(fragment_id, candidates, selected, "", day, false)
	return plan


## Enumerates all (template, container) candidates for the fragment and applies
## hard filters. Does not mutate game state. Public so tests can inspect the
## candidate list (P5.1).
func enumerate_candidates(fragment_id: String) -> Array[PlacementCandidate]:
	return _build_candidates(fragment_id, {})


func _build_candidates(
	fragment_id: String, placements_by_container: Dictionary
) -> Array[PlacementCandidate]:
	var candidates: Array[PlacementCandidate] = []

	for template_id in _repo.scrap_object_templates.keys():
		var template: ScrapObjectTemplate = _repo.scrap_object_templates[template_id]
		if not template.is_openable:
			continue

		for container_id in _repo.placement_containers.keys():
			var container: PlacementContainer = _repo.placement_containers[container_id]
			var candidate := PlacementCandidate.new(fragment_id, template_id, container_id)
			candidate.base_weight = _repo.get_spawn_config().base_candidate_weight
			_apply_hard_filters(candidate, template, container, placements_by_container)
			candidates.append(candidate)

	_apply_never_twice(candidates)
	# Deterministic ordering before weighted selection so iteration order cannot
	# change results.
	candidates.sort_custom(_candidate_sort)
	return candidates


func _candidate_sort(a: PlacementCandidate, b: PlacementCandidate) -> bool:
	if a.template_id != b.template_id:
		return a.template_id < b.template_id
	return a.container_id < b.container_id


func _apply_hard_filters(
	candidate: PlacementCandidate,
	template: ScrapObjectTemplate,
	container: PlacementContainer,
	placements_by_container: Dictionary
) -> void:
	if not template.is_openable:
		candidate.rejection_reason = "template_not_openable"
		return

	if not _is_compatible(template, container):
		candidate.rejection_reason = "incompatible_container"
		return

	if not _has_capacity(candidate.container_id, placements_by_container):
		candidate.rejection_reason = "container_at_capacity"
		return

	if container.is_locked_by_default and not _can_unlock_container(container):
		candidate.rejection_reason = _locked_reason(container)
		return

	if not _tool_is_obtainable(template.required_clean_tool):
		candidate.rejection_reason = "required_tool_unavailable"
		return

	# A carrier must be a REAL artifact the player can see and clean — never a scene-less placeholder
	# (e.g. small_santo). Checked last so tool-gating still records its own reason for the audit.
	if not _ArtifactScenes.has_scene(candidate.template_id):
		candidate.rejection_reason = "missing_scene"
		return


## Returns true when the player can open the container during this run.
## Safe eligibility is gated by the known Safe code only (CACHE-R1).
func _can_unlock_container(container: PlacementContainer) -> bool:
	var cfg := _repo.get_spawn_config()
	if container.id == cfg.safe_container_id:
		return _game_state.save_state.persistent.safe_code_known

	if container.unlock_requirement == "safe_code":
		return _game_state.save_state.persistent.safe_code_known

	if _repo.character_routes.has(container.unlock_requirement):
		return _game_state.save_state.persistent.route_completion.get(
			container.unlock_requirement, false
		)

	return _game_state.save_state.persistent.leads.has(container.unlock_requirement)


func _locked_reason(container: PlacementContainer) -> String:
	var cfg := _repo.get_spawn_config()
	if container.id == cfg.safe_container_id:
		return "safe_code_unknown"
	return "location_locked"


func _tool_is_obtainable(tool_id: String) -> bool:
	if tool_id.is_empty():
		return true
	if _repo.starting_kit.get("tool_ids", []).has(tool_id):
		return true
	if _game_state.save_state.persistent.legacy_items.has(tool_id):
		return true
	if _game_state.save_state.loop.tool_items.has(tool_id):
		return true
	return false


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


## Excludes prior (carrier_template_id, container_id) pairs. If every otherwise
## valid pair has been used, performs the documented soft reset: older pairs
## become eligible again, but the most recent pair remains forbidden.
func _apply_never_twice(candidates: Array[PlacementCandidate]) -> void:
	var fragment_id := candidates[0].fragment_id if not candidates.is_empty() else ""
	var history: Array = _game_state.save_state.persistent.spawn_history.get(fragment_id, [])
	var used_pairs := {}
	for entry in history:
		if entry is Dictionary and entry.has("carrier_template_id") and entry.has("container_id"):
			var key: String = "%s|%s" % [entry["carrier_template_id"], entry["container_id"]]
			used_pairs[key] = true

	var valid_pair_keys := {}
	for c in candidates:
		if c.is_eligible():
			valid_pair_keys[c.pair_key()] = true

	var used_valid_pairs := 0
	for key in valid_pair_keys.keys():
		if used_pairs.has(key):
			used_valid_pairs += 1

	var exhausted := used_valid_pairs >= valid_pair_keys.size() and not valid_pair_keys.is_empty()
	var most_recent_key := ""
	if exhausted and not history.is_empty():
		var last: Dictionary = history[history.size() - 1]
		if last.has("carrier_template_id") and last.has("container_id"):
			var key: String = "%s|%s" % [last["carrier_template_id"], last["container_id"]]
			if valid_pair_keys.has(key):
				most_recent_key = key

	for c in candidates:
		if not c.is_eligible():
			continue
		var key: String = c.pair_key()
		if not used_pairs.has(key):
			c.soft_reset = false
			continue
		if exhausted:
			if key == most_recent_key:
				c.rejection_reason = "soft_reset_most_recent_pair"
			else:
				c.soft_reset = true
		else:
			c.rejection_reason = "historical_pair"


func _filter_eligible(candidates: Array[PlacementCandidate]) -> Array[PlacementCandidate]:
	var out: Array[PlacementCandidate] = []
	for c in candidates:
		if c.is_eligible():
			out.append(c)
	return out


func _apply_weights(eligible: Array[PlacementCandidate]) -> void:
	var cfg := _repo.get_spawn_config()
	var neglect: Dictionary = _game_state.save_state.persistent.neglect_history
	for c in eligible:
		var neglect_count: int = neglect.get(c.container_id, 0)
		c.neglect_bonus = neglect_count * cfg.neglect_weight_multiplier
		c.day_spread_bonus = 0.0
		c.final_weight = cfg.base_candidate_weight + c.neglect_bonus + c.day_spread_bonus
		c.final_weight = maxf(c.final_weight, cfg.min_candidate_weight)


func _select_candidate(
	eligible: Array[PlacementCandidate], rng: RandomNumberGenerator
) -> PlacementCandidate:
	var total_weight: float = 0.0
	for c in eligible:
		total_weight += c.final_weight
	if total_weight <= 0.0:
		return null

	var roll := rng.randf() * total_weight
	for c in eligible:
		roll -= c.final_weight
		if roll <= 0.0:
			return c
	return eligible[eligible.size() - 1]


func _select_day(fragment_id: String, rng: RandomNumberGenerator) -> int:
	var cfg := _repo.get_spawn_config()
	var history: Array = _game_state.save_state.persistent.spawn_history.get(fragment_id, [])
	var day_counts := {}
	for entry in history:
		if entry is Dictionary and entry.has("day"):
			var d: int = int(entry["day"])
			day_counts[d] = day_counts.get(d, 0) + 1

	var day_weights := {}
	var total := 0.0
	for day in range(1, DayClock.TOTAL_DAYS + 1):
		var count: int = day_counts.get(day, 0)
		var weight: float = maxf(
			cfg.min_candidate_weight,
			cfg.base_candidate_weight - count * cfg.day_spread_weight_multiplier
		)
		day_weights[day] = weight
		total += weight

	if total <= 0.0:
		return rng.randi_range(1, DayClock.TOTAL_DAYS)

	var roll := rng.randf() * total
	for day in range(1, DayClock.TOTAL_DAYS + 1):
		roll -= day_weights[day]
		if roll <= 0.0:
			return day
	return DayClock.TOTAL_DAYS


func _is_seated(fragment_id: String) -> bool:
	var fragment: Fragment = _game_state.save_state.persistent.fragments.get(fragment_id)
	if fragment == null:
		return false
	return fragment.state == ModelEnums.FragmentState.SEATED


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


## Updates the persistent history entry for this loop with the runtime instance id.
## Called by DeliveryGenerator after carrier promotion.
func record_carrier_instance_id(fragment_id: String, instance_id: String) -> void:
	var history: Array = _game_state.save_state.persistent.spawn_history.get(fragment_id, [])
	if history.is_empty():
		return
	var last: Dictionary = history[history.size() - 1]
	if (
		last.get("loop", -1) == _game_state.loop_index
		and last.get("seed", -1) == _game_state.run_seed
	):
		last["carrier_instance_id"] = instance_id


## Returns the most recent audit log. Populated after plan_loop_placements or
## plan_fragment_placement.
func get_last_audit_log() -> Dictionary:
	return _last_audit_log.duplicate(true)


## Returns the Stable Interfaces placement-log line for a plan.
func get_placement_log_line(plan: Dictionary) -> Dictionary:
	return {
		"loop": _game_state.loop_index,
		"seed": _game_state.run_seed,
		"fragment_id": plan.get("fragment_id", ""),
		"carrier_template_id": plan.get("carrier_template_id", ""),
		"carrier_instance_id": plan.get("carrier_instance_id", ""),
		"container_id": plan.get("container_id", ""),
		"day": plan.get("day", 0),
		"soft_reset": plan.get("soft_reset", false),
	}


func _build_audit_log(
	fragment_id: String,
	candidates: Array[PlacementCandidate],
	selected: PlacementCandidate,
	instance_id: String,
	day: int,
	failed: bool
) -> Dictionary:
	var rejected: Array[Dictionary] = []
	for c in candidates:
		if not c.rejection_reason.is_empty():
			rejected.append(
				{
					"template_id": c.template_id,
					"container_id": c.container_id,
					"reason": c.rejection_reason
				}
			)

	var prior_pairs: Array[String] = []
	var history: Array = _game_state.save_state.persistent.spawn_history.get(fragment_id, [])
	for entry in history:
		if entry is Dictionary and entry.has("carrier_template_id") and entry.has("container_id"):
			prior_pairs.append("%s|%s" % [entry["carrier_template_id"], entry["container_id"]])

	var score := {}
	if selected != null:
		score = {
			"base_weight": selected.base_weight,
			"neglect_bonus": selected.neglect_bonus,
			"day_spread_bonus": selected.day_spread_bonus,
			"final_weight": selected.final_weight,
		}

	return {
		"player_id": _game_state.player_id,
		"loop_index": _game_state.loop_index,
		"run_seed": _game_state.run_seed,
		"fragment_id": fragment_id,
		"candidate_count": candidates.size(),
		"eligible_count": _filter_eligible(candidates).size(),
		"rejected_candidates": rejected,
		"selected_carrier_template": selected.template_id if selected != null else "",
		"selected_carrier_instance": instance_id,
		"selected_container": selected.container_id if selected != null else "",
		"selected_day": day,
		"score_components": score,
		"prior_pair_exclusions": prior_pairs,
		"soft_reset": selected.soft_reset if selected != null else false,
		"failed": failed,
	}


## Runs three sequential placements for the same fragment/player with controlled
## seeds. Retains history between runs so it proves the never-twice rule.
## Returns an array of audit logs, one per run.
func run_three_seed_demo(
	player_id: String, fragment_id: String, seeds: Array[int]
) -> Array[Dictionary]:
	GameState.initialize(player_id)
	_grant_starting_kit()
	var logs: Array[Dictionary] = []
	for seed in seeds:
		GameState.new_run(seed)
		_grant_starting_kit()
		var plan := plan_fragment_placement(fragment_id)
		if not plan.is_empty():
			_game_state.save_state.loop.current_carrier_placements[fragment_id] = plan
		logs.append(get_last_audit_log().duplicate(true))
	return logs


func _grant_starting_kit() -> void:
	for technique_id in _repo.starting_kit.get("technique_ids", []):
		if not _game_state.save_state.persistent.techniques_learned.has(technique_id):
			_game_state.save_state.persistent.techniques_learned.append(technique_id)
	for tool_id in _repo.starting_kit.get("tool_ids", []):
		var tool := _repo.get_tool(tool_id)
		if tool == null:
			continue
		if tool.is_legacy:
			if not _game_state.save_state.persistent.legacy_items.has(tool_id):
				_game_state.save_state.persistent.legacy_items.append(tool_id)
		if not _game_state.save_state.loop.tool_items.has(tool_id):
			_game_state.save_state.loop.tool_items.append(tool_id)

class_name ValueModel
## Computes an artifact instance's current market value from its rolled pristine
## ("true") value and the live coverage of its surface conditions.
##
## Each surface condition cuts up to its `value_reduction` percent of the true value
## at full coverage; cleaning the condition off scales that penalty toward zero, so a
## partially-cleaned piece is still sellable — just worth less. The result is floored
## at the template's minimum base value and never exceeds the rolled true value.
##
## Coverage source (artifact-agnostic, from persisted instance data):
##   * decal-based pieces — the fraction of each condition's spawned decals not yet
##     removed (removed_decals).
##   * authored-overlay pieces (no decal removals) — the overall remaining-dirt
##     fraction (1 - condition/100), applied to every condition the instance carries.
## When per-condition coverage is later persisted (see the data-reset fix), this seam
## can read it directly without changing callers.


## The current market value for `inst`. Falls back gracefully for pre-revamp instances.
static func current_value(
	inst: ObjectInstance, template: ScrapObjectTemplate, repo: DataRepository
) -> int:
	if inst == null:
		return 0
	var base := inst.true_value
	if base <= 0:
		base = inst.value if inst.value > 0 else _template_mid(template)
	if template == null or repo == null or base <= 0:
		return maxi(base, 0)
	var floor_value := int(template.base_value_range.x)
	var reduction := _reduction_percent(inst, repo)
	var current := int(round(float(base) * (1.0 - reduction / 100.0)))
	return clampi(current, mini(floor_value, base), base)


## Total percent (0..100) of the true value removed by the instance's still-present conditions.
static func _reduction_percent(inst: ObjectInstance, repo: DataRepository) -> float:
	var counts := _condition_counts(inst)
	if counts.is_empty():
		return 0.0
	# Decal pieces track per-condition removal; authored pieces use overall cleanliness.
	var use_decals := not inst.removed_decals.is_empty()
	var dirty_fraction := clampf(1.0 - inst.condition / 100.0, 0.0, 1.0)
	var total := 0.0
	for type_id in counts.keys():
		var condition := repo.get_surface_condition(type_id)
		if condition == null:
			continue
		var remaining: float
		if use_decals:
			var c: Dictionary = counts[type_id]
			remaining = float(c["remaining"]) / float(c["total"]) if int(c["total"]) > 0 else 0.0
		else:
			remaining = dirty_fraction
		total += condition.value_reduction * clampf(remaining, 0.0, 1.0)
	return total


## condition type_id -> {total, remaining} from the instance's spawned decals.
static func _condition_counts(inst: ObjectInstance) -> Dictionary:
	var out := {}
	for raw in inst.spawned_decals:
		if not (raw is Dictionary):
			continue
		var type_id := str(raw.get("type", ""))
		if type_id.is_empty():
			continue
		var entry: Dictionary = out.get(type_id, {"total": 0, "remaining": 0})
		entry["total"] = int(entry["total"]) + 1
		if not inst.removed_decals.has(str(raw.get("id", ""))):
			entry["remaining"] = int(entry["remaining"]) + 1
		out[type_id] = entry
	return out


## Rolls a pristine value uniformly within the template's [min, max] base value range.
static func roll_true_value(template: ScrapObjectTemplate, rng: RandomNumberGenerator) -> int:
	if template == null:
		return 0
	return roll_true_value_range(
		int(template.base_value_range.x), int(template.base_value_range.y), rng
	)


## Rolls a pristine value uniformly within an explicit [lo, hi] range (used when an artifact scene
## overrides its value range via ArtifactCatalog).
static func roll_true_value_range(lo: int, hi: int, rng: RandomNumberGenerator) -> int:
	var low := mini(lo, hi)
	var high := maxi(lo, hi)
	if high <= low:
		return low
	if rng == null:
		return (low + high) / 2
	return rng.randi_range(low, high)


static func _template_mid(template: ScrapObjectTemplate) -> int:
	if template == null:
		return 0
	return int(round((template.base_value_range.x + template.base_value_range.y) / 2.0))

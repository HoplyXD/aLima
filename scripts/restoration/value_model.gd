class_name ValueModel
## Computes an artifact instance's current market value from its rolled pristine
## ("true") value and the live coverage of its surface conditions.
##
## The TRUE value is rolled per instance, uniformly within the template's [min, max] range. Each
## surface condition cuts up to its `value_reduction` percent of that true value at full coverage;
## cleaning the condition off scales the penalty toward zero, so a partially-cleaned piece is still
## sellable — just worth less. The result is FLOORED AT 1/4 OF THE TRUE VALUE (so a filthy piece is
## still worth something, but cleaning always pays off) and never exceeds the true value.

## Fraction of the true value below which conditions can never push the price
## (the dirty-piece floor).
const MIN_VALUE_FRACTION := 0.25


## The floor value (1/4 of the true value), never below 1 for a positive-valued piece.
static func _floor_for(true_value: int) -> int:
	return maxi(1, int(round(float(true_value) * MIN_VALUE_FRACTION)))


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
	var reduction := _reduction_percent(inst, template, repo)
	var current := int(round(float(base) * (1.0 - reduction / 100.0)))
	return clampi(current, mini(_floor_for(base), base), base)


## Current value from an explicit {condition_id: {coverage 0..1, value_reduction percent}}
## map — used by the restoration view to price authored-overlay artifacts off their LIVE overlay
## coverage and each overlay's OWN value_reduction. The value climbs smoothly as the player
## cleans, floored at 1/4 of the true value and capped at it.
static func value_from_coverage(true_value: int, coverage: Dictionary) -> int:
	if true_value <= 0:
		return maxi(true_value, 0)
	if coverage.is_empty():
		return true_value
	var reduction := 0.0
	for condition_id in coverage.keys():
		var entry: Dictionary = coverage[condition_id]
		reduction += (
			float(entry.get("value_reduction", 0.0))
			* clampf(float(entry.get("coverage", 0.0)), 0.0, 1.0)
		)
	var current := int(round(float(true_value) * (1.0 - reduction / 100.0)))
	return clampi(current, mini(_floor_for(true_value), true_value), true_value)


## Total percent (0..100) of the true value removed by the instance's still-present conditions.
static func _reduction_percent(
	inst: ObjectInstance, template: ScrapObjectTemplate, repo: DataRepository
) -> float:
	var counts := _condition_counts(inst)
	if counts.is_empty():
		# Non-decal, non-overlay pieces (ordinary openables) have no per-condition data; derive the
		# reduction directly from how close condition is to the clean-completion threshold.
		var threshold := template.clean_completion_threshold if template != null else 100
		if threshold <= 0:
			threshold = 100
		return clampf(1.0 - inst.condition / float(threshold), 0.0, 1.0) * 100.0
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

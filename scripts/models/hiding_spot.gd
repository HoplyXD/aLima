class_name HidingSpot
## A hunt hiding spot: where a RELEASED fragment can be hidden for the player
## to track down by Cultural Echoes (data/delivery/hiding_spots.json).
##
## Spots are authored data so the team can add or tune locations without code:
## - `location` keys the walkable space ("yard", "dump_site", "forbidden_zone",
##   "shop").
## - `x`/`z` position the find in world space (the scene ground-snaps y); shop
##   spots use `anchor` (a Marker3D name on the shop root) instead.
## - `requires` gates availability ("location_unlocked:<id>" or "flag:<field>").
## - `days` optionally restricts to the in-loop days the location is reachable
##   (e.g. the Dump Site opens on days 3-4); empty means any day.

var id: String = ""
var location: String = ""
var x: float = 0.0
var z: float = 0.0
var anchor: String = ""
var requires: Array[String] = []
var days: Array[int] = []


static func from_dictionary(data: Dictionary) -> HidingSpot:
	var spot := HidingSpot.new()
	spot.id = ModelUtils.as_string(data.get("id"))
	spot.location = ModelUtils.as_string(data.get("location"))
	spot.x = ModelUtils.as_float(data.get("x"), 0.0)
	spot.z = ModelUtils.as_float(data.get("z"), 0.0)
	spot.anchor = ModelUtils.as_string(data.get("anchor"))
	spot.requires = ModelUtils.as_string_array(data.get("requires"))
	spot.days = []
	var raw_days: Variant = data.get("days", [])
	if raw_days is Array:
		for value in raw_days:
			spot.days.append(ModelUtils.as_int(value))
	return spot


func to_dictionary() -> Dictionary:
	return {
		"record_type": "hiding_spot",
		"id": id,
		"location": location,
		"x": x,
		"z": z,
		"anchor": anchor,
		"requires": requires.duplicate(),
		"days": days.duplicate(),
	}


## True when every availability requirement passes for the given save state.
func is_available(persistent: SaveState.PersistentState) -> bool:
	for requirement in requires:
		if not _requirement_met(requirement, persistent):
			return false
	return true


## True when the spot is reachable on the given day. Day 0 means "any day this
## loop" (loop-start planning: a windowed location opens later in the loop).
func is_open_on_day(day: int) -> bool:
	if days.is_empty() or day <= 0:
		return true
	return days.has(day)


static func _requirement_met(requirement: String, persistent: SaveState.PersistentState) -> bool:
	var parts := requirement.split(":", true, 1)
	if parts.size() != 2:
		return false
	var kind := parts[0]
	var value := parts[1]
	match kind:
		"location_unlocked":
			return persistent.unlocked_locations.has(value)
		"flag":
			var flag: Variant = persistent.get(value)
			return flag != null and bool(flag)
		_:
			return false


func validate(
	result: ValidationResult = ValidationResult.new(), file_path: String = ""
) -> ValidationResult:
	if id.is_empty():
		result.add_field_error(file_path, id, "id", "hiding spot id is required")
	if location.is_empty():
		result.add_field_error(file_path, id, "location", "hiding spot location is required")
	for day in days:
		if day < 1 or day > 5:
			result.add_field_error(file_path, id, "days", "days entries must be 1..5")
	for requirement in requires:
		if not requirement.contains(":"):
			result.add_field_error(
				file_path, id, "requires", "requirement '%s' must be '<kind>:<value>'" % requirement
			)
	return result

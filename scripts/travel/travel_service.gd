class_name TravelService
## Data-driven tricycle destination logic (travel system / meet-to-sell).
##
## Destinations live in data/travel/destinations.json — adding a map later
## (Dump Site, Sam's place) is a data change plus its scene. This is a plain
## instantiable class (not an autoload): it holds no scene refs and reads the
## live state (pending meets, tutorial step) on demand, so GUT can drive it
## directly.

const DESTINATIONS_PATH := "res://data/travel/destinations.json"

var _destinations: Array = []


func _init(path: String = DESTINATIONS_PATH) -> void:
	_load(path)


func destinations() -> Array:
	return _destinations


## Destinations reachable from `current_space` (everything except where you are).
func available_from(current_space: SpaceManager.Space) -> Array:
	var current_name: String = SpaceManager.Space.keys()[current_space]
	var out: Array = []
	for raw in _destinations:
		if str(raw.get("space")) != current_name:
			out.append(raw)
	return out


## True when the destination deserves a "someone is waiting" mark: a pending
## meet-in-person buyer is there, or the current tutorial step targets it.
func is_recommended(destination_id: String) -> bool:
	if not MarketplaceService.pending_meets_for(destination_id).is_empty():
		return true
	if TutorialService.is_tutorial_active():
		var destination := _find(destination_id)
		var step := TutorialService.current_step()
		var wanted := ModelUtils.as_dictionary(step.get("complete_on"))
		if (
			ModelUtils.as_string(wanted.get("signal")) == "space_changed"
			and ModelUtils.as_string(wanted.get("space")) == str(destination.get("space", ""))
		):
			return true
	return false


## The SpaceManager.Space for a destination id, or -1 when unknown.
func space_for(destination_id: String) -> int:
	var destination := _find(destination_id)
	if destination.is_empty():
		return -1
	var index: int = SpaceManager.Space.keys().find(str(destination.get("space")))
	return index


func _find(destination_id: String) -> Dictionary:
	for raw in _destinations:
		if raw is Dictionary and str(raw.get("id")) == destination_id:
			return raw
	return {}


func _load(path: String) -> void:
	_destinations = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("TravelService: cannot open %s" % path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		push_error("TravelService: malformed %s" % path)
		return
	var raw: Variant = (json.data as Dictionary).get("destinations")
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				_destinations.append(entry)

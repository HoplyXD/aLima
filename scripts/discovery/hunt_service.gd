extends Node
## Orchestrates the hidden-fragment hunt (autoload).
##
## Team decision 2026-07-07: completing a character's story RELEASES their
## fragment, which then hides at a Spawn-Director-planned hiding spot across the
## walkable spaces (yard, dump site, forbidden zone, shop). The player tracks it
## by Cultural Echoes and picks the fragment up at the spot; the pickup fires
## `EventBus.fragment_discovered` and the existing Found -> Portal -> seat chain
## takes over. (Exception: NPC-scripted grants like Sam's dirty bag keep the
## clean->open carrier flow.)
##
## This service is a thin autoload: planning lives in SpawnDirector
## (never-twice history, availability hard filter, seeded audit log); scenes ask
## `spots_for_location()` and report pickups via `mark_found()`.

signal hunt_planned(fragment_id: String, spot_id: String, location: String)
signal hunt_found(fragment_id: String)


func _ready() -> void:
	EventBus.fragment_released.connect(_on_fragment_released)


## Plans a spot for every RELEASED, unseated fragment that lacks one this loop.
## Safe to call repeatedly (existing plans are kept). Scenes call this on ready
## so a loaded save always has its hunts in place.
func ensure_planned() -> void:
	if GameState.save_state == null:
		return
	var repo := DataRepository.singleton()
	if not repo.is_loaded():
		return
	var before: Dictionary = GameState.save_state.loop.fragment_spots.duplicate()
	var director := SpawnDirector.new(repo, GameState)
	var plans := director.plan_hunt_spots(DayClock.get_day())
	for fragment_id in plans.keys():
		if not before.has(fragment_id):
			var plan: Dictionary = plans[fragment_id]
			hunt_planned.emit(fragment_id, plan.get("spot_id", ""), plan.get("location", ""))


## The planned hunts for one walkable location. Each entry:
## {fragment_id, spot (HidingSpot)}.
func spots_for_location(location: String) -> Array[Dictionary]:
	ensure_planned()
	var out: Array[Dictionary] = []
	if GameState.save_state == null:
		return out
	var repo := DataRepository.singleton()
	var plans: Dictionary = GameState.save_state.loop.fragment_spots
	var fragment_ids := plans.keys()
	fragment_ids.sort()
	for fragment_id in fragment_ids:
		var plan: Dictionary = plans[fragment_id]
		if plan.get("location", "") != location:
			continue
		var spot := repo.get_hiding_spot(String(plan.get("spot_id", "")))
		if spot == null:
			continue
		out.append({"fragment_id": fragment_id, "spot": spot})
	return out


## True when at least one hunt is planned for the location (echoes may run).
func is_hunt_active_in(location: String) -> bool:
	return not spots_for_location(location).is_empty()


## The player picked the fragment up at its spot. Clears the plan (the hunt is
## over; seating is the Found flow's job) and persists so a crash between pickup
## and seating re-plans rather than duplicating.
func mark_found(fragment_id: String) -> void:
	if GameState.save_state == null:
		return
	if not GameState.save_state.loop.fragment_spots.has(fragment_id):
		return
	GameState.save_state.loop.fragment_spots.erase(fragment_id)
	hunt_found.emit(fragment_id)
	var save_result := SaveService.save_game()
	if not save_result.ok:
		push_error("HuntService: save after find failed: %s" % save_result.get("error", ""))


## A story beat released a fragment mid-loop: hide it somewhere reachable today.
func _on_fragment_released(fragment_id: String) -> void:
	if GameState.save_state == null:
		return
	var repo := DataRepository.singleton()
	if not repo.is_loaded():
		return
	if GameState.save_state.loop.fragment_spots.has(fragment_id):
		return
	var occupied := {}
	for other_id in GameState.save_state.loop.fragment_spots.keys():
		var existing: Dictionary = GameState.save_state.loop.fragment_spots[other_id]
		occupied[existing.get("spot_id", "")] = true
	var director := SpawnDirector.new(repo, GameState)
	var plan := director.plan_hunt_spot(fragment_id, DayClock.get_day(), occupied)
	if plan.is_empty():
		push_warning("HuntService: no eligible hiding spot for %s" % fragment_id)
		return
	GameState.save_state.loop.fragment_spots[fragment_id] = plan
	hunt_planned.emit(fragment_id, plan.get("spot_id", ""), plan.get("location", ""))

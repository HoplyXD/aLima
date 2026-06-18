extends Node
## Per-route story progress and visit resolution. Registered as the `RouteService`
## autoload.
##
## Two pieces of route progress are tracked, both stored in PersistentState so they
## survive the five-day loop reset (CLAUDE.md §4-A — story progress is the
## protagonist's metaknowledge):
##   - "met": the player has finished a route's first conversation at least once.
##     Drives the intro -> return dialogue branch.
##   - "completed": the route's fragment has been seated (the route was fully
##     helped). Drives mutual-exclusion gating (e.g. the artisan only answers the
##     shared afternoon slot once the auntie route is complete) and reward grants.
##
## Completion is wired to EventBus.fragment_seated: seating a route's fragment
## completes that route, grants its rewards, and emits EventBus.route_completed.
## RouteService never touches scene nodes.

const _MET_PREFIX := "route_met:"


func _ready() -> void:
	EventBus.fragment_seated.connect(_on_fragment_seated)


# --- Met / completed state ----------------------------------------------------


## True once the player has finished this route's first conversation.
func is_met(route_id: String) -> bool:
	return GameState.save_state.persistent.dialogue_flags.has(_MET_PREFIX + route_id)


## Records that the player has met this route's character. Idempotent.
func mark_met(route_id: String) -> void:
	if route_id.is_empty():
		return
	var flags: Array[String] = GameState.save_state.persistent.dialogue_flags
	var flag := _MET_PREFIX + route_id
	if not flags.has(flag):
		flags.append(flag)


## True once the route's fragment has been seated (the route was fully helped).
func is_completed(route_id: String) -> bool:
	return bool(GameState.save_state.persistent.route_completion.get(route_id, false))


## Marks a route complete, grants its authored rewards, and announces it. A
## completed route is also implicitly met. Idempotent.
func mark_completed(route_id: String) -> void:
	if route_id.is_empty() or is_completed(route_id):
		return
	GameState.save_state.persistent.route_completion[route_id] = true
	mark_met(route_id)
	var route := _repo().get_route(route_id)
	if route != null:
		_grant_rewards(route.rewards)
	EventBus.route_completed.emit(route_id)


func has_lead(lead_id: String) -> bool:
	return GameState.save_state.persistent.leads.has(lead_id)


# --- Visit resolution ---------------------------------------------------------


## Returns the route whose visit window covers the given day/hour and whose visit
## gating is satisfied, or null. Ranked by a stable priority so a deterministic
## visitor answers when (rarely) more than one window overlaps.
func resolve_visitor(day: int, hour: int) -> CharacterRoute:
	var repo := _repo()
	for route_id in ["archeologist", "auntie", "scavenger", "artisan", "buyer"]:
		var route := repo.get_route(route_id)
		if route == null:
			continue
		if _window_covers(route, day, hour) and can_visit(route_id):
			return route
	return null


## Whether a route may currently answer the door. Only route-id prerequisites and
## mutual exclusions gate a *visit* (lead/flag prerequisites gate completion, not
## the appearance). Of two mutually exclusive routes that both fit the slot, the
## one with more satisfied route-id prerequisites takes it — so the gated artisan
## (prereq: auntie) displaces the scavenger once auntie is complete, and yields to
## the scavenger while she is not.
func can_visit(route_id: String) -> bool:
	var repo := _repo()
	var route := repo.get_route(route_id)
	if route == null:
		return false
	if not _visit_prereqs_satisfied(route):
		return false
	for excl_id in route.mutual_exclusions:
		var excl := repo.get_route(excl_id)
		if excl == null:
			continue
		if (
			_visit_prereqs_satisfied(excl)
			and _route_prereq_count(excl) > _route_prereq_count(route)
		):
			return false
	return true


# --- Dialogue selection -------------------------------------------------------


## Picks the dialogue key for a visit: the return variant once the character has
## been met, otherwise the intro. A day-specific key (e.g. "day3_return") wins when
## authored, then the plain state key, then a generic "default".
func dialogue_key(route: CharacterRoute, day: int) -> String:
	var state := "return" if is_met(route.id) else "intro"
	var day_key := "day%d_%s" % [day, state]
	if route.dialogue.has(day_key):
		return day_key
	if route.dialogue.has(state):
		return state
	return "default"


# --- Internals ----------------------------------------------------------------


func _on_fragment_seated(fragment_id: String, _slot_index: int) -> void:
	var fragment := _repo().get_fragment(fragment_id)
	if fragment == null:
		return
	if _repo().character_routes.has(fragment.owning_character_id):
		mark_completed(fragment.owning_character_id)


func _grant_rewards(rewards: Array) -> void:
	var persistent := GameState.save_state.persistent
	for reward in rewards:
		var id := str(reward)
		if id == "safe_code":
			persistent.safe_code_known = true
		elif id.ends_with("_lead"):
			if not persistent.leads.has(id):
				persistent.leads.append(id)
		elif id.ends_with("_tool") or id.ends_with("_tools"):
			if not persistent.legacy_items.has(id):
				persistent.legacy_items.append(id)
		else:
			if not persistent.story_clues.has(id):
				persistent.story_clues.append(id)


## Only route-id prerequisites gate a visit. Lead/flag prerequisites (e.g.
## "archeologist_lead", "all_fragments_seated") govern completion, not appearance.
func _visit_prereqs_satisfied(route: CharacterRoute) -> bool:
	var repo := _repo()
	for prereq in route.prerequisites:
		if repo.character_routes.has(prereq) and not is_completed(prereq):
			return false
	return true


func _route_prereq_count(route: CharacterRoute) -> int:
	var repo := _repo()
	var count := 0
	for prereq in route.prerequisites:
		if repo.character_routes.has(prereq):
			count += 1
	return count


func _window_covers(route: CharacterRoute, day: int, hour: int) -> bool:
	for window in route.schedule:
		if not window is Dictionary:
			continue
		var days: Variant = window.get("days")
		if not days is Array:
			continue
		var day_matches := false
		for d in days:
			if ModelUtils.as_int(d) == day:
				day_matches = true
				break
		if not day_matches:
			continue
		var start_hour := ModelUtils.as_int(window.get("start_hour"))
		var end_hour := ModelUtils.as_int(window.get("end_hour"))
		if hour >= start_hour and hour < end_hour:
			return true
	return false


func _repo() -> DataRepository:
	return DataRepository.singleton()

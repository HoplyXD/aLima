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

## Visit ordering scanned by resolve_visitor when (rarely) windows overlap.
const _VISIT_PRIORITY: Array[String] = ["archeologist", "auntie", "scavenger", "artisan", "buyer"]

## Loop-scoped record of which scheduled visits the player answered or let expire,
## keyed "day:route_id". Cleared on loop reset. Not persisted: a visit that closes
## unanswered is consumed for the current loop only (CLAUDE.md §4-J).
var _visit_log: Dictionary = {}

## Debug/demo override: when set to a route id, resolve_visitor returns that route
## ignoring the window, gating, and consumption. Only reachable via debug_force_visit
## (the slice/demo menu and tests) — never through normal progression.
var _debug_forced_route: String = ""


func _ready() -> void:
	EventBus.fragment_seated.connect(_on_fragment_seated)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.loop_reset.connect(_on_loop_reset)


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


# --- Authored route beats -----------------------------------------------------


## True once an authored beat (e.g. "auntie_beat_1") has been completed. Beat
## progress is persistent metaknowledge and survives the loop reset.
func is_beat_complete(beat_id: String) -> bool:
	return GameState.save_state.persistent.route_beats_completed.has(beat_id)


## The number of this route's authored beats the player has completed.
func beats_completed_count(route_id: String) -> int:
	var route := _repo().get_route(route_id)
	if route == null:
		return 0
	var count := 0
	for beat in route.beats:
		if beat is Dictionary and is_beat_complete(str(beat.get("id"))):
			count += 1
	return count


## The beat authored for this route on a given day, ready to be played now: it is
## not yet complete and every earlier beat is complete. Returns {} when there is no
## such beat (none authored for the day, already done, or blocked by a missed
## earlier beat). The shop calls this after a route's door dialogue to decide
## whether to open the scripted showcase.
func due_beat(route_id: String, day: int) -> Dictionary:
	var route := _repo().get_route(route_id)
	if route == null:
		return {}
	for i in route.beats.size():
		var beat: Variant = route.beats[i]
		if not beat is Dictionary:
			continue
		if ModelUtils.as_int(beat.get("day"), -1) != day:
			continue
		var beat_id := str(beat.get("id"))
		if is_beat_complete(beat_id):
			return {}
		if not _prior_beats_complete(route, i):
			return {}
		return beat
	return {}


## Records an authored beat as complete and announces it. Enforces ordinal gating —
## every earlier beat in the route must already be complete (so beat 2 requires beat
## 1, beat 3 requires beat 2). Completing the route's final authored beat RELEASES
## the route's fragment through FragmentService (never a handoff; the Spawn Director
## then places it). Idempotent; returns true only on a new, valid completion.
func complete_beat(route_id: String, beat_id: String) -> bool:
	var route := _repo().get_route(route_id)
	if route == null:
		return false
	var index := _beat_index(route, beat_id)
	if index < 0:
		push_warning("RouteService: '%s' has no beat '%s'" % [route_id, beat_id])
		return false
	if is_beat_complete(beat_id):
		return false
	if not _prior_beats_complete(route, index):
		push_warning("RouteService: beat '%s' is gated by an earlier incomplete beat" % beat_id)
		return false

	GameState.save_state.persistent.route_beats_completed.append(beat_id)
	EventBus.route_beat_completed.emit(route_id, beat_id)

	# The final authored beat releases the route's fragment into the scrap stream.
	if index == route.beats.size() - 1 and not route.holds_fragment_id.is_empty():
		FragmentService.release_fragment(route.holds_fragment_id, "route '%s' completed" % route_id)
	return true


func _beat_index(route: CharacterRoute, beat_id: String) -> int:
	for i in route.beats.size():
		var beat: Variant = route.beats[i]
		if beat is Dictionary and str(beat.get("id")) == beat_id:
			return i
	return -1


func _prior_beats_complete(route: CharacterRoute, index: int) -> bool:
	for i in index:
		var beat: Variant = route.beats[i]
		if beat is Dictionary and not is_beat_complete(str(beat.get("id"))):
			return false
	return true


# --- Visit scheduling / consumption -------------------------------------------


## Marks a scheduled visit as answered for the current loop so it is not later
## consumed as missed. Called by the shop when a route's door dialogue finishes.
func notify_visit_answered(route_id: String, day: int) -> void:
	if route_id.is_empty():
		return
	_visit_log[_visit_key(day, route_id)] = "answered"


## True once a scheduled visit for this day/route has been recorded (answered or
## allowed to expire) in the current loop. Used to avoid double-handling.
func is_visit_consumed(route_id: String, day: int) -> bool:
	return _visit_log.has(_visit_key(day, route_id))


## True once a scheduled visit closed unanswered in the current loop. Such a visit
## no longer answers the door (the visitor moved on).
func is_visit_missed(route_id: String, day: int) -> bool:
	return _visit_log.get(_visit_key(day, route_id), "") == "missed"


## Forces resolve_visitor to return this route regardless of window, gating, or
## consumption. Debug/demo only — there is no normal-progression path here.
func debug_force_visit(route_id: String) -> void:
	_debug_forced_route = route_id


func debug_clear_forced_visit() -> void:
	_debug_forced_route = ""


# --- Visit resolution ---------------------------------------------------------


## Returns the route whose visit window covers the given day/hour and whose visit
## gating is satisfied, or null. Ranked by a stable priority so a deterministic
## visitor answers when (rarely) more than one window overlaps. A window only closes
## at end_hour, and _window_covers already excludes hour >= end_hour, so an expired
## (consumed) visit can never resolve here — the is_visit_missed record drives the
## visit_missed signal and feedback, not resolution.
func resolve_visitor(day: int, hour: int) -> CharacterRoute:
	var repo := _repo()
	if not _debug_forced_route.is_empty():
		return repo.get_route(_debug_forced_route)
	for route_id in _VISIT_PRIORITY:
		var route := repo.get_route(route_id)
		if route == null:
			continue
		if not _window_covers(route, day, hour):
			continue
		if not can_visit(route_id):
			continue
		if not _beat_gate_allows_visit(route, day):
			continue
		return route
	return null


## Day-5 / beat gate (team decision, 2026-06-18): a route that authored a beat for
## this day only appears once every earlier beat is complete. The beat for the day
## may still be unstarted (it becomes the showcase), but a missed earlier beat hides
## the character. Routes without an authored beat for the day (e.g. the Mysterious
## Buyer, who has none) are never gated here.
func _beat_gate_allows_visit(route: CharacterRoute, day: int) -> bool:
	var index := -1
	for i in route.beats.size():
		var beat: Variant = route.beats[i]
		if beat is Dictionary and ModelUtils.as_int(beat.get("day"), -1) == day:
			index = i
			break
	if index < 0:
		return true
	if is_beat_complete(str(route.beats[index].get("id"))):
		return true
	return _prior_beats_complete(route, index)


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


## When the clock crosses a visit window's close hour, any genuinely-offered visit
## the player did not answer is consumed (it moves on) and announced once via
## EventBus.visit_missed. This is what makes a missed Day-1/Day-3 beat block the
## later beats (CLAUDE.md §4-J).
func _on_hour_changed(day: int, hour: int) -> void:
	if not _debug_forced_route.is_empty():
		return
	var repo := _repo()
	for route_id in _VISIT_PRIORITY:
		var route := repo.get_route(route_id)
		if route == null:
			continue
		if not _window_closes_at(route, day, hour):
			continue
		if is_visit_consumed(route_id, day):
			continue
		# Only count a visit the player could actually have answered as "missed".
		if not can_visit(route_id) or not _beat_gate_allows_visit(route, day):
			continue
		_visit_log[_visit_key(day, route_id)] = "missed"
		EventBus.visit_missed.emit(route_id, day)


func _on_loop_reset(_loop_index: int) -> void:
	# Visit answer/expiry is loop-scoped; a new loop re-offers every visit.
	_visit_log.clear()


func _visit_key(day: int, route_id: String) -> String:
	return "%d:%s" % [day, route_id]


## True when `hour` is exactly the close hour (end_hour) of a window that covers the
## given day — i.e. the window has just closed on this tick.
func _window_closes_at(route: CharacterRoute, day: int, hour: int) -> bool:
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
		if day_matches and ModelUtils.as_int(window.get("end_hour")) == hour:
			return true
	return false


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

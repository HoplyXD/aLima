extends Node
## Day/loop progression and the five-day loop reset transaction (CLOCK-R2/R3,
## SAVE-R1..R6). Registered as the `LoopController` autoload.
##
## LoopController is the integration layer between the presentation-free DayClock
## and the rest of the core services. It:
##   - forwards DayClock's signals onto EventBus (the shared cross-system hub) and
##     mirrors the live day/hour into GameState's loop-scoped save state;
##   - advances Day 1 -> Day 5 cleanly at each 20:00 close;
##   - performs the deterministic Day 5 reset (clear loop, increment loop, restart
##     at Day 1 07:00, atomic save, then announce loop_reset).
## It is the only emitter of EventBus.loop_reset. It holds no scene references.

var _resetting: bool = false  ## Guards the Day 5 reset against duplicate day_closed signals.


func _ready() -> void:
	DayClock.hour_changed.connect(_on_hour_changed)
	DayClock.day_changed.connect(_on_day_changed)
	DayClock.day_closed.connect(_on_day_closed)
	DayClock.pause_changed.connect(_on_pause_changed)


## Initializes and starts the live clock for a play session. Called by the Shop
## controller on ready; safe to call from tests to drive a real session.
##
## Guarded by DayClock.running so the clock keeps ticking when the player returns
## from the scrapyard: the first shop entry resets and starts the session, while
## subsequent entries reuse the running clock.
##
## Resumes from GameState.save_state.loop.current_day/current_hour so Continue
## restores the saved moment; New Game starts at Day 1 07:00 because initialize()
## resets those fields.
func begin_session() -> void:
	if DayClock.running:
		return
	DayClock.reset()
	DayClock.loop_index = GameState.loop_index
	DayClock.running = true
	_grant_starting_kit()
	# Reflect any persisted RELEASED/SEATED fragment state onto the repo so the Spawn
	# Director keeps placing a released-but-unfound fragment after a reload.
	FragmentService.sync_repo_from_persistent()
	var resume_day: int = clampi(GameState.save_state.loop.current_day, 1, DayClock.TOTAL_DAYS)
	DayClock.start_day(resume_day)
	# start_day() resets the hour to DAY_START_HOUR; resume the saved hour if it is
	# still within the working day, otherwise leave it at the start-of-day default.
	var saved_hour: int = GameState.save_state.loop.current_hour
	if saved_hour >= DayClock.DAY_START_HOUR and saved_hour < DayClock.DAY_END_HOUR:
		DayClock.set_hour(saved_hour)
	# Resume the exact minute within the hour so reloading restores the saved moment.
	DayClock.set_minute(GameState.save_state.loop.current_minute)


# --- DayClock -> EventBus / GameState bridge ---------------------------------


func _on_hour_changed(day: int, hour: int) -> void:
	GameState.save_state.loop.current_day = day
	GameState.save_state.loop.current_hour = hour
	GameState.save_state.loop.current_minute = 0  # a fresh hour starts at minute 0
	EventBus.hour_changed.emit(day, hour)


func _on_day_changed(day: int) -> void:
	GameState.save_state.loop.current_day = day
	GameState.save_state.loop.yard_scrap_remaining = -1
	EventBus.day_changed.emit(day)


func _on_pause_changed(is_paused: bool, owner_id: String) -> void:
	EventBus.clock_pause_changed.emit(is_paused, owner_id)


# --- Day / loop progression --------------------------------------------------


func _on_day_closed(day: int) -> void:
	# The DayClock close latch is the source of truth: a genuine close leaves the
	# clock closed until we restart it here. A stray/duplicate day_closed arriving
	# after we have already restarted (latch cleared) is ignored, so the Day 5
	# reset can never run twice. _resetting additionally guards re-entrancy.
	if _resetting or not DayClock.is_closed():
		return
	# The mandatory evening runs before day advancement (EVE-R1, §4-N). In interactive
	# mode the evening takes over and advances on commit (EveningService.commit_plan ->
	# advance_day_or_reset); in non-interactive mode (headless/tests) it returns false
	# and advancement proceeds inline exactly as before.
	if EveningService.handle_day_close(day):
		return
	advance_day_or_reset(day)


## Advances to the next day, or performs the Day 5 loop reset. Called inline at the
## close in non-interactive mode, and by EveningService.commit_plan() once the player
## has committed the evening plan (EVE-R5).
func advance_day_or_reset(day: int) -> void:
	if _resetting:
		return
	if day < DayClock.TOTAL_DAYS:
		DayClock.start_day(day + 1)
	else:
		_perform_loop_reset()


## Day 5 reset, in a fixed, idempotent order (SAVE-R1..R6, CLAUDE.md §4-A/B):
##   1. clear loop-scoped state only (persistent knowledge, seated fragments, and
##      spawn history are untouched);
##   2. increment the loop index and reseed the run context;
##   3. restart the clock at Day 1 07:00;
##   4. persist atomically (the save now reflects the fresh loop);
##   5. announce loop_reset once the state is consistent and saved.
func _perform_loop_reset() -> void:
	_resetting = true
	GameState.reset_loop_state()
	GameState.new_run()
	_grant_starting_kit()
	_plan_carrier_placements()
	DayClock.loop_index = GameState.loop_index
	DayClock.start_day(1)
	var save_result := SaveService.save_game()
	if not save_result.ok:
		push_error("LoopController: loop-reset save failed: %s" % save_result.get("error", ""))
	EventBus.loop_reset.emit(GameState.loop_index)
	_resetting = false


func _plan_carrier_placements() -> void:
	var repo := DataRepository.singleton()
	if not repo.is_loaded():
		push_error("LoopController: data repository failed to load")
		return
	var director := SpawnDirector.new(repo, GameState)
	director.plan_loop_placements()


## Grants the authored starting kit: techniques persist, legacy tools persist, and
## every loop starts with the loop-scoped tools listed in data/routes/starting_kit.json.
## This is the narrow integration fix that puts the pendant-cleaning tool in the
## player's hands for the slice (REST-R7).
func _grant_starting_kit() -> void:
	var repo := DataRepository.singleton()
	if not repo.is_loaded():
		return
	for technique_id in repo.starting_kit.get("technique_ids", []):
		if not GameState.save_state.persistent.techniques_learned.has(technique_id):
			GameState.save_state.persistent.techniques_learned.append(technique_id)
	var tools := ToolService.new(GameState, repo)
	for tool_id in repo.starting_kit.get("tool_ids", []):
		var tool := repo.get_tool(tool_id)
		if tool == null:
			continue
		if tool.is_legacy:
			if not GameState.save_state.persistent.legacy_items.has(tool_id):
				GameState.save_state.persistent.legacy_items.append(tool_id)
		if not GameState.save_state.loop.tool_items.has(tool_id):
			GameState.save_state.loop.tool_items.append(tool_id)
		# Also grant a durability-tracked instance so the tool is visible in Storage
		# and can be dragged onto the bench. Idempotent within a loop.
		if not _owns_tool_instance(tool_id):
			tools.grant_tool(tool_id)
	# Debug-only quality-of-life tools are granted automatically in debug/editor builds
	# and never leak into release saves.
	if OS.is_debug_build():
		var debug_clean_all := "debug_clean_all"
		var debug_tool := repo.get_tool(debug_clean_all)
		if debug_tool != null and not _owns_tool_instance(debug_clean_all):
			tools.grant_tool(debug_clean_all)


## True if a durability-tracked instance of the tool already exists this loop.
func _owns_tool_instance(tool_id: String) -> bool:
	for raw in GameState.save_state.loop.owned_tools:
		if raw is Dictionary and raw.get("tool_id") == tool_id:
			return true
	return false

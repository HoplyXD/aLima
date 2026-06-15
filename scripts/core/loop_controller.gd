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
func begin_session() -> void:
	DayClock.reset()
	DayClock.loop_index = GameState.loop_index
	DayClock.running = true
	DayClock.start_day(1)


# --- DayClock -> EventBus / GameState bridge ---------------------------------


func _on_hour_changed(day: int, hour: int) -> void:
	GameState.save_state.loop.current_day = day
	GameState.save_state.loop.current_hour = hour
	EventBus.hour_changed.emit(day, hour)


func _on_day_changed(day: int) -> void:
	GameState.save_state.loop.current_day = day
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
	DayClock.loop_index = GameState.loop_index
	DayClock.start_day(1)
	var save_result := SaveService.save_game()
	if not save_result.ok:
		push_error("LoopController: loop-reset save failed: %s" % save_result.get("error", ""))
	EventBus.loop_reset.emit(GameState.loop_index)
	_resetting = false

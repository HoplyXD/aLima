extends Node
## Reusable, typed day clock with ref-counted pause ownership (CLOCK-R1..R5).
##
## Registered as the `DayClock` autoload. It carries no `class_name` because an
## autoload singleton and a global class of the same name collide in Godot; the
## other core autoloads (EventBus/GameState/SaveService) follow the same rule.
## Tests that need an isolated instance preload this script and call `.new()`.
##
## The clock simulates one shop day (07:00 -> 20:00) at a configurable real-time
## rate. It is intentionally presentation-free: it never touches scene nodes,
## EventBus, or GameState. It advances ONLY when something calls tick(delta), so
## it is deterministic in tests and independent of any scene. The live game
## drives tick() from the active scene's _process; LoopController forwards this
## clock's signals onto EventBus and owns day/loop progression.
##
## Time model: each in-game hour costs `seconds_per_hour` real seconds. A day
## runs 07:00..20:00 (13 in-game hours = ~13 real minutes at 60 s/hour). 20:00 is
## the authoritative close boundary: reaching it latches the clock closed and
## emits `day_closed` exactly once, holding until start_day()/reset() resumes it.

# --- Signals (DayClock-local; LoopController forwards them onto EventBus) -----
signal hour_changed(day: int, hour: int)
signal day_changed(day: int)
signal day_closed(day: int)
signal pause_changed(is_paused: bool, owner_id: String)

const DAY_START_HOUR: int = 7  ## Shop opens 07:00.
const DAY_END_HOUR: int = 20  ## Shop closes at the authoritative 20:00 boundary.
const TOTAL_DAYS: int = 5  ## Five-day loop.
const MINUTES_PER_HOUR: int = 60  ## In-game minutes shown in one clock hour.

## Stable pause-owner IDs for the full-screen systems that freeze shop time
## (CLOCK-R5). Each owner acquires/releases exactly one pause.
const PAUSE_DIALOGUE: String = "dialogue"
const PAUSE_RESTORATION: String = "restoration"
const PAUSE_SCANNER: String = "scanner"
const PAUSE_TRIAGE: String = "triage"
const PAUSE_JOURNAL: String = "journal"
const PAUSE_PORTAL: String = "portal"
const PAUSE_PHONE: String = "phone"
const PAUSE_STORAGE: String = "storage"
const PAUSE_SHOWCASE: String = "showcase"
const PAUSE_DEMO: String = "demo"
const PAUSE_EVENING: String = "evening"

## Real seconds per in-game hour. GDD cadence is 1 real minute = 1 in-game hour.
## Lower this (e.g. 0.1) to watch/verify the clock move faster (debug speed).
var seconds_per_hour: float = 60.0

## Whether the auto-driver (the active scene's _process) should advance the clock
## via tick(). Tests leave this false and drive tick() directly so the simulation
## stays deterministic. tick() itself ignores this flag.
var running: bool = false

var loop_index: int = 0  ## Mirror of the current loop, set by LoopController for display.

var _day: int = 1
var _hour: int = DAY_START_HOUR
var _hour_elapsed: float = 0.0  ## Real seconds elapsed inside the current in-game hour.
var _closed: bool = false  ## Latched true at 20:00 until start_day()/reset().
var _pause_owners: Dictionary = {}  ## Set of owner_id -> true; paused iff non-empty.

# --- Lifecycle / control ------------------------------------------------------


## Full state reset to Day 1, 07:00, stopped, with no pause owners. Emits no
## signals; used for init and deterministic test setup.
func reset() -> void:
	_day = 1
	_hour = DAY_START_HOUR
	_hour_elapsed = 0.0
	_closed = false
	running = false
	_pause_owners.clear()


## Stops the auto-driver without otherwise mutating clock state. Used so an
## autoload clock does not keep ticking after its driving scene is freed.
func stop() -> void:
	running = false


## Begins (or restarts) a day at 07:00 and clears the close latch. Emits
## day_changed then hour_changed so listeners see the day and its opening hour.
func start_day(day: int) -> void:
	_day = day
	_hour = DAY_START_HOUR
	_hour_elapsed = 0.0
	_closed = false
	day_changed.emit(_day)
	hour_changed.emit(_day, _hour)


## Sets the current hour (for resuming a saved game). Clamped to the working day.
## Emits hour_changed if the hour actually changes.
func set_hour(hour: int) -> void:
	var new_hour := clampi(hour, DAY_START_HOUR, DAY_END_HOUR - 1)
	if new_hour != _hour:
		_hour = new_hour
		hour_changed.emit(_day, _hour)


## Sets the minute within the current hour (for resuming a saved game) by seeding the
## elapsed-seconds accumulator. Clamped to 0..59; needs seconds_per_hour set first.
func set_minute(minute: int) -> void:
	var m := clampi(minute, 0, MINUTES_PER_HOUR - 1)
	_hour_elapsed = (float(m) / float(MINUTES_PER_HOUR)) * seconds_per_hour


## Advances the simulation by `delta` real seconds. No-op while paused or closed.
## Emits hour_changed exactly once per in-game hour; on reaching 20:00 it latches
## closed and emits day_closed exactly once, discarding any leftover delta so a
## large frame delta or accelerated debug speed can never skip or duplicate a
## transition or bleed into the next day.
func tick(delta: float) -> void:
	if _closed or is_paused() or seconds_per_hour <= 0.0 or delta <= 0.0:
		return
	_hour_elapsed += delta
	while _hour_elapsed >= seconds_per_hour:
		_hour_elapsed -= seconds_per_hour
		_hour += 1
		if _hour >= DAY_END_HOUR:
			_hour = DAY_END_HOUR
			_hour_elapsed = 0.0
			_closed = true
			day_closed.emit(_day)
			return
		hour_changed.emit(_day, _hour)


# --- Pause ownership (CLOCK-R5) ----------------------------------------------


## Acquires a pause for `owner_id`. Set semantics: a repeat acquire from the same
## owner is idempotent. pause_changed(true) fires only on the empty->non-empty edge.
func request_pause(owner_id: String) -> void:
	if _pause_owners.has(owner_id):
		return
	var was_paused := not _pause_owners.is_empty()
	_pause_owners[owner_id] = true
	if not was_paused:
		pause_changed.emit(true, owner_id)


## Releases `owner_id`'s pause. Releasing an unknown owner is a harmless no-op
## (warned). pause_changed(false) fires only on the non-empty->empty edge, so the
## clock resumes only after every owner has released.
func release_pause(owner_id: String) -> void:
	if not _pause_owners.has(owner_id):
		push_warning("DayClock.release_pause: unknown owner '%s' ignored" % owner_id)
		return
	_pause_owners.erase(owner_id)
	if _pause_owners.is_empty():
		pause_changed.emit(false, owner_id)


# --- Queries ------------------------------------------------------------------


func get_day() -> int:
	return _day


func get_hour() -> int:
	return _hour


## Minute within the current hour (0..59), derived from elapsed real seconds.
func get_minute() -> int:
	var minute := int((_hour_elapsed / maxf(seconds_per_hour, 0.0001)) * MINUTES_PER_HOUR)
	return clampi(minute, 0, MINUTES_PER_HOUR - 1)


## Continuous fractional hour (e.g. 7.5 for 7:30). Useful for smooth visual
## animations like the sun arc, where integer-minute steps would look jittery.
func get_fractional_hour() -> float:
	return float(_hour) + (_hour_elapsed / maxf(seconds_per_hour, 0.0001))


func is_paused() -> bool:
	return not _pause_owners.is_empty()


func is_closed() -> bool:
	return _closed


## True while the clock would actively advance: auto-driver on, not paused, not
## closed. Used by the Shop's is_day_running() seam.
func is_running() -> bool:
	return running and not is_paused() and not _closed


## Number of distinct pause owners currently holding the clock (for debugging/tests).
func pause_owner_count() -> int:
	return _pause_owners.size()


## True if `owner_id` currently holds a pause.
func has_pause_owner(owner_id: String) -> bool:
	return _pause_owners.has(owner_id)

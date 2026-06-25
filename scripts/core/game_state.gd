extends Node
## In-memory owner of player/run context and the split save state.
##
## GameState owns the persistent and loop-scoped state contracts, the current
## run context (player_id, loop_index, run_seed), and a debug seed override.
## It does not manipulate scene nodes. Saving/loading is delegated to
## SaveService; GameState only exposes its state for serialization.

var player_id: String = "local-player"
var loop_index: int = 0
var run_seed: int = 0
var debug_seed_override: int = -1  ## -1 means use a generated seed.
## DEBUG: guarantee a Gold artifact in day-1 deliveries (so the dust overlay contrasts with the
## silver artifacts) — see DeliveryGenerator.DEBUG_FIRST_GOLD. Set false for unbiased deliveries.
var debug_first_gold: bool = true

var save_state: SaveState = SaveState.new()
var run_context: RunContext = RunContext.new()


func _ready() -> void:
	initialize(player_id)


## Initializes or resets the game state for a new player/session. This is the
## narrow helper needed for tests; it does not implement Phase 2 day clock or
## full loop-reset gameplay.
func initialize(new_player_id: String = "local-player") -> void:
	player_id = new_player_id
	loop_index = 0
	debug_seed_override = -1
	save_state = SaveState.new()
	save_state.player_id = player_id
	_load_fragment_definitions()
	_new_run_context()


## Copies authored fragment definitions into persistent state so the loop can
## track their lifecycle (LOCKED -> RELEASED -> SEATED).
func _load_fragment_definitions() -> void:
	var repo := DataRepository.singleton()
	if not repo.is_loaded():
		return
	for fragment_id in repo.fragments.keys():
		var source: Fragment = repo.fragments[fragment_id]
		# Only populate if missing; never overwrite an existing persistent state.
		if not save_state.persistent.fragments.has(fragment_id):
			var copy := Fragment.from_dictionary(source.to_dictionary())
			save_state.persistent.fragments[fragment_id] = copy


## Starts a new run with an optional explicit seed. If seed is negative, the
## run seed is derived from a time-based source (still deterministic once set).
func new_run(seed: int = -1) -> void:
	loop_index += 1
	if seed >= 0:
		run_seed = seed
	elif debug_seed_override >= 0:
		run_seed = debug_seed_override
	else:
		run_seed = int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
	run_context = RunContext.new()
	_update_run_context()


## Resets only loop-scoped state; persistent knowledge survives (SAVE-R1).
func reset_loop_state() -> void:
	save_state.reset_loop_state()


func set_debug_seed_override(seed: int) -> void:
	debug_seed_override = seed


## Creates a deterministic local RandomNumberGenerator for a named stream.
## Different stream names produce independent sequences from the same run seed.
func make_rng(stream_name: String) -> RandomNumberGenerator:
	return run_context.make_rng(stream_name)


## Returns a deterministic integer seed for a named stream.
func derive_seed(stream_name: String) -> int:
	return run_context.derive_seed(stream_name)


func _new_run_context() -> void:
	_update_run_context()


func _update_run_context() -> void:
	run_context.player_id = player_id
	run_context.loop_index = loop_index
	run_context.run_seed = run_seed


## ---------------------------------------------------------------------------
## RunContext
## ---------------------------------------------------------------------------
class RunContext:
	var player_id: String = "local-player"
	var loop_index: int = 0
	var run_seed: int = 0

	## Creates a local RandomNumberGenerator seeded from the run seed and stream
	## name. Never touches global random state.
	func make_rng(stream_name: String) -> RandomNumberGenerator:
		var rng := RandomNumberGenerator.new()
		rng.seed = derive_seed(stream_name)
		return rng

	## Derives a stable seed from the run seed and a stream name.
	func derive_seed(stream_name: String) -> int:
		var hash := stream_name.hash()
		return (run_seed + hash + loop_index * 104729) % 2147483647

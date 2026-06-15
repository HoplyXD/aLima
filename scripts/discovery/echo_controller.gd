extends Node
## Cultural Echo orchestrator.
##
## Manages the active carrier target, proximity smoothing, band mixing, audio
## output, flicker authorization, and the resonance meter/captions state. This is
## a thin autoload that listens to typed EventBus signals and exposes a small,
## explicit scene-integration boundary (listener/carrier positions) so the
## proximity math stays pure and testable.
##
## Invariants enforced here:
##  - Echoes run only for a RELEASED, unfound carrier in the current scene.
##  - Heartbeat is structurally impossible for decoys (is_carrier == true gate).
##  - Flicker is authorized only at proximity >= GLOW_REVEAL_AT and only for the
##    active promoted carrier.
##  - Discovery, seating, removal, opening, loop reset, and scene loss all clear
##    the active target.

signal state_changed(state: Dictionary)

const GLOW_REVEAL_AT := 0.60
const GAIN_EPSILON := 0.001

var _proximity: EchoProximityService
var _active_instance_id: String = ""
var _active_fragment_id: String = ""
var _active_echo_set: EchoSet = null
var _current_gains := {
	EchoMixer.BAND_HUM: 0.0,
	EchoMixer.BAND_MELODY: 0.0,
	EchoMixer.BAND_VOICE: 0.0,
	EchoMixer.BAND_HEARTBEAT: 0.0
}
var _heartbeat_pulse: float = 0.0
var _pulse_accumulator: float = 0.0

@onready var _audio: EchoAudio = _ensure_audio_node()


func _ready() -> void:
	_proximity = EchoProximityService.new()
	_connect_events()


func _process(delta: float) -> void:
	update(delta)


## Public update entrypoint for tests and for callers that drive the controller
## manually. In normal play this is called from _process.
func update(delta: float) -> void:
	_update_internal(delta)


## ---------------------------------------------------------------------------
## Scene integration boundary
## ---------------------------------------------------------------------------


## Sets the listener/source position (e.g. the camera or player focus). Pass
## Vector3.INF to mark invalid.
func set_listener_position(pos: Vector3) -> void:
	_proximity.source_position = pos


## Sets the active carrier's position. Pass Vector3.INF to mark invalid.
func set_carrier_position(pos: Vector3) -> void:
	_proximity.target_position = pos


## ---------------------------------------------------------------------------
## Public query API
## ---------------------------------------------------------------------------


## Returns true when the active target is a valid carrier and proximity is at or
## above the flicker reveal threshold.
func is_flicker_authorized(instance_id: String) -> bool:
	if _active_instance_id.is_empty() or _active_instance_id != instance_id:
		return false
	var inst := _find_instance(_active_instance_id)
	if inst == null or not inst.is_carrier:
		return false
	return _proximity.smoothed_proximity >= GLOW_REVEAL_AT


## Returns true only for the active promoted carrier. Decoys always return false.
func is_heartbeat_authorized(instance_id: String) -> bool:
	if _active_instance_id.is_empty() or _active_instance_id != instance_id:
		return false
	var inst := _find_instance(_active_instance_id)
	return inst != null and inst.is_carrier


## Returns a snapshot of the echo state for the HUD.
func get_state() -> Dictionary:
	var inst := _find_instance(_active_instance_id)
	var valid := _is_target_valid(inst)
	var active_bands: Array[String] = []
	if valid:
		active_bands = EchoMixer.active_bands(_current_gains)
	return {
		"valid": valid,
		"instance_id": _active_instance_id,
		"fragment_id": _active_fragment_id,
		"proximity": _proximity.smoothed_proximity if valid else 0.0,
		"raw_proximity": _proximity.raw_proximity if valid else 0.0,
		"active_bands": active_bands,
		"voice_caption": _voice_caption() if valid else "",
		"heartbeat_pulse": _heartbeat_pulse if valid else 0.0,
		"gains": _current_gains.duplicate(),
	}


## Forces the active target to clear (e.g. when the Shop scene closes).
func clear_active_target() -> void:
	_set_active_target("")


## ---------------------------------------------------------------------------
## Internal lifecycle
## ---------------------------------------------------------------------------


func _ensure_audio_node() -> EchoAudio:
	var existing := get_node_or_null("Audio")
	if existing is EchoAudio:
		return existing
	var node := EchoAudio.new()
	node.name = "Audio"
	add_child(node)
	return node


func _connect_events() -> void:
	EventBus.carrier_activated.connect(_on_carrier_activated)
	EventBus.fragment_discovered.connect(_on_fragment_discovered)
	EventBus.fragment_seated.connect(_on_fragment_seated)
	EventBus.loop_reset.connect(_on_loop_reset)
	EventBus.triage_completed.connect(_on_triage_completed)
	EventBus.object_opened.connect(_on_object_opened)


func _update_internal(delta: float) -> void:
	if GameState.save_state == null:
		return
	_proximity.update(delta)
	var inst := _find_instance(_active_instance_id)
	var valid := _is_target_valid(inst)

	if not valid:
		if _audio.is_playing():
			_audio.stop_all()
		if _any_gain_audible():
			_current_gains = {
				EchoMixer.BAND_HUM: 0.0,
				EchoMixer.BAND_MELODY: 0.0,
				EchoMixer.BAND_VOICE: 0.0,
				EchoMixer.BAND_HEARTBEAT: 0.0
			}
			state_changed.emit(get_state())
		return

	if _active_echo_set == null:
		var fragment: Fragment = GameState.save_state.persistent.fragments.get(_active_fragment_id)
		if fragment != null:
			_active_echo_set = DataRepository.singleton().get_echo_set(fragment.echo_set_ref)
		if _active_echo_set != null:
			_proximity.far_radius = _active_echo_set.far_radius
			_proximity.near_radius = _active_echo_set.near_radius
			_proximity.smoothing_time = _active_echo_set.smoothing_time
			_audio.set_echo_set(_active_echo_set)

	if _active_echo_set == null:
		return

	if not _audio.is_playing():
		_audio.play_all()

	var heartbeat_authorized := inst.is_carrier
	var gains := EchoMixer.calculate_band_gains(
		_proximity.smoothed_proximity, _active_echo_set, heartbeat_authorized
	)
	_audio.apply_gains(gains)
	_current_gains = gains
	_update_pulse(delta, _current_gains.get(EchoMixer.BAND_HEARTBEAT, 0.0))
	EventBus.echo_proximity_changed.emit(
		_active_instance_id, _proximity.smoothed_proximity, _dominant_band(gains)
	)
	state_changed.emit(get_state())


func _update_pulse(delta: float, heartbeat_linear: float) -> void:
	if heartbeat_linear <= GAIN_EPSILON:
		_heartbeat_pulse = 0.0
		return
	# Pulse at ~72 BPM when heartbeat is active; intensity follows gain.
	_pulse_accumulator += delta
	var beat_interval := 60.0 / 72.0
	var phase := fmod(_pulse_accumulator, beat_interval) / beat_interval
	var pulse := 0.0
	if phase < 0.25:
		pulse = sin(phase * 4.0 * PI) * heartbeat_linear
	_heartbeat_pulse = pulse


func _set_active_target(instance_id: String) -> void:
	if _active_instance_id == instance_id:
		return
	_active_instance_id = instance_id
	_active_fragment_id = ""
	_active_echo_set = null
	if instance_id.is_empty():
		_proximity.clear_target()
		_audio.stop_all()
		_audio.set_echo_set(null)
		_current_gains = {
			EchoMixer.BAND_HUM: 0.0,
			EchoMixer.BAND_MELODY: 0.0,
			EchoMixer.BAND_VOICE: 0.0,
			EchoMixer.BAND_HEARTBEAT: 0.0
		}
	else:
		var inst := _find_instance(instance_id)
		if inst != null and inst.is_carrier and not inst.fragment_id.is_empty():
			_active_fragment_id = inst.fragment_id
	state_changed.emit(get_state())


func _is_target_valid(inst: ObjectInstance) -> bool:
	if GameState.save_state == null:
		return false
	if inst == null or not inst.is_carrier or inst.fragment_id.is_empty():
		return false
	var fragment: Fragment = GameState.save_state.persistent.fragments.get(inst.fragment_id)
	if fragment == null or fragment.state != ModelEnums.FragmentState.RELEASED:
		return false
	if inst.state == ModelEnums.ObjState.OPEN:
		return false
	return _instance_is_present(inst)


## An instance is present if it is in the current delivery or in the loop
## inventory (i.e. it has not been recycled).
func _instance_is_present(inst: ObjectInstance) -> bool:
	if GameState.save_state == null:
		return false
	for id in GameState.save_state.loop.current_delivery_ids:
		if id == inst.uid:
			return true
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == inst.uid:
			return true
	return false


func _find_instance(instance_id: String) -> ObjectInstance:
	if GameState.save_state == null:
		return null
	for raw in GameState.save_state.loop.inventory:
		if raw is Dictionary and raw.get("uid") == instance_id:
			return ObjectInstance.from_dictionary(raw)
	return null


func _voice_caption() -> String:
	if _active_echo_set == null:
		return ""
	var voice_gain: float = _current_gains.get(EchoMixer.BAND_VOICE, 0.0)
	if voice_gain <= GAIN_EPSILON:
		return ""
	return _active_echo_set.voice_caption


func _dominant_band(gains: Dictionary) -> String:
	var best := ""
	var best_gain := -1.0
	for band in [
		EchoMixer.BAND_HEARTBEAT, EchoMixer.BAND_VOICE, EchoMixer.BAND_MELODY, EchoMixer.BAND_HUM
	]:
		var g: float = gains.get(band, 0.0)
		if g > best_gain:
			best_gain = g
			best = band
	return best


func _any_gain_audible() -> bool:
	for g in _current_gains.values():
		if g > GAIN_EPSILON:
			return true
	return false


## ---------------------------------------------------------------------------
## Event handlers
## ---------------------------------------------------------------------------


func _on_carrier_activated(instance_id: String, _fragment_id: String) -> void:
	if _active_instance_id.is_empty():
		_set_active_target(instance_id)


func _on_fragment_discovered(fragment_id: String, instance_id: String) -> void:
	if _active_fragment_id == fragment_id or _active_instance_id == instance_id:
		_set_active_target("")


func _on_fragment_seated(fragment_id: String, _slot_index: int) -> void:
	if _active_fragment_id == fragment_id:
		_set_active_target("")


func _on_loop_reset(_loop_index: int) -> void:
	_set_active_target("")


func _on_triage_completed(_kept: Array, recycled_ids: Array) -> void:
	if _active_instance_id.is_empty():
		return
	if recycled_ids.has(_active_instance_id):
		_set_active_target("")


func _on_object_opened(instance_id: String, _result: String, _content_id: String) -> void:
	if _active_instance_id == instance_id:
		_set_active_target("")

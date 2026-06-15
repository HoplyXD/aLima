class_name EchoAudio
extends Node
## Four-layer Cultural Echo audio presentation.
##
## Owns four AudioStreamPlayer nodes routed to dedicated buses (Hum, Melody,
## Voice, Heartbeat). Loads streams from the active EchoSet, starts all available
## layers together from a synchronized timeline, and applies crossfades by
## changing volume_db without restarting clips. Missing development audio is
## handled gracefully: the player is left with no stream and zero gain, and the
## system continues to work.
##
## Call apply_gains() each frame or whenever the mixer produces new values. Call
## set_echo_set() when the active target changes. Call stop_all() when the target
## becomes invalid.

const BUS_HUM := "Hum"
const BUS_MELODY := "Melody"
const BUS_VOICE := "Voice"
const BUS_HEARTBEAT := "Heartbeat"

const BAND_HUM := "hum"
const BAND_MELODY := "melody"
const BAND_VOICE := "voice"
const BAND_HEARTBEAT := "heartbeat"

var _echo_set: EchoSet = null
var _muted: bool = false
var _is_playing: bool = false

@onready var _hum_player: AudioStreamPlayer = _ensure_player(BAND_HUM, BUS_HUM)
@onready var _melody_player: AudioStreamPlayer = _ensure_player(BAND_MELODY, BUS_MELODY)
@onready var _voice_player: AudioStreamPlayer = _ensure_player(BAND_VOICE, BUS_VOICE)
@onready var _heartbeat_player: AudioStreamPlayer = _ensure_player(BAND_HEARTBEAT, BUS_HEARTBEAT)


func _ready() -> void:
	_hum_player.bus = BUS_HUM
	_melody_player.bus = BUS_MELODY
	_voice_player.bus = BUS_VOICE
	_heartbeat_player.bus = BUS_HEARTBEAT


## Sets the EchoSet whose streams will be loaded. If the set changes, all players
## are stopped and will restart together on the next play call.
func set_echo_set(echo_set: EchoSet) -> void:
	if _echo_set == echo_set:
		return
	_echo_set = echo_set
	_stop_and_clear_players()
	if echo_set == null:
		return
	_load_stream(_hum_player, echo_set.hum_stream)
	_load_stream(_melody_player, echo_set.melody_stream)
	_load_stream(_voice_player, echo_set.voice_stream)
	_load_stream(_heartbeat_player, echo_set.heartbeat_stream)


## Starts all loaded layers together. Safe to call repeatedly; if already playing,
## players are not restarted.
func play_all() -> void:
	if _is_playing:
		return
	_is_playing = true
	_play_if_stream(_hum_player)
	_play_if_stream(_melody_player)
	_play_if_stream(_voice_player)
	_play_if_stream(_heartbeat_player)


## Stops all layers and resets playback position so the next play starts fresh.
func stop_all() -> void:
	_is_playing = false
	_hum_player.stop()
	_melody_player.stop()
	_voice_player.stop()
	_heartbeat_player.stop()


## Applies per-band linear gains. Players with zero gain are muted at the player
## level so bus muting remains independent. Gains outside 0..1 are clamped.
func apply_gains(gains: Dictionary) -> void:
	var hum := clampf(gains.get(BAND_HUM, 0.0), 0.0, 1.0)
	var melody := clampf(gains.get(BAND_MELODY, 0.0), 0.0, 1.0)
	var voice := clampf(gains.get(BAND_VOICE, 0.0), 0.0, 1.0)
	var heartbeat := clampf(gains.get(BAND_HEARTBEAT, 0.0), 0.0, 1.0)

	_apply_player_gain(_hum_player, hum)
	_apply_player_gain(_melody_player, melody)
	_apply_player_gain(_voice_player, voice)
	_apply_player_gain(_heartbeat_player, heartbeat)


## Global mute for this echo layer. Does not affect bus muting.
func set_muted(value: bool) -> void:
	_muted = value
	if _muted:
		_hum_player.volume_db = EchoMixer.SILENCE_DB
		_melody_player.volume_db = EchoMixer.SILENCE_DB
		_voice_player.volume_db = EchoMixer.SILENCE_DB
		_heartbeat_player.volume_db = EchoMixer.SILENCE_DB


## Returns true if all layers are currently playing.
func is_playing() -> bool:
	return _is_playing


func _ensure_player(band: String, bus_name: String) -> AudioStreamPlayer:
	var existing := get_node_or_null(band)
	if existing is AudioStreamPlayer:
		return existing
	var player := AudioStreamPlayer.new()
	player.name = band
	player.bus = bus_name
	add_child(player)
	return player


func _load_stream(player: AudioStreamPlayer, path: String) -> void:
	player.stream = null
	if path.is_empty():
		return
	if not ResourceLoader.exists(path):
		push_warning("EchoAudio: missing stream '%s'" % path)
		return
	var stream := ResourceLoader.load(path, "AudioStream")
	if stream == null:
		push_warning("EchoAudio: could not load stream '%s'" % path)
		return
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	player.stream = stream
	player.volume_db = EchoMixer.SILENCE_DB


func _play_if_stream(player: AudioStreamPlayer) -> void:
	if player.stream == null:
		return
	if not player.playing:
		player.play(0.0)


func _apply_player_gain(player: AudioStreamPlayer, linear: float) -> void:
	if _muted:
		return
	player.volume_db = EchoMixer.linear_to_db(linear)


func _stop_and_clear_players() -> void:
	stop_all()
	_hum_player.stream = null
	_melody_player.stream = null
	_voice_player.stream = null
	_heartbeat_player.stream = null

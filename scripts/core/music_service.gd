extends Node
## MusicService autoload — the single source of background music.
##
## Crossfades between named tracks on the `Music` bus (added in
## default_bus_layout.tres; trimmed by SettingsService.music_volume). Two pooled
## `AudioStreamPlayer`s ping-pong so one fades in while the other fades out.
##
## Track policy (per design):
##   - bgm_3  → the title intro + main menu.
##   - bgm_1  → all gameplay spaces.
##   - SILENCE → the Day-0 junkshop (tutorial) and the Day-1 intro dialogue; bgm_1
##     resumes once the Day-1 intro finishes.
##
## The intro/menu call play_track("bgm_3") directly; gameplay music is driven
## automatically from SpaceManager.space_changed (see _apply_gameplay_music).

## Music bus (see default_bus_layout.tres).
const MUSIC_BUS := &"Music"

## Track id -> resource path. Drop the real files at these paths; any that are
## missing fall back to FALLBACK_TRACK so the game always has something to play.
const TRACKS := {
	"bgm_1": "res://assets/audio/bmg/bgm 1.wav",
	"bgm_2": "res://assets/audio/bmg/bgm 2.wav",
	"bgm_3": "res://assets/audio/bmg/bgm 3.wav",
}
const FALLBACK_TRACK := "res://assets/audio/bmg/Maharlikang Bahandi Music.wav"

const FADE_TIME: float = 1.2
const FULL_DB: float = 0.0
const SILENT_DB: float = -40.0

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current_id: String = ""


func _ready() -> void:
	# Music must survive pauses and scene swaps.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "MusicVoice%d" % i
		player.bus = MUSIC_BUS
		player.volume_db = SILENT_DB
		# Loop the track by replaying it when it ends (works regardless of the
		# stream's own loop import setting).
		player.finished.connect(_on_voice_finished.bind(i))
		add_child(player)
		_players.append(player)
	SpaceManager.space_changed.connect(_on_space_changed)
	# When the Day-1 intro dialogue wraps, bring gameplay music back in.
	Day1Service.day1_intro_finished.connect(func() -> void: _apply_gameplay_music())


## Crossfades to `track_id`. No-op if it is already the playing track.
func play_track(track_id: String, fade: float = FADE_TIME) -> void:
	if track_id == _current_id and _players[_active].playing:
		return
	_current_id = track_id
	if DisplayServer.get_name() == "headless":
		return
	var stream := _resolve(track_id)
	if stream == null:
		return
	var incoming := 1 - _active
	var in_player := _players[incoming]
	var out_player := _players[_active]
	in_player.stream = stream
	in_player.volume_db = SILENT_DB
	in_player.play()
	_active = incoming
	var tween := create_tween().set_parallel(true)
	tween.tween_property(in_player, "volume_db", FULL_DB, fade)
	tween.tween_property(out_player, "volume_db", SILENT_DB, fade)
	tween.chain().tween_callback(out_player.stop)


## Fades all music out to silence (e.g. the quiet Day-0 junkshop).
func stop(fade: float = FADE_TIME) -> void:
	_current_id = ""
	if DisplayServer.get_name() == "headless":
		return
	for player in _players:
		if player.playing:
			var tween := create_tween()
			tween.tween_property(player, "volume_db", SILENT_DB, fade)
			tween.tween_callback(player.stop)


# --- Gameplay policy ----------------------------------------------------------


func _on_space_changed(space: SpaceManager.Space) -> void:
	_apply_gameplay_music(space)


## bgm_1 everywhere, except the Day-0 junkshop (tutorial) and the Day-1 intro
## dialogue, which stay silent until the intro finishes.
func _apply_gameplay_music(space: SpaceManager.Space = SpaceManager.current_space) -> void:
	var quiet_shop := (
		space == SpaceManager.Space.SHOP
		and (TutorialService.is_tutorial_active() or Day1Service.is_day1_intro_active())
	)
	if quiet_shop:
		stop()
	else:
		play_track("bgm_1")


# --- Internals ----------------------------------------------------------------


func _on_voice_finished(index: int) -> void:
	# Loop only the voice that is still the active track.
	if index == _active and not _current_id.is_empty():
		_players[index].play()


func _resolve(track_id: String) -> AudioStream:
	var path := String(TRACKS.get(track_id, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path)
	if ResourceLoader.exists(FALLBACK_TRACK):
		return load(FALLBACK_TRACK)
	push_warning("MusicService: no audio for '%s' (and no fallback)." % track_id)
	return null

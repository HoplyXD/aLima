extends CanvasLayer
## Animated scene-change driver: fade-out → loading screen → async (threaded) load → fade-in.
##
## This is the "SceneManager" role, named SceneTransition to avoid collision with the existing
## SpaceManager (the tested two-space state machine in scripts/core/space_manager.gd).
## SceneTransition is the *presentation* layer; SpaceManager stays the source of truth for which
## space is active. Route SpaceManager's loader seam through here to animate its transitions —
## see the wiring note in the controller summary.
##
## Sequence (transition_to):
##   1. Fade the screen to `fade_color`. WAIT for this to finish before unloading anything.
##   2. Swap to res://scenes/ui/loading_screen.tscn and fade in to reveal it.
##   3. Stream the target scene with ResourceLoader.load_threaded_request (off the main thread),
##      polling progress and honouring `min_loading_time` so the screen never flickers past.
##   4. Once 100% loaded, fade out, swap to the target, fade back in to reveal it.
##
## Register as an Autoload named `SceneTransition` (project.godot [autoload]).

signal transition_started(path: String)
signal transition_finished(path: String)

const LOADING_SCENE := "res://scenes/ui/loading_screen.tscn"

@export var fade_duration: float = 0.4
@export var fade_color: Color = Color(0, 0, 0, 1)
## Minimum seconds the loading screen stays up even if the target loads instantly.
@export var min_loading_time: float = 0.6

var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	# Draw above everything, and keep running while the tree is paused (e.g. during triage pause).
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = fade_color
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_fade.visible = false
	add_child(_fade)


## Animated swap to `target_path`. Re-entrant calls while busy are ignored.
func transition_to(target_path: String) -> void:
	if _busy:
		push_warning("SceneTransition.transition_to ignored — a transition is already running.")
		return
	_busy = true
	transition_started.emit(target_path)

	# 1. Cover the current scene and WAIT before unloading it.
	await _fade_to(1.0)

	# 2. Show the loading screen and reveal it behind a brief fade-in.
	get_tree().change_scene_to_file(LOADING_SCENE)
	await get_tree().process_frame
	var loading := get_tree().current_scene as LoadingScreen
	await _fade_to(0.0)
	if loading != null:
		loading.reveal()

	# 3. Stream the target off the main thread while the screen animates.
	var packed := await _load_threaded(target_path, loading)

	# 4. Cover, swap in the real scene, reveal.
	await _fade_to(1.0)
	if packed != null:
		get_tree().change_scene_to_packed(packed)
	else:
		push_error("SceneTransition: failed to load %s" % target_path)
		get_tree().change_scene_to_file(target_path)  # last-resort blocking load
	await get_tree().process_frame
	await _fade_to(0.0)

	_busy = false
	transition_finished.emit(target_path)


## Threaded load with progress + a minimum on-screen time. Returns the PackedScene or null.
func _load_threaded(path: String, loading: LoadingScreen) -> PackedScene:
	if ResourceLoader.load_threaded_request(path) != OK:
		return null
	var progress: Array = [0.0]
	var elapsed := 0.0
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if loading != null:
			loading.set_progress(progress[0])
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				break
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				return null
		elapsed += await _frame_delta()
	# Hold the screen until the minimum display time has elapsed.
	while elapsed < min_loading_time:
		elapsed += await _frame_delta()
	return ResourceLoader.load_threaded_get(path) as PackedScene


## Tweens the fade overlay alpha and awaits completion.
func _fade_to(alpha: float) -> void:
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, fade_duration)
	await tween.finished
	_fade.visible = alpha > 0.0


## Awaits one frame and returns the time it took (so we can accumulate elapsed seconds).
func _frame_delta() -> float:
	await get_tree().process_frame
	return get_process_delta_time()

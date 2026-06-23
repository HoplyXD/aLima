class_name ShowcaseScreen
extends CanvasLayer
## Scripted photograph showcase for an authored route beat (Phase 10, P10.3).
##
## This is an *emotional authored showcase*, not a second restoration mini-game: a
## short, paused 2D sequence (before -> a single restoring action -> after) framed by
## the route portrait and the authored beat summary. Completing it records the beat
## through RouteService (which enforces ordinal gating and, on the final beat,
## releases the route's fragment via FragmentService). The showcase never grants a
## fragment, item, or money directly.
##
## Presentation only; the UI is built in code so the scene file stays trivial. The
## stable seams the GUT tests drive are open()/advance()/is_open() and the
## beat_completed/closed signals.

signal closed
## Emitted once when the showcase's beat is recorded as complete.
signal beat_completed(route_id: String, beat_id: String)

# Authored, clearly-placeholder supportive captions (subject to cultural review).
const _STEP_PROMPTS: Array[String] = [
	"Begin the restoration",
	"Reveal what you saved",
	"Set it down gently",
]

var _route_id: String = ""
var _beat_id: String = ""
var _step: int = 0
var _owns_pause: bool = false
var _completed: bool = false

var _backdrop: ColorRect
var _portrait: TextureRect
var _photo: ColorRect
var _title_label: Label
var _summary_label: RichTextLabel
var _caption_label: Label
var _primary_button: Button


func _ready() -> void:
	layer = 80
	visible = false
	_build_ui()


## Opens the showcase for a route beat. `beat` is the authored beat dict
## (id/day/object_template/summary). Pauses shop time while open.
func open(route: CharacterRoute, beat: Dictionary) -> void:
	if route == null or beat.is_empty():
		push_warning("ShowcaseScreen: open called without a route/beat")
		return
	_route_id = route.id
	_beat_id = str(beat.get("id"))
	_step = 0
	_completed = false

	_title_label.text = "%s — A Photograph to Mend" % route.display_name
	_summary_label.text = str(beat.get("summary"))
	if not route.portrait.is_empty():
		var tex: Texture2D = load(route.portrait)
		if tex != null:
			_portrait.texture = tex

	visible = true
	if not _owns_pause:
		DayClock.request_pause(DayClock.PAUSE_SHOWCASE)
		_owns_pause = true
	_render_step()
	_primary_button.grab_focus()


func is_open() -> bool:
	return visible


## Advances the showcase one step. On the final step it records the beat (once) and
## closes. Exposed so the shop button and the tests share one path.
func advance() -> void:
	if not visible:
		return
	if _step < _STEP_PROMPTS.size() - 1:
		_step += 1
		_render_step()
		return
	_finish()


func close() -> void:
	if visible:
		visible = false
		_release_pause_if_owned()
	closed.emit()


func _exit_tree() -> void:
	_release_pause_if_owned()


func _finish() -> void:
	# Record the beat exactly once. RouteService enforces gating and, on the route's
	# final beat, releases the fragment — the showcase itself never hands one over.
	if not _completed:
		_completed = true
		if RouteService.complete_beat(_route_id, _beat_id):
			beat_completed.emit(_route_id, _beat_id)
	close()


func _render_step() -> void:
	_primary_button.text = _STEP_PROMPTS[_step]
	match _step:
		0:
			_photo.color = Color(0.12, 0.10, 0.09)  # grimy "before"
			_caption_label.text = "The photograph is dim with age. Take your time."
		1:
			_photo.color = Color(0.55, 0.45, 0.32)  # mid-restoration
			_caption_label.text = "Old grime lifts away under a careful hand."
		2:
			_photo.color = Color(0.93, 0.86, 0.70)  # warm "after"
			_caption_label.text = "There they are again — a moment, kept."


func _release_pause_if_owned() -> void:
	if _owns_pause:
		if DayClock.has_pause_owner(DayClock.PAUSE_SHOWCASE):
			DayClock.release_pause(DayClock.PAUSE_SHOWCASE)
		_owns_pause = false


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.78)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 520)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 28)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(220, 300)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_portrait)

	var photo_frame := PanelContainer.new()
	photo_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	photo_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(photo_frame)

	_photo = ColorRect.new()
	_photo.color = Color(0.12, 0.10, 0.09)
	_photo.custom_minimum_size = Vector2(300, 300)
	photo_frame.add_child(_photo)

	_summary_label = RichTextLabel.new()
	_summary_label.bbcode_enabled = true
	_summary_label.fit_content = true
	_summary_label.custom_minimum_size = Vector2(0, 90)
	col.add_child(_summary_label)

	_caption_label = Label.new()
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_caption_label)

	_primary_button = Button.new()
	_primary_button.custom_minimum_size = Vector2(0, 48)
	_primary_button.pressed.connect(advance)
	col.add_child(_primary_button)

class_name TutorialHintBox
extends Control
## Compact tutorial hint: plain text, a small circular speaker face, and an
## animated pointer arrow aimed at whatever the player should use next (TUT).
##
## Unlike DialogueBox (full conversations, typewriter, input-driven), this box
## is a passive, persistent nudge: it never consumes input and stays up until
## hide_hint(). Speakers are authored in data/tutorial/speakers.json; portraits
## are optional — a coloured circle with the speaker's initial is the fallback.
## For 3D anchors, callers project with camera.unproject_position() and call
## point_at_screen_pos().

const SPEAKERS_PATH := "res://data/tutorial/speakers.json"
const ARROW_SIZE: float = 26.0
const ARROW_GAP: float = 14.0  ## Hover distance above the target point.
const ARROW_BOB: float = 8.0
## Targets above this screen y flip the arrow below the point (aiming up), so
## top-bar buttons (Scan & Judge, Close) never push it off-screen.
const TOP_FLIP_ZONE: float = 90.0

static var _speakers: Dictionary = {}
static var _speakers_loaded: bool = false

var _arrow_target: Vector2 = Vector2.ZERO
var _arrow_visible: bool = false
var _time: float = 0.0
var _show_tween: Tween
var _hide_tween: Tween

@onready var _panel: PanelContainer = %HintPanel
@onready var _portrait_bg: Panel = %PortraitCircle
@onready var _initial_label: Label = %PortraitInitial
@onready var _portrait_rect: TextureRect = %PortraitTexture
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _text_label: Label = %HintText


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_style()
	hide()
	modulate.a = 0.0
	scale = Vector2.ONE * 0.98


func _process(delta: float) -> void:
	if _arrow_visible:
		_time += delta
		queue_redraw()


func _draw() -> void:
	if not _arrow_visible:
		return
	# A bobbing triangle hovering near the target, pointing at it. Targets near the
	# top edge (top-bar buttons like Scan & Judge / Close) flip the arrow BELOW the
	# point, aiming up, so it never draws off-screen.
	var bob := sin(_time * 4.0) * ARROW_BOB
	var half := ARROW_SIZE * 0.5
	var points: PackedVector2Array
	if _arrow_target.y < TOP_FLIP_ZONE:
		# Below the target, tip pointing up at it.
		var tip := _arrow_target + Vector2(0.0, ARROW_GAP - bob)
		points = PackedVector2Array(
			[tip, tip + Vector2(-half, ARROW_SIZE), tip + Vector2(half, ARROW_SIZE)]
		)
	else:
		# Above the target, tip pointing down at it.
		var tip := _arrow_target + Vector2(0.0, -ARROW_GAP + bob)
		points = PackedVector2Array(
			[tip, tip + Vector2(-half, -ARROW_SIZE), tip + Vector2(half, -ARROW_SIZE)]
		)
	# Brass arrow with a deep-ink outline, matching the shared UI palette.
	draw_colored_polygon(points, UiPalette.SOFT_GOLD)
	draw_polyline(
		PackedVector2Array([points[0], points[1], points[2], points[0]]),
		Color(0.12, 0.10, 0.07, 0.9),
		2.0
	)


## Shows the hint text as `speaker_id` (resolved from speakers.json; unknown ids
## fall back to the raw id with a neutral face). Text supports {player} tokens.
func show_hint(speaker_id: String, text: String) -> void:
	if _hide_tween != null and _hide_tween.is_valid():
		_hide_tween.kill()
	var speaker := _resolve_speaker(speaker_id)
	_speaker_label.text = DialogueVars.format(str(speaker.get("display_name", speaker_id)))
	_text_label.text = DialogueVars.format(text)
	var color := Color.from_string(str(speaker.get("color", "")), Color(0.35, 0.35, 0.4))
	_portrait_bg.self_modulate = color
	var portrait_path := str(speaker.get("portrait", ""))
	var texture: Texture2D = null
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		texture = load(portrait_path) as Texture2D
	_portrait_rect.texture = texture
	_portrait_rect.visible = texture != null
	_initial_label.visible = texture == null
	_initial_label.text = _speaker_label.text.left(1).to_upper()
	show()
	_animate_show()


func hide_hint() -> void:
	clear_pointer()
	hide()
	_animate_hide()


## Aims the arrow at a screen-space point (e.g. an unprojected 3D interactable).
func point_at_screen_pos(pos: Vector2) -> void:
	_arrow_target = pos
	_arrow_visible = true
	queue_redraw()


## Aims the arrow at the center-top of a Control (e.g. the tool sidebar).
## Top-bar controls are aimed at from BELOW their bottom edge instead (the
## arrow flips upward in _draw), so it never covers the button or leaves the screen.
func point_at_control(target: Control) -> void:
	var rect := target.get_global_rect()
	if rect.position.y < TOP_FLIP_ZONE:
		point_at_screen_pos(Vector2(rect.get_center().x, rect.end.y))
	else:
		point_at_screen_pos(Vector2(rect.get_center().x, rect.position.y))


func clear_pointer() -> void:
	_arrow_visible = false
	queue_redraw()


func _apply_style() -> void:
	if _panel != null:
		_panel.add_theme_stylebox_override("panel", UiPalette.manuscript_card_style())
	if _portrait_bg != null:
		_portrait_bg.add_theme_stylebox_override(
			"panel", UiPalette.panel_style(Color(0.17, 0.14, 0.10, 1.0), UiPalette.SOFT_GOLD, 24)
		)
	if _speaker_label != null:
		_speaker_label.add_theme_color_override("font_color", UiPalette.SOFT_GOLD)
	if _text_label != null:
		_text_label.add_theme_color_override("default_color", UiPalette.BONE)
		_text_label.add_theme_color_override("font_color", UiPalette.BONE)


func _animate_show() -> void:
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	modulate.a = 0.0
	scale = Vector2.ONE * 0.98
	_show_tween = create_tween()
	_show_tween.set_trans(Tween.TRANS_SINE)
	_show_tween.set_ease(Tween.EASE_OUT)
	_show_tween.tween_property(self, "modulate:a", 1.0, 0.16)
	_show_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.18)


func _animate_hide() -> void:
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	if _hide_tween != null and _hide_tween.is_valid():
		_hide_tween.kill()
	_hide_tween = create_tween()
	_hide_tween.set_trans(Tween.TRANS_SINE)
	_hide_tween.set_ease(Tween.EASE_IN)
	_hide_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_hide_tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.98, 0.12)
	_hide_tween.finished.connect(func() -> void: hide())


## Test/introspection seams.
func arrow_target() -> Vector2:
	return _arrow_target


func is_pointing() -> bool:
	return _arrow_visible


## Resolved display name for a speaker id ({player}-substituted). Shared with
## other tutorial presentation (e.g. TutorialGlue's dialogue lines).
static func speaker_display_name(speaker_id: String) -> String:
	var speaker := _resolve_speaker(speaker_id)
	return DialogueVars.format(str(speaker.get("display_name", speaker_id)))


static func _resolve_speaker(speaker_id: String) -> Dictionary:
	_ensure_speakers_loaded()
	var speaker: Variant = _speakers.get(speaker_id)
	if speaker is Dictionary:
		return speaker
	return {"display_name": speaker_id, "color": "", "portrait": ""}


static func _ensure_speakers_loaded() -> void:
	if _speakers_loaded:
		return
	_speakers_loaded = true
	var file := FileAccess.open(SPEAKERS_PATH, FileAccess.READ)
	if file == null:
		push_warning("TutorialHintBox: cannot open %s" % SPEAKERS_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		push_warning("TutorialHintBox: malformed %s" % SPEAKERS_PATH)
		return
	var raw: Variant = (json.data as Dictionary).get("speakers")
	if raw is Dictionary:
		_speakers = raw

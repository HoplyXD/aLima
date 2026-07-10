extends Control
## Splash screen: fades the whole scene in from black, flips the logo like a card,
## shimmers a glow across the title letters one at a time, then fades back to black
## and hands off to the title screen. Any key/click skips ahead.
##
## The black ColorRect stays opaque the whole time; only the `Content` group
## (logo + letters) fades, so there is never a flash of the engine clear colour.

@export var next_scene: PackedScene = preload("res://scenes/ui/title_intro.tscn")

@export_group("Timing")
@export var fade_in_time: float = 1.0
@export var hold_time: float = 1.8
@export var fade_out_time: float = 0.8

@export_group("Logo")
## Optional logo override; when empty the TextureRect's own texture is used.
@export var logo: Texture2D
## Seconds for one half-flip (face-on -> edge-on -> flipped). Lower = faster.
@export var flip_half_duration: float = 0.6
## Pause between flips so it reads as a deliberate beat, not a wobble.
@export var flip_pause: float = 0.8

@export_group("Title")
@export var title_text: String = "Alima"
@export var title_font: Font = preload("res://assets/fonts/CloisterBlack.ttf")
@export var title_font_size: int = 151
@export var title_color: Color = Color(0.96, 0.9, 0.72)

@export_group("Letter Glow")
@export var glow_color: Color = Color(1.0, 0.92, 0.62)
## Soft halo radius (px) at the peak of each letter's glow.
@export var glow_max_size: int = 32
## How fast the glow wave travels across the letters.
@export var glow_speed: float = 2.6
## Phase offset per letter — bigger spacing = slower left-to-right shimmer.
@export var glow_stagger: float = 0.55
## Higher = a tighter, sparklier peak on each letter.
@export var glow_sharpness: float = 3.0

@onready var _content: Control = $Content
@onready var _logo_rect: TextureRect = $Content/CenterContainer/VBoxContainer/TextureRect
@onready var _letters_box: HBoxContainer = $Content/CenterContainer/VBoxContainer/Letters

var _letters: Array[Label] = []
var _phase := "in"
var _t := 0.0
var _glow_t := 0.0
var _leaving := false


func _ready() -> void:
	if logo != null:
		_logo_rect.texture = logo
	# Flip around the logo's centre so it turns over in place instead of sliding.
	_logo_rect.resized.connect(_center_logo_pivot)
	call_deferred("_center_logo_pivot")
	_build_letters()
	_content.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_start_flip_loop()


func _process(delta: float) -> void:
	if _leaving:
		return
	_t += delta
	_run_letter_glow(delta)
	match _phase:
		"in":
			_content.modulate = Color(1.0, 1.0, 1.0, clampf(_t / fade_in_time, 0.0, 1.0))
			if _t >= fade_in_time:
				_content.modulate = Color.WHITE
				_phase = "hold"
				_t = 0.0
		"hold":
			if _t >= hold_time:
				_phase = "out"
				_t = 0.0
		"out":
			_content.modulate = Color(1.0, 1.0, 1.0, 1.0 - clampf(_t / fade_out_time, 0.0, 1.0))
			if _t >= fade_out_time:
				_content.modulate = Color(1.0, 1.0, 1.0, 0.0)
				_go_next()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _phase == "out":
		return
	var pressed := false
	if event is InputEventKey:
		pressed = (event as InputEventKey).pressed
	elif event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventJoypadButton:
		pressed = (event as InputEventJoypadButton).pressed
	if pressed:
		# Skip straight into the fade-out.
		_phase = "out"
		_t = 0.0


func _build_letters() -> void:
	for child in _letters_box.get_children():
		child.queue_free()
	_letters.clear()
	for ch in title_text:
		var label := Label.new()
		label.text = ch
		label.add_theme_font_override("font", title_font)
		label.add_theme_font_size_override("font_size", title_font_size)
		label.add_theme_color_override("font_color", title_color)
		# Zero shadow offset turns the shadow into a soft halo (the "glow").
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		label.add_theme_constant_override("shadow_outline_size", 0)
		var c := glow_color
		c.a = 0.0
		label.add_theme_color_override("font_shadow_color", c)
		_letters_box.add_child(label)
		_letters.append(label)


## Travelling glow: a sine wave peaks on each letter in turn (offset by index),
## driving a soft halo behind that glyph so the shimmer sweeps left to right.
func _run_letter_glow(delta: float) -> void:
	_glow_t += delta
	for i in _letters.size():
		var phase := _glow_t * glow_speed - float(i) * glow_stagger
		var k := pow(maxf(sin(phase), 0.0), glow_sharpness)
		_letters[i].add_theme_constant_override(
			"shadow_outline_size", int(round(glow_max_size * k))
		)
		var c := glow_color
		c.a = k
		_letters[i].add_theme_color_override("font_shadow_color", c)


func _center_logo_pivot() -> void:
	_logo_rect.pivot_offset = _logo_rect.size * 0.5


## Looping card flip: scale.x 1 -> -1 crosses 0 (edge-on), reading as the logo
## turning over around its vertical axis, then pauses before the next flip.
func _start_flip_loop() -> void:
	var tween := create_tween().set_loops()
	(
		tween
		. tween_property(_logo_rect, "scale:x", -1.0, flip_half_duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		tween
		. tween_property(_logo_rect, "scale:x", 1.0, flip_half_duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	tween.tween_interval(flip_pause)


func _go_next() -> void:
	if _leaving or next_scene == null:
		return
	_leaving = true
	get_tree().change_scene_to_packed(next_scene)

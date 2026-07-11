extends Control
## Cinematic title intro: full-body portraits of the cast breathe and sway over a
## warm procedural junkshop backdrop, graded from cool monochrome to muted bronze,
## with a side-by-side group shot and a mix of fade / wipe / blur transitions.
## When the montage ends — or any key skips it — the picture fades to black and
## hands off to the title screen, which fades back up from black on its side, so
## the hand-off reads as one continuous fade into the menu.
##
## The whole sequence is data-driven: tune timing, framing, crops, light direction,
## idle motion, backdrop mood and transitions from the `shots` array in the
## inspector, or edit `_default_sequence()` below. No art is redesigned — portraits
## are only cropped, desaturated, shaded, tinted and gently animated.

const PORTRAIT_SHADER: Shader = preload("res://shader/title_intro_portrait.gdshader")
const POST_SHADER: Shader = preload("res://shader/title_intro_post.gdshader")
const WIPE_SHADER: Shader = preload("res://shader/title_intro_wipe.gdshader")
const BG_SHADER: Shader = preload("res://shader/title_intro_bg.gdshader")
const TITLE_FONT: Font = preload("res://assets/fonts/CloisterBlack.ttf")

## Fallback transitions (fade / wipe / blur) for sequence entries that don't set
## their own `"transition"` key. Every built-in entry sets one explicitly.
const DEFAULT_CUTS: Array[String] = ["fade", "ink", "blur", "shadow", "zoom"]
const DEFAULT_BG_MOOD := Color(1.0, 0.96, 0.88)

@export var next_scene: PackedScene = preload("res://scenes/ui/title_screen.tscn")

@export_group("Timing")
@export var fade_in_time: float = 1.6
@export var transition_time: float = 0.55

@export_group("Audio")
@export var ambience: AudioStream = preload("res://assets/audio/echoes/hum.wav")

@export_group("Look")
@export var vignette_strength: float = 0.6
@export var grain_amount: float = 0.03
## Bronze used for the character name captions.
@export var bronze_bright: Color = Color(0.95, 0.78, 0.42)
## When non-empty this overrides the built-in composed sequence.
@export var shots: Array[Dictionary] = []

@onready var _background: ColorRect = $Background
@onready var _stage: Node2D = $Stage
@onready var _overlays: CanvasLayer = $Overlays
@onready var _post: ColorRect = $Overlays/PostRect
@onready var _wipe: ColorRect = $Overlays/WipeRect
@onready var _fade: ColorRect = $Overlays/FadeRect

var _phase := "montage"
var _done := false


func _ready() -> void:
	_apply_post()
	_apply_wipe()
	_apply_background()
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	var dust := _make_dust()
	_overlays.add_child(dust)
	_overlays.move_child(dust, 0)  # above the stage, behind vignette/fade/title
	_start_music()
	if shots.is_empty():
		shots = _default_sequence()
	_set_bg_mood(shots[0].get("bg_mood", DEFAULT_BG_MOOD), 0.0)
	_play_sequence()


# --- Sequence -----------------------------------------------------------------


func _play_sequence() -> void:
	# Lift the opening blackness while dust is already drifting.
	await _fade_to(0.0, fade_in_time)
	for i in shots.size():
		if _phase != "montage":
			return
		var entry: Dictionary = shots[i]
		_set_bg_mood(entry.get("bg_mood", DEFAULT_BG_MOOD), transition_time + 1.0)
		if entry.get("lineup", false):
			await _show_lineup(entry)
		else:
			await _show_shot(entry, i)
		if _phase != "montage":
			return
		if i < shots.size() - 1:
			var cut := String(entry.get("transition", DEFAULT_CUTS[i % DEFAULT_CUTS.size()]))
			await _do_wipe(cut, transition_time)
	# Reached the end naturally (nobody skipped): fade out and hand off to the menu.
	if _phase != "montage":
		return
	_clear_stage()
	_leave_to_menu(transition_time)


func _show_shot(d: Dictionary, _index: int) -> void:
	var sprite := _make_portrait(d)
	_stage.add_child(sprite)
	var sweep := _make_sweep(d)
	_overlays.add_child(sweep)
	_overlays.move_child(sweep, _post.get_index())  # keep vignette above the sweep
	var name_label := _make_name_label(String(d.get("name", "")), Rect2(360.0, 992.0, 1200.0, 72.0))
	_stage.add_child(name_label)

	var reveal: float = d.get("reveal", 1.4)
	var hold: float = d.get("hold", 2.6)
	var lit_peak: float = d.get("lit_peak", 1.0)
	var base_pos: Vector2 = d["center"]
	var start_off: Vector2 = d.get("offset_start", Vector2.ZERO)
	var end_off: Vector2 = d.get("offset_end", Vector2.ZERO)
	var base_scale: float = d["scale"]
	var push: float = d.get("push", 0.03)
	var end_pos: Vector2 = base_pos + end_off
	var end_scale: float = base_scale * (1.0 + push)

	sprite.position = base_pos + start_off
	sprite.scale = Vector2(base_scale, base_scale)
	sprite.modulate.a = 0.0
	sprite.material.set_shader_parameter("lit", 0.05)

	var band_w: float = 520.0
	var from_x: float = -band_w
	var to_x: float = 1920.0 + band_w
	if d.get("sweep_from_right", false):
		from_x = 1920.0 + band_w
		to_x = -band_w
	sweep.position = Vector2(from_x, 0.0)

	# Entrance: fade the plate up, push in, and sweep the rim light once.
	var t := create_tween().set_parallel(true)
	t.tween_property(sprite, "modulate:a", 1.0, reveal).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)
	(
		t
		. tween_method(_set_lit.bind(sprite), 0.05, lit_peak, reveal)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	t.tween_property(sprite, "position", end_pos, reveal).set_trans(Tween.TRANS_SINE)
	t.tween_property(sprite, "scale", Vector2(end_scale, end_scale), reveal).set_trans(
		Tween.TRANS_SINE
	)
	t.tween_property(sweep, "position:x", to_x, reveal * 1.15).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	t.tween_property(sweep, "modulate:a", 0.0, reveal * 0.6).set_ease(Tween.EASE_IN)
	(
		t
		. tween_property(name_label, "modulate:a", 1.0, reveal * 0.9)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)

	await get_tree().create_timer(reveal).timeout
	if _phase != "montage":
		return
	# Hold: keep the still alive with a looping idle (breath + sway), bound to the
	# sprite so it dies automatically when the wipe clears the stage.
	_start_idle(sprite, end_scale, end_pos, d.get("breathe", 1.0), d.get("sway", 1.0))
	await get_tree().create_timer(hold).timeout
	# The sprite + sweep stay in place; the wipe covers them and _clear_stage()
	# frees them at the fully-covered midpoint so each cut flows over the image.


## Side-by-side group shot: lays out N half-body portraits left-to-right on the
## shared backdrop, staggers their reveal, then lets them idle together for the
## hold. The whole group then leaves through one shared transition.
func _show_lineup(entry: Dictionary) -> void:
	var members: Array = entry.get("members", [])
	var n: int = members.size()
	if n == 0:
		return
	var reveal: float = entry.get("reveal", 1.6)
	var hold: float = entry.get("hold", 3.2)
	var stagger: float = entry.get("stagger", 0.22)
	var xs := _lineup_xs(n)
	for j in n:
		_reveal_lineup_member(members[j], xs[j], reveal, j * stagger)
	# Cover the slowest member (last one) finishing its entrance, then the hold.
	await get_tree().create_timer(reveal + (n - 1) * stagger + hold).timeout


func _reveal_lineup_member(m: Dictionary, x: float, reveal: float, delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if _phase != "montage":
		return
	var sprite := _make_portrait(m)
	_stage.add_child(sprite)
	var base_pos := Vector2(x, m.get("cy", 560.0))
	var base_scale: float = m.get("scale", 0.5)
	var end_scale: float = base_scale * (1.0 + m.get("push", 0.02))
	sprite.position = base_pos + Vector2(0.0, 24.0)  # gentle rise-in
	sprite.scale = Vector2(base_scale, base_scale)
	sprite.modulate.a = 0.0
	sprite.material.set_shader_parameter("lit", 0.05)
	var t := create_tween().set_parallel(true)
	t.tween_property(sprite, "modulate:a", 1.0, reveal).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)
	t.tween_property(sprite, "position", base_pos, reveal).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)
	(
		t
		. tween_property(sprite, "scale", Vector2(end_scale, end_scale), reveal)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	(
		t
		. tween_method(_set_lit.bind(sprite), 0.05, m.get("lit_peak", 0.9), reveal)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	# Names sit on a shared baseline near the bottom edge so they never cover a
	# portrait's body (the lineup members have different heights).
	var name_label := _make_name_label(
		String(m.get("name", "")), Rect2(x - 240.0, 992.0, 480.0, 60.0)
	)
	_stage.add_child(name_label)
	t.tween_property(name_label, "modulate:a", 1.0, reveal).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)
	await get_tree().create_timer(reveal).timeout
	if _phase != "montage":
		return
	_start_idle(sprite, end_scale, base_pos, m.get("breathe", 1.0), m.get("sway", 1.0))


## Evenly spaced x anchors for a lineup of `n` portraits across the 1920 width.
func _lineup_xs(n: int) -> Array[float]:
	var xs: Array[float] = []
	var step: float = 1920.0 / float(n + 1)
	for i in n:
		xs.append(step * float(i + 1))
	return xs


func _clear_stage() -> void:
	for child in _stage.get_children():
		child.queue_free()
	for child in _overlays.get_children():
		if child.name == "IntroSweep":
			child.queue_free()


# --- Shot building -------------------------------------------------------------


func _make_portrait(d: Dictionary) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = true
	var at := AtlasTexture.new()
	at.atlas = d["texture"]
	at.region = d["region"]
	sprite.texture = at
	var sm := ShaderMaterial.new()
	sm.shader = PORTRAIT_SHADER
	sm.set_shader_parameter("contrast", d.get("contrast", 1.12))
	sm.set_shader_parameter("brightness", d.get("brightness", -0.02))
	sm.set_shader_parameter("light_dir", d.get("light_dir", 0))
	sm.set_shader_parameter("shadow_strength", d.get("shadow_strength", 0.55))
	sm.set_shader_parameter("shadow_softness", d.get("shadow_softness", 0.55))
	sm.set_shader_parameter("tint", d.get("tint", Color(1.0, 1.0, 1.0)))
	sm.set_shader_parameter("tint_strength", d.get("tint_strength", 0.0))
	sm.set_shader_parameter("light_color", d.get("light_color", Color(1.0, 1.0, 1.0)))
	sm.set_shader_parameter("light_strength", d.get("light_strength", 0.0))
	sprite.material = sm
	return sprite


func _make_sweep(d: Dictionary) -> TextureRect:
	var band_w: float = 520.0
	var rect := TextureRect.new()
	rect.name = "IntroSweep"
	rect.texture = _sweep_texture(int(band_w))
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = Vector2(band_w, 1080.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	rect.material = mat
	var c: Color = d.get("sweep_color", Color(1.0, 0.94, 0.82))
	rect.modulate = Color(c.r, c.g, c.b, 0.0)
	return rect


func _set_lit(v: float, sprite: Sprite2D) -> void:
	if is_instance_valid(sprite) and sprite.material != null:
		sprite.material.set_shader_parameter("lit", v)


## Bronze name caption for a portrait. Lives in _stage so the between-shot wipe
## frees it with the sprite. `box` is the centered layout box (px) it aligns in.
func _make_name_label(text: String, box: Rect2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", TITLE_FONT)
	l.add_theme_font_size_override("font_size", int(box.size.y * 0.62))
	l.add_theme_color_override("font_color", bronze_bright)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 14)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = box.position
	l.size = box.size
	l.modulate.a = 0.0
	return l


## Fake-life idle for a still drawing: a slow breathing scale pulse, a gentle
## horizontal sway and a sub-degree rotation, all looping and bound to the sprite
## (so they stop the instant the sprite is freed). `breathe`/`sway` scale the
## motion per shot so e.g. Auntie stays near-still while others move a touch more.
func _start_idle(
	sprite: Sprite2D, base_scale: float, base_pos: Vector2, breathe: float, sway: float
) -> void:
	var amp: float = 0.012 * breathe
	var breath := create_tween().set_loops().bind_node(sprite)
	(
		breath
		. tween_property(
			sprite, "scale", Vector2(base_scale * (1.0 + amp), base_scale * (1.0 + amp)), 1.5
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		breath
		. tween_property(
			sprite,
			"scale",
			Vector2(base_scale * (1.0 - amp * 0.4), base_scale * (1.0 - amp * 0.4)),
			1.5
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	var sx: float = 4.0 * sway
	var sway_t := create_tween().set_loops().bind_node(sprite)
	(
		sway_t
		. tween_property(sprite, "position:x", base_pos.x + sx, 2.2)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		sway_t
		. tween_property(sprite, "position:x", base_pos.x - sx, 2.2)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	var rot: float = deg_to_rad(0.25) * sway
	var rot_t := create_tween().set_loops().bind_node(sprite)
	rot_t.tween_property(sprite, "rotation", rot, 2.6).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	rot_t.tween_property(sprite, "rotation", -rot, 2.6).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)


# --- Look & title --------------------------------------------------------------


func _apply_post() -> void:
	var sm := ShaderMaterial.new()
	sm.shader = POST_SHADER
	sm.set_shader_parameter("vignette_strength", vignette_strength)
	sm.set_shader_parameter("grain_amount", grain_amount)
	_post.material = sm
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_wipe() -> void:
	var sm := ShaderMaterial.new()
	sm.shader = WIPE_SHADER
	sm.set_shader_parameter("progress", 0.0)
	sm.set_shader_parameter("wipe_color", Color(0.0, 0.0, 0.0, 1.0))
	sm.set_shader_parameter("soft", 0.12)
	sm.set_shader_parameter("seed", 0.0)
	_wipe.material = sm
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.visible = false


func _apply_background() -> void:
	var sm := ShaderMaterial.new()
	sm.shader = BG_SHADER
	sm.set_shader_parameter("mood", DEFAULT_BG_MOOD)
	sm.set_shader_parameter("intensity", 0.9)
	sm.set_shader_parameter("dust_amount", 0.5)
	_background.material = sm
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Cross-fade the backdrop mood tint toward `c` over `dur` (0 = snap).
func _set_bg_mood(c: Color, dur: float) -> void:
	if not is_instance_valid(_background) or _background.material == null:
		return
	var mat := _background.material as ShaderMaterial
	if dur <= 0.0:
		mat.set_shader_parameter("mood", c)
		return
	var from: Color = mat.get_shader_parameter("mood")
	var t := create_tween()
	(
		t
		. tween_method(func(v: Color) -> void: mat.set_shader_parameter("mood", v), from, c, dur)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)


# --- Transitions & flow --------------------------------------------------------


func _fade_to(a: float, dur: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", a, dur).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	await t.finished


## Stylized between-shot transition. Sweeps the chosen wipe to full cover (black),
## swaps the stage at the covered midpoint, then sweeps back out. Every cut passes
## through black so no two shots ever need to be composited.
func _do_wipe(cut: String, dur: float) -> void:
	var p := _wipe_params(cut)
	var mat := _wipe.material as ShaderMaterial
	mat.set_shader_parameter("wipe_type", p["type"])
	mat.set_shader_parameter("angle", p["angle"])
	mat.set_shader_parameter("wipe_color", p["color"])
	mat.set_shader_parameter("seed", randf() * 100.0)
	_set_wipe_progress(0.0)
	_wipe.visible = true
	var half := dur * 0.5
	var t1 := create_tween()
	t1.tween_method(_set_wipe_progress, 0.0, 0.5, half).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN
	)
	await t1.finished
	if _phase != "montage":
		return
	_clear_stage()
	var t2 := create_tween()
	t2.tween_method(_set_wipe_progress, 0.5, 1.0, half).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)
	await t2.finished
	_set_wipe_progress(0.0)
	_wipe.visible = false


func _set_wipe_progress(v: float) -> void:
	if is_instance_valid(_wipe) and _wipe.material != null:
		(_wipe.material as ShaderMaterial).set_shader_parameter("progress", v)


func _wipe_params(cut: String) -> Dictionary:
	match cut:
		"fade":
			return {"type": 0, "angle": 0.0, "color": Color(0.0, 0.0, 0.0, 1.0)}
		"blur":
			return {"type": 8, "angle": 0.0, "color": Color(0.0, 0.0, 0.0, 1.0)}
		"light_sweep":
			return {"type": 1, "angle": 0.0, "color": Color(1.0, 0.92, 0.78, 1.0)}
		"ink":
			return {"type": 2, "angle": 0.0, "color": Color(0.0, 0.0, 0.0, 1.0)}
		"smoke":
			return {"type": 3, "angle": -0.25, "color": Color(0.05, 0.05, 0.06, 1.0)}
		"shadow":
			return {"type": 4, "angle": 0.0, "color": Color(0.0, 0.0, 0.0, 1.0)}
		"whip":
			return {"type": 5, "angle": 0.0, "color": Color(0.0, 0.0, 0.0, 1.0)}
		"zoom":
			return {"type": 6, "angle": 0.0, "color": Color(0.0, 0.0, 0.0, 1.0)}
		"particle":
			return {"type": 7, "angle": 0.0, "color": Color(0.0, 0.0, 0.0, 1.0)}
		_:
			return {"type": 0, "angle": 0.0, "color": Color(0.0, 0.0, 0.0, 1.0)}


## Mouse click, key, or gamepad button all act as "continue": any press during the
## montage skips it and fades straight into the title screen.
func _unhandled_input(event: InputEvent) -> void:
	if _done or not _pressed(event):
		return
	get_viewport().set_input_as_handled()
	_skip()


func _pressed(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false


## Skips the remaining montage and fades straight into the title screen.
func _skip() -> void:
	if _phase != "montage":
		return
	_clear_stage()
	_leave_to_menu()


## Fades the intro picture to black, then hands off to the title screen — which
## fades back up from black on its side, so the hand-off reads as one continuous
## fade into the menu rather than a hard scene cut.
func _leave_to_menu(fade_dur: float = 0.35) -> void:
	if _done:
		return
	_done = true
	_phase = "leaving"
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, fade_dur).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	await t.finished
	_change_scene()


func _change_scene() -> void:
	if next_scene != null:
		get_tree().change_scene_to_packed(next_scene)


# --- Texture helpers -----------------------------------------------------------


func _sweep_texture(w: int) -> GradientTexture2D:
	var gt := GradientTexture2D.new()
	gt.width = w
	gt.height = 4
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0.0, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 0.95, 0.86, 1), Color(1, 1, 1, 0)])
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gt.gradient = grad
	return gt


func _soft_dot() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 7.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _make_dust() -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = 28
	p.lifetime = 9.0
	p.emitting = true
	p.position = Vector2(960.0, 540.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(960.0, 540.0, 1.0)
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 25.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3(0.0, -4.0, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	pm.color = Color(1.0, 0.9, 0.72, 0.16)
	p.process_material = pm
	p.texture = _soft_dot()
	return p


func _start_music() -> void:
	# bgm_1 is the opening/intro theme; the menu crossfades to bgm_3 on the title card.
	MusicService.play_track("bgm_1")


# --- Composed sequence ---------------------------------------------------------
# Source portraits are 2500x4000, full body on transparent BG. Every entry shows
# the full body (region = the whole image) with a light direction, a backdrop
# mood and a gentle idle. A `"lineup"` entry places several full-body portraits
# side-by-side for a group shot. Source-safe: only crop + grade + shade + tint +
# a tiny idle loop, no redraw.


func _default_sequence() -> Array[Dictionary]:
	# Full-body framing of the 2500x4000 portraits (region = the whole image, scale
	# fits the height on screen). Stills only get grade + shade + tint + a tiny idle
	# loop; no redraw. Nudge an entry's scale/center to reframe it.
	var buyer := {
		"name": "Mr. Maverick",
		"texture": preload("res://assets/Characters/Mysterious Buyer.png"),
		"region": Rect2(0, 0, 2500, 4000),
		"scale": 0.25,
		"center": Vector2(960, 540),
		"push": 0.02,
		"light_dir": 2,  # top light only catches the tie + jaw
		"shadow_strength": 0.84,
		"hold": 2.6,
		"reveal": 1.7,
		"transition": "fade",
		"breathe": 0.6,
		"sway": 0.5,
		"bg_mood": Color(0.78, 0.84, 0.95),
		"tint": Color(0.78, 0.82, 0.90),
		"tint_strength": 0.05,
		"light_color": Color(0.70, 0.80, 1.00),
		"light_strength": 0.12,
	}
	var scavenger := {
		"name": "Ayla",
		"texture": preload("res://assets/Characters/Scavenger.png"),
		"region": Rect2(0, 0, 2500, 4000),  # full body, same framing as Auntie Shine & Lave
		"scale": 0.22,  # matches the trio so all three full bodies line up at cy
		"cy": 560.0,  # shared with Auntie Shine & Lave so the trio lines up horizontally
		"push": 0.02,
		"light_dir": 0,
		"shadow_strength": 0.22,
		"breathe": 1.0,
		"sway": 1.0,
		"tint": Color(0.96, 0.88, 0.72),
		"tint_strength": 0.18,
		"light_color": Color(1.00, 0.92, 0.74),
		"light_strength": 0.20,
	}
	var auntie := {
		"name": "Auntie Shine",
		"texture": preload("res://assets/Characters/Auntie.png"),
		"region": Rect2(0, 0, 2500, 4000),
		"scale": 0.22,
		"cy": 560.0,
		"push": 0.0,
		"light_dir": 0,
		"shadow_strength": 0.12,
		"breathe": 0.3,
		"sway": 0.4,  # near-still: stillness reads as warmth
		"tint": Color(0.92, 0.84, 0.70),
		"tint_strength": 0.28,
		"light_color": Color(1.00, 0.90, 0.72),
		"light_strength": 0.24,
	}
	var artisan := {
		"name": "Lave",
		"texture": preload("res://assets/Characters/Artisan.png"),
		"region": Rect2(0, 0, 2500, 4000),
		"scale": 0.22,
		"cy": 560.0,
		"push": 0.02,
		"light_dir": 1,
		"shadow_strength": 0.6,
		"breathe": 1.1,
		"sway": 1.1,
		"tint": Color(0.92, 0.74, 0.42),
		"tint_strength": 0.38,
		"light_color": Color(1.00, 0.78, 0.40),
		"light_strength": 0.32,
	}
	var uncle := {
		"name": "Tito Yuyu",
		"texture": preload("res://assets/Characters/Uncle.png"),
		"region": Rect2(0, 0, 2500, 4000),
		"scale": 0.25,
		"center": Vector2(960, 540),
		"push": 0.03,
		"light_dir": 2,
		"shadow_strength": 0.5,
		"hold": 2.8,
		"reveal": 1.5,
		"transition": "blur",
		"breathe": 0.7,
		"sway": 0.6,
		"bg_mood": Color(0.74, 0.82, 0.95),
		"tint": Color(0.70, 0.78, 0.86),
		"tint_strength": 0.42,
		"light_color": Color(0.78, 0.86, 1.00),
		"light_strength": 0.36,
	}
	var archeologist := {
		"name": "Sam",
		"texture": preload("res://assets/Characters/Archeologist.png"),
		"region": Rect2(0, 0, 2500, 4000),
		"scale": 0.25,
		"center": Vector2(960, 540),
		"push": 0.05,
		"light_dir": 0,
		"shadow_strength": 0.68,
		"sweep_from_right": true,
		"hold": 3.4,
		"reveal": 1.8,
		"breathe": 0.8,
		"sway": 0.7,
		"bg_mood": Color(1.05, 0.82, 0.50),
		"tint": Color(0.90, 0.66, 0.40),
		"tint_strength": 0.52,
		"light_color": Color(1.00, 0.72, 0.40),
		"light_strength": 0.46,
	}
	# The warm found-family trio share one screen side-by-side.
	var family := {
		"lineup": true,
		"members": [scavenger, auntie, artisan],
		"reveal": 1.6,
		"hold": 3.2,
		"stagger": 0.22,
		"transition": "ink",
		"bg_mood": Color(1.05, 0.92, 0.72),
	}
	return [buyer, family, uncle, archeologist]

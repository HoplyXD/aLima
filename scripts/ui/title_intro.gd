extends Control
## Cinematic title intro: a slow, monochrome, high-contrast character montage that
## fades in from black, reveals the cast one at a time (each with a distinct,
## composed "camera" framing and a sweeping rim light), then lands on a bronze
## medieval title with a pulsing "Press Any Key". Any input skips to the menu.
##
## The whole sequence is data-driven: tune timing, framing, crops, light direction
## and transitions per character from the `shots` array in the inspector, or edit
## `_default_shots()` below. No art is redesigned — portraits are only desaturated,
## shaded, cropped and re-framed.

const PORTRAIT_SHADER: Shader = preload("res://shader/title_intro_portrait.gdshader")
const POST_SHADER: Shader = preload("res://shader/title_intro_post.gdshader")
const TITLE_FONT: Font = preload("res://assets/fonts/CloisterBlack.ttf")

@export var next_scene: PackedScene = preload("res://scenes/ui/title_screen.tscn")

@export_group("Timing")
@export var fade_in_time: float = 1.6
@export var transition_time: float = 0.55
@export var wind_beat: float = 0.9
@export var title_reveal_time: float = 1.6

@export_group("Title")
@export var title_text: String = "aLima"
@export var subtitle_text: String = "Press Any Key"
@export var title_font_size: int = 220
@export var subtitle_font_size: int = 38
@export var bronze: Color = Color(0.74, 0.55, 0.27)
@export var bronze_bright: Color = Color(0.95, 0.78, 0.42)

@export_group("Audio")
@export var music: AudioStream
@export var ambience: AudioStream = preload("res://assets/audio/echoes/hum.wav")
@export var wind_sfx: AudioStream
@export var music_volume_db: float = -10.0

@export_group("Look")
@export var vignette_strength: float = 0.6
@export var grain_amount: float = 0.03
## When non-empty this overrides the built-in composed sequence.
@export var shots: Array[Dictionary] = []

@onready var _stage: Node2D = $Stage
@onready var _overlays: CanvasLayer = $Overlays
@onready var _post: ColorRect = $Overlays/PostRect
@onready var _fade: ColorRect = $Overlays/FadeRect
@onready var _title_layer: Control = $Overlays/TitleLayer
@onready var _title_glow: TextureRect = $Overlays/TitleLayer/TitleGlow
@onready var _title_label: Label = $Overlays/TitleLayer/TitleLabel
@onready var _subtitle_label: Label = $Overlays/TitleLayer/SubtitleLabel
@onready var _music: AudioStreamPlayer = $Music
@onready var _wind: AudioStreamPlayer = $Wind

var _phase := "montage"
var _done := false


func _ready() -> void:
	_apply_post()
	_apply_title_style()
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_title_layer.visible = false
	_title_label.modulate.a = 0.0
	_subtitle_label.modulate.a = 0.0
	_title_glow.modulate.a = 0.0
	var dust := _make_dust()
	_overlays.add_child(dust)
	_overlays.move_child(dust, 0) # above the stage, behind vignette/fade/title
	_start_music()
	if shots.is_empty():
		shots = _default_shots()
	_play_sequence()


# --- Sequence -----------------------------------------------------------------


func _play_sequence() -> void:
	# Lift the opening blackness while dust is already drifting.
	await _fade_to(0.0, fade_in_time)
	for i in shots.size():
		if _done:
			return
		await _show_shot(shots[i], i)
		if _done:
			return
		await _fade_to(1.0, transition_time)
	_clear_stage()
	await _reveal_title()


func _show_shot(d: Dictionary, index: int) -> void:
	var sprite := _make_portrait(d)
	_stage.add_child(sprite)
	var sweep := _make_sweep(d)
	_overlays.add_child(sweep)
	_overlays.move_child(sweep, _post.get_index()) # keep vignette above the sweep

	var reveal: float = d.get("reveal", 1.4)
	var hold: float = d.get("hold", 2.6)
	var lit_peak: float = d.get("lit_peak", 1.0)
	var base_pos: Vector2 = d["center"]
	var start_off: Vector2 = d.get("offset_start", Vector2.ZERO)
	var end_off: Vector2 = d.get("offset_end", Vector2.ZERO)
	var base_scale: float = d["scale"]
	var push: float = d.get("push", 0.03)
	var total: float = reveal + hold

	sprite.position = base_pos + start_off
	sprite.scale = Vector2(base_scale, base_scale)
	sprite.modulate.a = 0.0
	sprite.material.set_shader_parameter("lit", 0.05)

	# Shots after the first emerge from the black gap left by the previous fade.
	if index > 0:
		var open := create_tween()
		open.tween_property(_fade, "color:a", 0.0, minf(reveal, 0.6)).set_trans(Tween.TRANS_SINE)

	var band_w: float = 520.0
	var from_x: float = -band_w
	var to_x: float = 1920.0 + band_w
	if d.get("sweep_from_right", false):
		from_x = 1920.0 + band_w
		to_x = -band_w
	sweep.position = Vector2(from_x, 0.0)

	var t := create_tween().set_parallel(true)
	t.tween_property(sprite, "modulate:a", 1.0, reveal).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_lit.bind(sprite), 0.05, lit_peak, reveal).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "position", base_pos + end_off, total).set_trans(Tween.TRANS_SINE)
	t.tween_property(sprite, "scale", Vector2(base_scale * (1.0 + push), base_scale * (1.0 + push)), total).set_trans(Tween.TRANS_SINE)
	t.tween_property(sweep, "position:x", to_x, reveal * 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(sweep, "modulate:a", 0.0, reveal * 0.6).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(total).timeout
	sprite.queue_free()
	sweep.queue_free()


func _clear_stage() -> void:
	for child in _stage.get_children():
		child.queue_free()


func _reveal_title() -> void:
	if _done:
		return
	_phase = "title"
	_title_layer.visible = true
	if wind_sfx != null:
		_wind.stream = wind_sfx
		_wind.play()
	await get_tree().create_timer(wind_beat).timeout
	if _done:
		return
	# Lift the darkness and bring the bronze title up out of it.
	var t := create_tween().set_parallel(true)
	t.tween_property(_fade, "color:a", 0.0, title_reveal_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_title_label, "modulate:a", 1.0, title_reveal_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_title_glow, "modulate:a", 0.75, title_reveal_time * 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(title_reveal_time).timeout
	if _done:
		return
	_start_subtitle_pulse()
	_start_glow_breathe()


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
	sprite.material = sm
	return sprite


func _make_sweep(d: Dictionary) -> TextureRect:
	var band_w: float = 520.0
	var rect := TextureRect.new()
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


# --- Look & title --------------------------------------------------------------


func _apply_post() -> void:
	var sm := ShaderMaterial.new()
	sm.shader = POST_SHADER
	sm.set_shader_parameter("vignette_strength", vignette_strength)
	sm.set_shader_parameter("grain_amount", grain_amount)
	_post.material = sm
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_title_style() -> void:
	_title_label.text = title_text
	_title_label.add_theme_font_override("font", TITLE_FONT)
	_title_label.add_theme_font_size_override("font_size", title_font_size)
	_title_label.add_theme_color_override("font_color", bronze)
	_title_label.add_theme_constant_override("shadow_offset_x", 0)
	_title_label.add_theme_constant_override("shadow_offset_y", 0)
	_title_label.add_theme_constant_override("shadow_outline_size", 26)
	_title_label.add_theme_color_override("font_shadow_color", Color(bronze_bright.r, bronze_bright.g, bronze_bright.b, 0.55))

	_subtitle_label.text = subtitle_text
	_subtitle_label.add_theme_font_override("font", TITLE_FONT)
	_subtitle_label.add_theme_font_size_override("font_size", subtitle_font_size)
	_subtitle_label.add_theme_color_override("font_color", Color(bronze.r, bronze.g, bronze.b, 0.85))

	_title_glow.texture = _radial_texture(900, 460)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_title_glow.material = mat
	_title_glow.modulate = Color(bronze_bright.r, bronze_bright.g, bronze_bright.b, 0.0)


func _start_subtitle_pulse() -> void:
	var t := create_tween().set_loops()
	t.tween_property(_subtitle_label, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_subtitle_label, "modulate:a", 0.35, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_glow_breathe() -> void:
	var t := create_tween().set_loops()
	t.tween_property(_title_glow, "modulate:a", 0.55, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_title_glow, "modulate:a", 0.75, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- Transitions & flow --------------------------------------------------------


func _fade_to(a: float, dur: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", a, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _unhandled_input(event: InputEvent) -> void:
	if _done or not _pressed(event):
		return
	if _phase == "title":
		_done = true
		_change_scene()
	else:
		_skip()


func _pressed(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed
	elif event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	elif event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false


func _skip() -> void:
	if _done:
		return
	_done = true
	var t := create_tween().set_parallel(true)
	t.tween_property(_fade, "color:a", 1.0, 0.35)
	if _music.playing:
		t.tween_property(_music, "volume_db", -40.0, 0.35)
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


func _radial_texture(w: int, h: int) -> GradientTexture2D:
	var gt := GradientTexture2D.new()
	gt.width = w
	gt.height = h
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
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
	var stream: AudioStream = music if music != null else ambience
	if stream == null:
		return
	_music.stream = stream
	_music.volume_db = music_volume_db
	_music.play()
	_music.finished.connect(func() -> void:
		if not _done:
			_music.play()
	)


# --- Composed sequence ---------------------------------------------------------
# Source portraits are 2500x4000, full body on transparent BG. Each entry crops a
# tight "camera" region, picks a light direction, and sets its own slow motion so
# every reveal feels distinct. Source-safe: only crop + grade + shade, no redraw.


func _default_shots() -> Array[Dictionary]:
	return [
		{
			"name": "Mysterious Buyer",
			"texture": preload("res://assets/Characters/Mysterious Buyer.png"),
			# Hooded head + gold tie, face withheld in the hood's black void.
			"region": Rect2(600, 520, 1300, 1500),
			"scale": 0.62,
			"center": Vector2(960, 480),
			"push": 0.02,
			"light_dir": 2, # top light only catches tie + jaw
			"shadow_strength": 0.84,
			"hold": 2.7,
			"reveal": 1.7,
		},
		{
			"name": "Scavenger",
			"texture": preload("res://assets/Characters/Scavenger.png"),
			# Child: big eyes + nose band-aid, soft even front light, gentle.
			"region": Rect2(720, 800, 1000, 1080),
			"scale": 0.66,
			"center": Vector2(960, 500),
			"push": 0.03,
			"light_dir": 0,
			"shadow_strength": 0.22,
			"hold": 2.6,
			"reveal": 1.3,
		},
		{
			"name": "Auntie",
			"texture": preload("res://assets/Characters/Auntie.png"),
			# Pure ink line-art, warm smile. Near-still: stillness reads as warmth.
			"region": Rect2(780, 540, 820, 900),
			"scale": 0.84,
			"center": Vector2(960, 500),
			"push": 0.0,
			"light_dir": 0,
			"shadow_strength": 0.12,
			"hold": 2.6,
			"reveal": 1.4,
		},
		{
			"name": "Artisan",
			"texture": preload("res://assets/Characters/Artisan.png"),
			# Side light: pan from the raised hammer (right) to the eyes (left).
			"region": Rect2(680, 540, 1680, 1180),
			"scale": 0.74,
			"center": Vector2(960, 500),
			"offset_start": Vector2(80, 0),
			"offset_end": Vector2(-30, 0),
			"push": 0.02,
			"light_dir": 1, # lit from the left, hammer side falls to shadow
			"shadow_strength": 0.6,
			"hold": 2.8,
			"reveal": 1.5,
		},
		{
			"name": "Uncle",
			"texture": preload("res://assets/Characters/Uncle.png"),
			# Grizzled veteran: top light rakes the white hair + scar, low-angle feel.
			"region": Rect2(720, 40, 1080, 1500),
			"scale": 0.63,
			"center": Vector2(960, 470),
			"push": 0.04,
			"light_dir": 2,
			"shadow_strength": 0.5,
			"hold": 2.8,
			"reveal": 1.5,
		},
		{
			"name": "Archeologist",
			"texture": preload("res://assets/Characters/Archeologist.png"),
			# Hero beat: rim from the right reveals one eye under the brim, then the gaze.
			"region": Rect2(720, 600, 1100, 760),
			"scale": 1.0,
			"center": Vector2(960, 500),
			"push": 0.05,
			"light_dir": 0,
			"shadow_strength": 0.68,
			"sweep_from_right": true,
			"hold": 3.4,
			"reveal": 1.8,
		},
	]

class_name DrawableTextureSpike
extends Control
## De-risk spike for the DrawableTexture2D-based cleaning (Godot 4.7 experimental API).
##
## Proves, in isolation from the restoration core, that:
##   1. DrawableTexture2D.setup() + blit_rect() render and live-update on THIS renderer
##      (project is Mobile on desktop / Compatibility on web).
##   2. The "paint the clean surface back" erase model works with the DEFAULT blend_mix
##      (material = null) so we never touch the renderer-inconsistent blend_sub/blend_mul
##      (godot issue #29105). The drawable texture is the artifact albedo: it starts grimy,
##      and dragging a soft round brush blits clean texels back over the grime.
##   3. Per-tool clean radius is just the brush stamp size (keys 1/2/3).
##
## This is a spike: it holds no game state, never touches RestorationService/SaveService,
## and is not wired into the bench. Run it with:
##   & $godot --path . scenes/restoration/spikes/drawable_texture_spike.tscn
## Left-drag to clean. Keys 1/2/3 = small/medium/large tool radius. R = re-grime.

const TEX_SIZE: int = 512  ## Drawable albedo resolution (crisp; GPU-side so cheap).
const GRIME_COLOR := Color(0.18, 0.15, 0.09)
const CLEAN_COLOR := Color(0.83, 0.80, 0.55)
## Three "tool" radii in texels, selectable 1/2/3 — stand-in for per-tool clean_radius.
const RADII: Array[int] = [28, 56, 96]

var _drawable: DrawableTexture2D
var _clean_brush: ImageTexture  ## RGB = clean colour, ALPHA = soft radial falloff.
var _grime_full: ImageTexture  ## Full-surface grime with splotchy alpha.
var _radius: int = RADII[1]
var _view: TextureRect
var _status: Label
var _painting: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_drawable = DrawableTexture2D.new()
	_drawable.setup(
		TEX_SIZE, TEX_SIZE, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, CLEAN_COLOR, false
	)
	_clean_brush = _make_soft_brush(CLEAN_COLOR)
	_grime_full = _make_grime()
	_apply_grime()

	_view = TextureRect.new()
	_view.texture = _drawable
	_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)

	_status = Label.new()
	_status.position = Vector2(16, 12)
	_status.add_theme_font_size_override("font_size", 18)
	add_child(_status)
	_refresh_status()


func _refresh_status() -> void:
	_status.text = (
		"DrawableTexture2D spike — left-drag to clean | 1/2/3 radius | R re-grime\n"
		+ "renderer: %s   tool radius: %d px" % [_renderer_name(), _radius]
	)


func _renderer_name() -> String:
	# Diagnostic only: which pipeline this run is using (Mobile/Compat/Forward+).
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"))


# --- Grime / brush sources ---------------------------------------------------


## Re-lays the full grime coating over the clean base (blend_mix, opaque-ish via the
## grime alpha) so the surface starts dirty.
func _apply_grime() -> void:
	_drawable.blit_rect(
		Rect2i(0, 0, TEX_SIZE, TEX_SIZE), _grime_full, Color.WHITE, 0, null
	)


## A soft round brush whose RGB is the clean surface colour and whose alpha falls off
## radially (1 at centre → 0 at the edge). Blitting it with the DEFAULT blend_mix does
## out = mix(grime, clean, alpha), i.e. a soft circular reveal — no blend_sub needed.
func _make_soft_brush(color: Color) -> ImageTexture:
	var size := RADII[RADII.size() - 1] * 2  # big enough for the largest radius
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (size * 0.5)
			var a := clampf(1.0 - smoothstep(0.6, 1.0, d), 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(img)


## Splotchy full-surface grime: value-noise alpha so the clean base shows through in
## patches (so cleaning visibly changes coverage rather than a flat repaint).
func _make_grime() -> ImageTexture:
	var img := Image.create_empty(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var n := _noise(x * 0.06, y * 0.06) * 0.6 + _noise(x * 0.18, y * 0.18) * 0.4
			var a := clampf(0.55 + n * 0.6, 0.0, 1.0)
			img.set_pixel(x, y, Color(GRIME_COLOR.r, GRIME_COLOR.g, GRIME_COLOR.b, a))
	return ImageTexture.create_from_image(img)


func _noise(x: float, y: float) -> float:
	var n := sin(x * 12.9898 + y * 78.233) * 43758.5453
	return n - floor(n)


# --- Input -------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_painting = event.pressed
		if _painting:
			_clean_at(event.position)
	elif event is InputEventMouseMotion and _painting:
		_clean_at(event.position)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			_radius = RADII[0]
		KEY_2:
			_radius = RADII[1]
		KEY_3:
			_radius = RADII[2]
		KEY_R:
			_apply_grime()
	_refresh_status()


## Maps a click in the TextureRect to drawable texel space and blits one clean stamp of
## the current tool radius — the heart of the cleaning interaction.
func _clean_at(local_pos: Vector2) -> void:
	var uv := _view_uv(local_pos)
	if uv.x < 0.0:
		return  # outside the displayed texture
	var cx := int(uv.x * TEX_SIZE)
	var cy := int(uv.y * TEX_SIZE)
	var r := _radius
	# blit_rect copies the WHOLE source into the dest rect, so size the dest rect to the
	# tool radius and let blit scale the soft brush down into it.
	var rect := Rect2i(cx - r, cy - r, r * 2, r * 2)
	_drawable.blit_rect(rect, _clean_brush, Color.WHITE, 0, null)


## Converts a position inside this Control to UV (0..1) on the displayed drawable,
## accounting for STRETCH_KEEP_ASPECT_CENTERED letterboxing. Returns (-1,-1) if outside.
func _view_uv(pos: Vector2) -> Vector2:
	var rect_size := _view.size
	var scale := minf(rect_size.x / TEX_SIZE, rect_size.y / TEX_SIZE)
	var drawn := Vector2(TEX_SIZE, TEX_SIZE) * scale
	var origin := (rect_size - drawn) * 0.5
	var rel := (pos - origin) / drawn
	if rel.x < 0.0 or rel.x > 1.0 or rel.y < 0.0 or rel.y > 1.0:
		return Vector2(-1, -1)
	return rel

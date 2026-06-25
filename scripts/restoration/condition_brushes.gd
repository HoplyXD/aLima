class_name ConditionBrushes
extends RefCounted
## Loads the hand-painted surface-condition PNGs (assets/artifact_conditions/*.png) as
## Texture2D "brush stamps" for DrawableTexture2D drawing.
##
## Each PNG carries its condition's irregular ALPHA shape (rust splotch, water stain, dust,
## ...), so stamping one paints that organic mark — and picking a different PNG plus a random
## size/flip each stroke is what makes the drawn grime change size and shape every time. This
## is the "turn the PNGs into textures for texture drawing" piece, and it is reusable beyond
## debug: the real over-restoration "scrub-too-much draws damage" mechanic draws from here too.
##
## NOTE: scans the asset dir with DirAccess, which is reliable in the editor / dev runs. If we
## ever need this in an exported build, swap to an explicit id list (PNGs become .ctex on export).

const DIR := "res://assets/artifact_conditions/"


## Resolution of a built circular brush (square; the disc is inscribed). 128 is crisp enough
## for a brush yet cheap to build.
const BRUSH_RES: int = 128

## Every condition PNG in the asset dir, as Texture2D brush stamps (may be empty if the dir
## is missing). Excludes Godot's sidecar .import files.
static func load_all() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		push_warning("ConditionBrushes: cannot open %s" % DIR)
		return out
	for file in dir.get_files():
		if not file.to_lower().ends_with(".png"):
			continue
		var tex := load(DIR + file) as Texture2D
		if tex != null:
			out.append(tex)
	return out


## Every condition PNG turned into a CIRCULAR brush: the PNG's colour fills a disc whose alpha
## falls off radially. Stamping one draws a soft textured CIRCLE (sized by the blit rect), not a
## pasted rectangle — so the brush "uses the PNG as a texture inside its radius".
static func load_circular() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for tex in load_all():
		var brush := make_circular(tex)
		if brush != null:
			out.append(brush)
	return out


## A circular brush whose RGB is `source` (stretched to fill) and whose alpha is the source
## alpha times a radial disc falloff. Returns an RGBA8 ImageTexture, or null if the source has
## no readable image.
static func make_circular(source: Texture2D) -> ImageTexture:
	if source == null:
		return null
	var img := source.get_image()
	if img == null:
		return null
	# Imported textures are usually VRAM-compressed (ETC2/ASTC/S3TC). resize() and the per-pixel
	# alpha work below require an UNCOMPRESSED format — calling them on a compressed image crashes
	# — so decompress and convert to RGBA8 FIRST, then resize.
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.resize(BRUSH_RES, BRUSH_RES)
	_apply_disc_falloff(img)
	return ImageTexture.create_from_image(img)


## A circular ERASE brush for blend_sub blitting: RGB is 0 (so the subtract never changes the
## painted colour) and alpha is the erase strength — 1 at the centre fading to 0 at the disc edge.
## Blitting it with a blend_sub texture_blit material SUBTRACTS that much alpha from the paint
## layer, removing the drawn overlay there so the artifact's own texture shows through (it does NOT
## paint a colour over the surface).
static func make_erase_disc() -> ImageTexture:
	var img := Image.create_empty(BRUSH_RES, BRUSH_RES, false, Image.FORMAT_RGBA8)
	var res := BRUSH_RES
	var c := Vector2(res, res) * 0.5
	for y in res:
		for x in res:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (res * 0.5)
			var erase := clampf(1.0 - smoothstep(0.55, 1.0, d), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, erase))
	return ImageTexture.create_from_image(img)


## Multiplies each pixel's alpha by a soft radial disc mask (1 at centre -> 0 at the edge), so the
## brush is a circle: the PNG's own alpha is preserved and scaled by the disc.
static func _apply_disc_falloff(img: Image) -> void:
	var res := img.get_width()
	var c := Vector2(res, res) * 0.5
	for y in res:
		for x in res:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (res * 0.5)
			var disc := clampf(1.0 - smoothstep(0.78, 1.0, d), 0.0, 1.0)
			var px := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(px.r, px.g, px.b, px.a * disc))

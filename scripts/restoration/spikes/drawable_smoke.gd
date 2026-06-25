extends SceneTree
## Headless smoke check for the DrawableTexture2D API on this binary. Confirms the class
## exists, setup() runs, and blit_rect() (default blend_mix) executes without error — the
## API surface the cleaning rework depends on. Prints SPIKE_OK / SPIKE_FAIL and exits.
##   & $godot --headless --path . -s scripts/restoration/spikes/drawable_smoke.gd


func _init() -> void:
	var ok := true
	if not ClassDB.class_exists("DrawableTexture2D"):
		print("SPIKE_FAIL: DrawableTexture2D not in ClassDB (need Godot 4.7+)")
		quit(1)
		return
	var tex := DrawableTexture2D.new()
	tex.setup(64, 64, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color(0.83, 0.80, 0.55), false)

	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.18, 0.15, 0.09, 1.0))
	var brush := ImageTexture.create_from_image(img)
	# A few blits at the default blend_mix (material = null) — the path the rework uses.
	for i in 8:
		tex.blit_rect(Rect2i(i * 4, i * 4, 16, 16), brush, Color.WHITE, 0, null)

	ok = tex.get_width() == 64 and tex.get_height() == 64

	# Brush library: the condition PNGs loaded as Texture2D stamps, blitted onto the drawable.
	var brushes := ConditionBrushes.load_all()
	for b in brushes:
		tex.blit_rect(Rect2i(8, 8, 32, 32), b, Color.WHITE, 0, null)
	ok = ok and not brushes.is_empty()

	# Circular brushes: this is the path that crashed in-game (get_image on a VRAM-compressed
	# texture -> resize). Building them must not crash, and each must blit cleanly.
	var circular := ConditionBrushes.load_circular()
	var eraser := ConditionBrushes.make_erase_disc()
	for c in circular:
		tex.blit_rect(Rect2i(8, 8, 48, 48), c, Color.WHITE, 0, null)
	if eraser != null:
		tex.blit_rect(Rect2i(8, 8, 48, 48), eraser, Color.WHITE, 0, null)
	ok = ok and not circular.is_empty() and eraser != null

	print(
		(
			"SPIKE_%s: drawable=%dx%d raw_brushes=%d circular=%d eraser=%s"
			% [
				"OK" if ok else "FAIL",
				tex.get_width(),
				tex.get_height(),
				brushes.size(),
				circular.size(),
				str(eraser != null)
			]
		)
	)
	quit(0 if ok else 1)

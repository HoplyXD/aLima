class_name Drawable3DSpike
extends Node3D
## De-risk spike #2: DrawableTexture2D drawing onto a 3D curved surface at the scrub point.
##
## Mirrors the real artifact: a sphere with the SAME analytic spherical UV that
## RestorationObject3D uses, so whatever works here drops straight onto the bench. It proves:
##   1. We can map a pointer ray -> surface hit -> spherical UV -> texel rect and blit a stamp
##      there with DrawableTexture2D, on a rotating 3D object (the stamp sticks to the surface).
##   2. Drawing the condition PNGs (via ConditionBrushes) paints their irregular shapes, and a
##      random brush + random size each stroke makes the drawn grime vary in size and shape --
##      the "decals change shape every time" feel, done as texture drawing not blob sprites.
##   3. Erase (paint the clean surface back, default blend_mix) reveals the surface under the
##      brush -- the small-area erasure the blob-fade decals lack.
##
## Run:  & $godot --path . scenes/restoration/spikes/drawable_3d_spike.tscn
##   Left-drag draw grime · E toggle draw/erase · right-drag rotate · 1/2/3 brush size · C clear

const TEX_SIZE: int = 512
const SPHERE_RADIUS: float = 0.55
const CLEAN_COLOR := Color(0.83, 0.80, 0.55)
const RADII: Array[int] = [24, 48, 80]  ## brush radii in texels (1/2/3)

## Samples the drawable via the SAME analytic spherical UV the blit + raycast use, so a stamp
## lands exactly where it is drawn (a StandardMaterial3D would sample the mesh's own UV instead
## and the stamps would be misplaced). Mirrors restoration_dirt.gdshader's mapping.
const SPIKE_SHADER_CODE := "shader_type spatial;\nrender_mode cull_back, diffuse_lambert;\nuniform sampler2D paint : source_color, filter_linear, repeat_disable;\nvarying vec3 vn;\nvoid vertex() { vn = normalize(NORMAL); }\nvoid fragment() {\n\tfloat u = 0.5 + atan(vn.x, vn.z) / TAU;\n\tfloat v = 0.5 - asin(clamp(vn.y, -1.0, 1.0)) / PI;\n\tALBEDO = texture(paint, vec2(u, v)).rgb;\n}\n"

var _surface: MeshInstance3D
var _camera: Camera3D
var _drawable: DrawableTexture2D
var _erase_brush: ImageTexture
var _brushes: Array[Texture2D] = []
var _status: Label

var _radius: int = RADII[1]
var _erasing: bool = false
var _left_down: bool = false
var _right_down: bool = false
var _yaw: float = 0.0
var _pitch: float = -0.18
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_drawable = DrawableTexture2D.new()
	_drawable.setup(TEX_SIZE, TEX_SIZE, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, CLEAN_COLOR, false)
	_erase_brush = _make_soft_brush(CLEAN_COLOR)
	_brushes = ConditionBrushes.load_all()

	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 0.0, 2.6)
	add_child(_camera)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(-30.0), 0.0)
	add_child(light)

	var sphere := SphereMesh.new()
	sphere.radius = SPHERE_RADIUS
	sphere.height = SPHERE_RADIUS * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_surface = MeshInstance3D.new()
	_surface.mesh = sphere
	var shader := Shader.new()
	shader.code = SPIKE_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("paint", _drawable)
	_surface.material_override = mat
	add_child(_surface)
	_apply_orientation()

	_build_hud()
	_refresh_status()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(16, 12)
	_status.add_theme_font_size_override("font_size", 18)
	layer.add_child(_status)


func _refresh_status() -> void:
	_status.text = (
		"DrawableTexture2D 3D spike — left-drag %s | E toggle | right-drag rotate | 1/2/3 size | C clear\n"
		% ("ERASE" if _erasing else "DRAW")
		+ "brushes loaded: %d   radius: %d px" % [_brushes.size(), _radius]
	)


# --- Brushes -----------------------------------------------------------------


## A soft round brush (RGB = clean colour, radial alpha) so erasing reveals the surface
## softly under the pointer — the same paint-clean-back model the 2D spike validated.
func _make_soft_brush(color: Color) -> ImageTexture:
	var size := RADII[RADII.size() - 1] * 2
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (size * 0.5)
			var a := clampf(1.0 - smoothstep(0.6, 1.0, d), 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(img)


# --- Drawing -----------------------------------------------------------------


## Stamps one mark at the surface point under `screen_pos`. Draw mode picks a random condition
## PNG at a random size (so size/shape vary each stamp); erase mode paints the clean surface
## back. No-op when the ray misses the sphere.
func _stamp_at(screen_pos: Vector2) -> void:
	var uv := _surface_uv(screen_pos)
	if uv.x < 0.0:
		return
	var brush: Texture2D = _erase_brush
	var r := _radius
	if not _erasing:
		if _brushes.is_empty():
			return
		brush = _brushes[_rng.randi_range(0, _brushes.size() - 1)]
		r = int(_radius * _rng.randf_range(0.6, 1.4))  # random size -> shape varies each stamp
	var cx := int(uv.x * TEX_SIZE)
	var cy := int(uv.y * TEX_SIZE)
	_drawable.blit_rect(Rect2i(cx - r, cy - r, r * 2, r * 2), brush, Color.WHITE, 0, null)


## Pointer ray -> sphere hit -> spherical UV (matching RestorationObject3D._local_to_uv), in
## the surface's LOCAL frame so stamps stick to the surface as it rotates. (-1,-1) on a miss.
func _surface_uv(screen_pos: Vector2) -> Vector2:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var hit := _ray_sphere(origin, dir, _surface.global_position, SPHERE_RADIUS)
	if not hit.get("hit", false):
		return Vector2(-1, -1)
	var local: Vector3 = _surface.to_local(hit["point"]).normalized()
	var u := 0.5 + atan2(local.x, local.z) / TAU
	var v := 0.5 - asin(clampf(local.y, -1.0, 1.0)) / PI
	return Vector2(u, v)


func _ray_sphere(origin: Vector3, direction: Vector3, center: Vector3, radius: float) -> Dictionary:
	var dir := direction.normalized()
	var oc := origin - center
	var b := oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return {"hit": false}
	var t := -b - sqrt(disc)
	if t < 0.0:
		t = -b + sqrt(disc)
		if t < 0.0:
			return {"hit": false}
	return {"hit": true, "point": origin + dir * t}


# --- Orientation -------------------------------------------------------------


func _apply_orientation() -> void:
	_surface.basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))


func _clear() -> void:
	# Re-setup repaints the whole surface with the clean base colour.
	_drawable.setup(TEX_SIZE, TEX_SIZE, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, CLEAN_COLOR, false)


# --- Input -------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_left_down = mb.pressed
			if mb.pressed:
				_stamp_at(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_right_down = mb.pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _left_down:
			_stamp_at(mm.position)
		elif _right_down:
			_yaw = fposmod(_yaw - mm.relative.x * 0.0065, TAU)
			_pitch = clampf(_pitch - mm.relative.y * 0.0065, -1.3, 1.3)
			_apply_orientation()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).keycode:
			KEY_E:
				_erasing = not _erasing
			KEY_1:
				_radius = RADII[0]
			KEY_2:
				_radius = RADII[1]
			KEY_3:
				_radius = RADII[2]
			KEY_C:
				_clear()
		_refresh_status()

class_name DrawableUV2Spike
extends Node3D
## De-risk spike for the SMOOTH cleaning rebuild: a DrawableTexture2D dirt mask sampled via an
## auto-generated (lightmap-unwrapped) UV2, so cleaning paints smooth CIRCLES at the right spot on a
## real artifact mesh whose own UVs overlap.
##
## Pipeline proven here:
##   1. merge the .obj surfaces -> one ArrayMesh
##   2. ArrayMesh.lightmap_unwrap() -> non-overlapping UV2
##   3. shader reads a DrawableTexture2D `dirt_mask` via UV2 (1 = dirty, 0 = clean)
##   4. left-drag -> ray-triangle hit -> barycentric UV2 -> blit a soft BLACK circle (smooth clean)
##
## Run:  & $godot --path . scenes/restoration/spikes/drawable_uv2_spike.tscn
##   Left-drag = clean (smooth circles) · right-drag = rotate · C = re-dirty

const MESH_PATH := "res://assets/3d Assets/Artifacts/Locket.obj"
const MASK_SIZE: int = 512
const BRUSH_RADIUS: int = 26  ## clean radius in mask texels
const MODEL_SCALE: float = 0.1
const SHADER := "shader_type spatial;\nrender_mode blend_mix, cull_back, depth_draw_opaque, diffuse_lambert, specular_schlick_ggx;\nuniform sampler2D dirt_mask : filter_linear;\nuniform vec4 dirt_color : source_color = vec4(0.42, 0.38, 0.3, 1.0);\nuniform vec4 clean_color : source_color = vec4(0.85, 0.7, 0.3, 1.0);\nvoid fragment() {\n\tfloat dirt = texture(dirt_mask, UV2).r;\n\tALBEDO = mix(clean_color.rgb, dirt_color.rgb, dirt);\n\tMETALLIC = 0.7 * (1.0 - dirt);\n\tROUGHNESS = mix(0.35, 0.95, dirt);\n}\n"

var _surface: MeshInstance3D
var _camera: Camera3D
var _mask: DrawableTexture2D
var _brush: ImageTexture
var _verts: PackedVector3Array
var _uv2: PackedVector2Array
var _indices: PackedInt32Array
var _status: Label
var _yaw: float = 0.0
var _pitch: float = -0.18
var _left_down: bool = false
var _right_down: bool = false


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.position = Vector3(0, 0, 2.6)
	add_child(_camera)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(-30.0), 0.0)
	add_child(light)

	_mask = DrawableTexture2D.new()
	_mask.setup(MASK_SIZE, MASK_SIZE, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color.WHITE, false)
	_brush = _make_soft_black_brush()

	var mesh := _build_unwrapped_mesh()
	_surface = MeshInstance3D.new()
	_surface.mesh = mesh
	_surface.scale = Vector3.ONE * MODEL_SCALE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	mat.set_shader_parameter("dirt_mask", _mask)
	_surface.material_override = mat
	add_child(_surface)
	_apply_orientation()
	_build_hud()


## Merges the .obj surfaces, lightmap-unwraps a UV2, and caches the post-unwrap triangles for raycast.
func _build_unwrapped_mesh() -> ArrayMesh:
	var src := load(MESH_PATH) as Mesh
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var indices := PackedInt32Array()
	var has_norms := true
	for s in src.get_surface_count():
		var a := src.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var base := verts.size()
		verts.append_array(v)
		var rn: Variant = a[Mesh.ARRAY_NORMAL]
		if rn is PackedVector3Array and (rn as PackedVector3Array).size() == v.size():
			norms.append_array(rn)
		else:
			has_norms = false
		var ri: Variant = a[Mesh.ARRAY_INDEX]
		if ri is PackedInt32Array and not (ri as PackedInt32Array).is_empty():
			for i in (ri as PackedInt32Array):
				indices.append(base + i)
		else:
			for i in v.size():
				indices.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	if has_norms and norms.size() == verts.size():
		arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	am.lightmap_unwrap(Transform3D.IDENTITY, 0.05)  # adds non-overlapping UV2
	# Cache the POST-unwrap geometry (unwrap may split verts at seams) for the raycast.
	var out := am.surface_get_arrays(0)
	_verts = out[Mesh.ARRAY_VERTEX]
	_uv2 = out[Mesh.ARRAY_TEX_UV2]
	var oi: Variant = out[Mesh.ARRAY_INDEX]
	_indices = oi if oi is PackedInt32Array else PackedInt32Array()
	if _indices.is_empty():
		for i in _verts.size():
			_indices.append(i)
	return am


func _make_soft_black_brush() -> ImageTexture:
	var size := BRUSH_RADIUS * 2
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / (size * 0.5)
			var a := clampf(1.0 - smoothstep(0.5, 1.0, d), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))  # black: blend_mix lowers dirt smoothly
	return ImageTexture.create_from_image(img)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(16, 12)
	_status.add_theme_font_size_override("font_size", 18)
	_status.text = (
		"UV2 dirt-mask spike — left-drag CLEAN (smooth circles) · right-drag rotate · C re-dirty\n"
		+ "verts=%d  uv2=%d" % [_verts.size(), _uv2.size()]
	)
	layer.add_child(_status)


# --- Cleaning -----------------------------------------------------------------


func _clean_at(screen_pos: Vector2) -> void:
	var uv := _surface_uv2(screen_pos)
	if uv.x < 0.0:
		return
	var cx := int(uv.x * MASK_SIZE)
	var cy := int(uv.y * MASK_SIZE)
	var r := BRUSH_RADIUS
	_mask.blit_rect(Rect2i(cx - r, cy - r, r * 2, r * 2), _brush, Color.WHITE, 0, null)


## Pointer ray -> nearest triangle hit -> barycentric UV2. (-1,-1) on a miss.
func _surface_uv2(screen_pos: Vector2) -> Vector2:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var inv := _surface.global_transform.affine_inverse()
	var lo: Vector3 = inv * origin
	var ld := (inv.basis * dir).normalized()
	var best_t := INF
	var best := Vector2(-1, -1)
	for i in range(0, _indices.size() - 2, 3):
		var ia := _indices[i]
		var ib := _indices[i + 1]
		var ic := _indices[i + 2]
		var p: Variant = Geometry3D.ray_intersects_triangle(lo, ld, _verts[ia], _verts[ib], _verts[ic])
		if p != null:
			var t: float = lo.distance_to(p as Vector3)
			if t < best_t:
				best_t = t
				best = _bary(p as Vector3, _verts[ia], _verts[ib], _verts[ic], _uv2[ia], _uv2[ib], _uv2[ic])
	return best


func _bary(p: Vector3, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> Vector2:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var d00 := v0.dot(v0)
	var d01 := v0.dot(v1)
	var d11 := v1.dot(v1)
	var d20 := v2.dot(v0)
	var d21 := v2.dot(v1)
	var denom := d00 * d11 - d01 * d01
	if absf(denom) < 1e-9:
		return ua
	var v := (d11 * d20 - d01 * d21) / denom
	var w := (d00 * d21 - d01 * d20) / denom
	return ua * (1.0 - v - w) + ub * v + uc * w


func _apply_orientation() -> void:
	_surface.basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0)).scaled(Vector3.ONE * MODEL_SCALE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_left_down = mb.pressed
			if mb.pressed:
				_clean_at(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_right_down = mb.pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _left_down:
			_clean_at(mm.position)
		elif _right_down:
			_yaw = fposmod(_yaw - mm.relative.x * 0.0065, TAU)
			_pitch = clampf(_pitch - mm.relative.y * 0.0065, -1.3, 1.3)
			_apply_orientation()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		if (event as InputEventKey).keycode == KEY_C:
			_mask.setup(MASK_SIZE, MASK_SIZE, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, Color.WHITE, false)

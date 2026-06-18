class_name RestorationObject3D
extends Node3D
## Presentation-only 3D model for the focused restoration view (REST-R8).
##
## This node owns the manipulable object geometry, the surface dirt mask, the
## clasp hotspot, and the analytic hit-testing the view uses to turn pointer rays
## into surface UVs. It carries NO game rules: it never reads is_carrier/contents,
## never touches RestorationService, GameState, or SaveService, and never decides
## whether a tool is correct. The view (restoration_view.gd) owns all of that and
## only asks this node to render dirt, rotate, and report where a ray hits.
##
## The object is intentionally simple development geometry (a tarnished medallion
## sphere with a bail and a clasp). Authored production models replace it later
## (Phase 13/20); the analytic spherical mapping keeps the painted dirt mask and
## the shader perfectly aligned without depending on a mesh UV layout.

const DIRT_SHADER := preload("res://scenes/restoration/restoration_dirt.gdshader")

const MASK_SIZE: int = 64  ## Dirt mask resolution; small so coverage scans stay cheap.
const BRUSH_RADIUS_UV: float = 0.16  ## Cleaning brush radius in UV space.
const CLEAN_THRESHOLD: float = 0.5  ## Mask R below this counts a texel as cleaned.

## Authored rest orientation the reset-view action returns to.
const AUTHORED_YAW: float = 0.0
const AUTHORED_PITCH: float = -0.18

## Narrowly-scoped presentation adapter: placeholder development geometry per
## openable_type. This is presentation only (mesh size / colours / clasp offset),
## never gameplay rules, so the reusable view stays artifact-agnostic. Authored
## models replace these in later phases.
const PRESENTATION := {
	"pendant":
	{
		"radius": 0.55,
		"clean_color": Color(0.83, 0.80, 0.55),
		"grime_color": Color(0.18, 0.15, 0.09),
		"clasp_offset": Vector3(0.0, 0.62, 0.0),
	},
	"_default":
	{
		"radius": 0.55,
		"clean_color": Color(0.78, 0.78, 0.80),
		"grime_color": Color(0.16, 0.14, 0.12),
		"clasp_offset": Vector3(0.0, 0.62, 0.0),
	},
}

var _built: bool = false
var _radius: float = 0.55
var _clasp_radius: float = 0.18
var _clasp_interactive: bool = false

var _medallion: MeshInstance3D
var _bail: MeshInstance3D
var _clasp: MeshInstance3D
var _material: ShaderMaterial
var _dirt_image: Image
var _dirt_texture: ImageTexture

var _yaw: float = AUTHORED_YAW
var _pitch: float = AUTHORED_PITCH
var _authored_basis: Basis = Basis.IDENTITY
var _clasp_closed_position: Vector3 = Vector3(0.0, 0.62, 0.0)

## Photo/blemish mode (decal-based templates: photos, frames, paper). Instead of a
## shader dirt mask, the object becomes a flat photo plane carrying discrete
## blemish hotspots the player clicks to clean. Placeholder development geometry.
const PHOTO_HALF_W: float = 0.78
const PHOTO_HALF_H: float = 0.56
const BLEMISH_RADIUS: float = 0.13  ## Pick radius for a blemish hotspot.
const PHOTO_COLOR := Color(0.90, 0.87, 0.79)

var _photo_mode: bool = false
var _photo: MeshInstance3D
var _blemishes: Dictionary = {}  ## blemish_id -> {node: MeshInstance3D, center: Vector3}


func _ready() -> void:
	_authored_basis = Basis.from_euler(Vector3(AUTHORED_PITCH, AUTHORED_YAW, 0.0))
	if not _built:
		_build()
	reset_orientation()


## (Re)configures the model for a specific instance/template. Presentation only:
## the initial surface cleanliness is reconstructed from the instance condition so
## reopening the view shows progress consistent with saved state.
func configure(template: ScrapObjectTemplate, inst: ObjectInstance) -> void:
	if not _built:
		_build()
	# Default back to medallion presentation; the view re-enters photo mode for
	# decal-based templates after configuring.
	_set_photo_mode(false)
	var preset: Dictionary = PRESENTATION.get(
		template.openable_type if template != null else "", PRESENTATION["_default"]
	)
	_apply_preset(preset)

	var fraction := 0.0
	if template != null and template.clean_completion_threshold > 0:
		fraction = clampf(inst.condition / float(template.clean_completion_threshold), 0.0, 1.0)

	var is_open := inst.state == ModelEnums.ObjState.OPEN
	var is_clean := inst.state == ModelEnums.ObjState.CLEAN or is_open
	if is_clean:
		set_fully_clean()
	else:
		_apply_initial_cleanliness(fraction)
	set_clasp_revealed(is_clean)
	set_clasp_open(is_open)
	reset_orientation()


# --- Orientation -------------------------------------------------------------


## Orbits the object by the given yaw/pitch deltas (radians). Pitch is clamped and
## yaw wraps so the object can never reach an unusable upside-down/gimbal state.
func rotate_view(delta_yaw: float, delta_pitch: float) -> void:
	_yaw = fposmod(_yaw + delta_yaw, TAU)
	_pitch = clampf(_pitch + delta_pitch, -1.3, 1.3)
	_apply_orientation()


## Returns the object to its authored rest orientation.
func reset_orientation() -> void:
	_yaw = AUTHORED_YAW
	_pitch = AUTHORED_PITCH
	_apply_orientation()


func get_orientation_basis() -> Basis:
	return basis


func get_authored_basis() -> Basis:
	return _authored_basis


func _apply_orientation() -> void:
	basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))


# --- Surface cleaning --------------------------------------------------------


## Clears dirt within the brush radius around a UV point (soft-edged). Presentation
## only; the view calls this after RestorationService confirms a compatible tool.
func clean_brush_at_uv(uv: Vector2) -> void:
	if _dirt_image == null:
		return
	var cx := uv.x * MASK_SIZE
	var cy := uv.y * MASK_SIZE
	var r_px := BRUSH_RADIUS_UV * MASK_SIZE
	if r_px <= 0.0:
		return
	var span := int(ceil(r_px))
	var min_x := int(floor(cx)) - span
	var max_x := int(floor(cx)) + span
	var min_y := clampi(int(floor(cy)) - span, 0, MASK_SIZE - 1)
	var max_y := clampi(int(floor(cy)) + span, 0, MASK_SIZE - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx := float(x) + 0.5 - cx
			var dy := float(y) + 0.5 - cy
			var dist := sqrt(dx * dx + dy * dy)
			if dist > r_px:
				continue
			var wrapped_x := ((x % MASK_SIZE) + MASK_SIZE) % MASK_SIZE
			var current := _dirt_image.get_pixel(wrapped_x, y).r
			# 0 at brush centre (fully clean) rising to 1 at the edge.
			var target := clampf(dist / r_px, 0.0, 1.0)
			var new_r := minf(current, target)
			_dirt_image.set_pixel(wrapped_x, y, Color(new_r, new_r, new_r, 1.0))
	_dirt_texture.update(_dirt_image)


## Fraction of the surface texels that are now cleaned (0..1).
func coverage() -> float:
	if _dirt_image == null:
		return 0.0
	var cleaned := 0
	for y in MASK_SIZE:
		for x in MASK_SIZE:
			if _dirt_image.get_pixel(x, y).r < CLEAN_THRESHOLD:
				cleaned += 1
	return float(cleaned) / float(MASK_SIZE * MASK_SIZE)


## Picks a still-dirty UV (deterministic scan) for controller/keyboard cleaning,
## which auto-targets grime instead of requiring precise pointer aiming.
func auto_target_dirty_uv() -> Vector2:
	if _dirt_image != null:
		for y in MASK_SIZE:
			for x in MASK_SIZE:
				if _dirt_image.get_pixel(x, y).r >= CLEAN_THRESHOLD:
					return Vector2((float(x) + 0.5) / MASK_SIZE, (float(y) + 0.5) / MASK_SIZE)
	return Vector2(0.5, 0.5)


func set_fully_clean() -> void:
	if _dirt_image == null:
		return
	_dirt_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_dirt_texture.update(_dirt_image)


## Returns the exact dirt mask as a (small, lossless) PNG so the view can preserve
## where the player cleaned when switching artifacts and persist it to the save.
## Empty in photo mode (decal removal is already persisted on the instance).
func snapshot_dirt_png() -> PackedByteArray:
	if _photo_mode or _dirt_image == null:
		return PackedByteArray()
	return _dirt_image.save_png_to_buffer()


## Restores a previously snapshotted dirt mask, re-creating the exact cleaned spots.
func restore_dirt_png(bytes: PackedByteArray) -> void:
	if bytes.is_empty() or _photo_mode or _dirt_image == null:
		return
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return
	if img.get_width() != MASK_SIZE or img.get_height() != MASK_SIZE:
		return
	img.convert(_dirt_image.get_format())
	_dirt_image.copy_from(img)
	_dirt_texture.update(_dirt_image)


## True when the texel under the given UV has been cleaned (test/integration seam).
func is_uv_cleaned(uv: Vector2) -> bool:
	if _dirt_image == null:
		return false
	var x := clampi(int(uv.x * MASK_SIZE), 0, MASK_SIZE - 1)
	var y := clampi(int(uv.y * MASK_SIZE), 0, MASK_SIZE - 1)
	return _dirt_image.get_pixel(x, y).r < CLEAN_THRESHOLD


# --- Clasp -------------------------------------------------------------------


## Shows/hides the clasp and marks whether it can currently be activated. The view
## only reveals it once RestorationService reports the instance is CLEAN.
func set_clasp_revealed(value: bool) -> void:
	_clasp_interactive = value
	if _clasp != null:
		_clasp.visible = value
		var mat := _clasp.material_override as StandardMaterial3D
		if mat != null:
			# Subtle highlight invites interaction; not a carrier tell (every clean
			# openable shows the same prompt regardless of contents).
			mat.emission_enabled = value


func set_clasp_open(value: bool) -> void:
	if _clasp == null:
		return
	_clasp.visible = value or _clasp_interactive
	if value:
		_clasp_interactive = false
		_clasp.position = _clasp_closed_position + Vector3(0.0, 0.18, 0.12)
		_clasp.rotation = Vector3(deg_to_rad(-55.0), 0.0, 0.0)
		var mat := _clasp.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_enabled = false
	else:
		_clasp.position = _clasp_closed_position
		_clasp.rotation = Vector3.ZERO


func is_clasp_interactive() -> bool:
	return _clasp_interactive


# --- Hit testing -------------------------------------------------------------


## Analytic ray/surface test. Returns {hit:bool, point:Vector3, uv:Vector2}. Uses
## ray-sphere math rather than the physics engine so it is deterministic and runs
## headlessly, and so it cleanly distinguishes object hits from empty space.
func ray_test_surface(origin: Vector3, direction: Vector3) -> Dictionary:
	if not _built or _medallion == null:
		return {"hit": false}
	var hit := _ray_sphere(origin, direction, _medallion.global_position, _radius)
	if not hit.get("hit", false):
		return {"hit": false}
	var local: Vector3 = _medallion.to_local(hit["point"])
	return {"hit": true, "point": hit["point"], "uv": _local_to_uv(local)}


## Ray test against the clasp hotspot. Only hits while the clasp is interactive.
func ray_test_clasp(origin: Vector3, direction: Vector3) -> Dictionary:
	if not _clasp_interactive or _clasp == null:
		return {"hit": false}
	return _ray_sphere(origin, direction, _clasp.global_position, _clasp_radius)


## Converts a point on the medallion (object-local space) to the same spherical UV
## the dirt shader uses, so painted dirt and rendered grime stay aligned.
func _local_to_uv(p: Vector3) -> Vector2:
	var n := p.normalized()
	var u := 0.5 + atan2(n.x, n.z) / TAU
	var v := 0.5 - asin(clampf(n.y, -1.0, 1.0)) / PI
	return Vector2(u, v)


func _ray_sphere(origin: Vector3, direction: Vector3, center: Vector3, radius: float) -> Dictionary:
	var dir := direction.normalized()
	var oc := origin - center
	var b := oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return {"hit": false}
	var sqrt_disc := sqrt(disc)
	var t := -b - sqrt_disc
	if t < 0.0:
		t = -b + sqrt_disc
		if t < 0.0:
			return {"hit": false}
	return {"hit": true, "point": origin + dir * t, "t": t}


# --- Photo / blemish mode ----------------------------------------------------


## Switches into the flat photo presentation used by decal-based templates and
## builds one clickable hotspot per authored blemish. `colors` maps a blemish
## type to its placeholder swatch colour; `removed_ids` hides already-cleaned
## blemishes so a reopened photo reconstructs saved progress.
func enter_photo_mode(decals: Array, removed_ids: Array, colors: Dictionary) -> void:
	if not _built:
		_build()
	_set_photo_mode(true)
	_clear_blemishes()
	var count := decals.size()
	var index := 0
	for decal in decals:
		var center := _blemish_layout(index, count)
		var node := _make_blemish_node(center, colors.get(decal.type, Color(0.5, 0.5, 0.5)))
		add_child(node)
		_blemishes[decal.id] = {"node": node, "center": center}
		node.visible = not removed_ids.has(decal.id)
		index += 1
	reset_orientation()


func _set_photo_mode(enabled: bool) -> void:
	_photo_mode = enabled
	if _medallion != null:
		_medallion.visible = not enabled
	if _bail != null:
		_bail.visible = not enabled
	if _clasp != null and enabled:
		_clasp.visible = false
		_clasp_interactive = false
	if enabled and _photo == null:
		_build_photo()
	if _photo != null:
		_photo.visible = enabled
	if not enabled:
		_clear_blemishes()


func is_photo_mode() -> bool:
	return _photo_mode


## Ray test against the visible blemish hotspots. Returns {hit, blemish_id, point}.
## Analytic (ray-sphere) so it runs headlessly, like the medallion surface test.
func ray_test_blemish(origin: Vector3, direction: Vector3) -> Dictionary:
	var best := {"hit": false}
	var best_t := INF
	for blemish_id in _blemishes.keys():
		var entry: Dictionary = _blemishes[blemish_id]
		var node: MeshInstance3D = entry["node"]
		if node == null or not node.visible:
			continue
		var center: Vector3 = to_global(entry["center"])
		var hit := _ray_sphere(origin, direction, center, BLEMISH_RADIUS)
		if hit.get("hit", false) and hit["t"] < best_t:
			best_t = hit["t"]
			best = {"hit": true, "blemish_id": blemish_id, "point": hit["point"]}
	return best


## Hides a cleaned blemish hotspot. Presentation only; the view calls this after
## RestorationService confirms the matching tool removed it.
func remove_blemish(blemish_id: String) -> void:
	if _blemishes.has(blemish_id):
		var node: MeshInstance3D = _blemishes[blemish_id]["node"]
		if node != null:
			node.visible = false


## A still-dirty blemish id for controller/keyboard cleaning (auto-target), or "".
func auto_target_blemish_id() -> String:
	for blemish_id in _blemishes.keys():
		var node: MeshInstance3D = _blemishes[blemish_id]["node"]
		if node != null and node.visible:
			return blemish_id
	return ""


## Test/integration seam: ids of blemishes still showing.
func get_visible_blemish_ids() -> Array[String]:
	var out: Array[String] = []
	for blemish_id in _blemishes.keys():
		var node: MeshInstance3D = _blemishes[blemish_id]["node"]
		if node != null and node.visible:
			out.append(blemish_id)
	return out


## Test/integration seam: world-space centre of a blemish hotspot (for aiming a ray).
func get_blemish_global_center(blemish_id: String) -> Vector3:
	if _blemishes.has(blemish_id):
		return to_global(_blemishes[blemish_id]["center"])
	return Vector3.ZERO


func has_visible_blemishes() -> bool:
	for blemish_id in _blemishes.keys():
		var node: MeshInstance3D = _blemishes[blemish_id]["node"]
		if node != null and node.visible:
			return true
	return false


func _clear_blemishes() -> void:
	for blemish_id in _blemishes.keys():
		var node: MeshInstance3D = _blemishes[blemish_id]["node"]
		if node != null:
			node.queue_free()
	_blemishes.clear()


## Lays blemishes out in a tidy grid across the photo face, slightly proud of it.
func _blemish_layout(index: int, count: int) -> Vector3:
	var cols := maxi(1, int(ceil(sqrt(float(count)))))
	var rows := maxi(1, int(ceil(float(count) / float(cols))))
	var col := index % cols
	var row := index / cols
	var fx := (float(col) + 0.5) / float(cols)
	var fy := (float(row) + 0.5) / float(rows)
	var x := lerpf(-PHOTO_HALF_W * 0.7, PHOTO_HALF_W * 0.7, fx)
	var y := lerpf(PHOTO_HALF_H * 0.7, -PHOTO_HALF_H * 0.7, fy)
	return Vector3(x, y, 0.04)


func _make_blemish_node(center: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = BLEMISH_RADIUS * 0.7
	mesh.height = BLEMISH_RADIUS * 1.4
	mesh.radial_segments = 12
	mesh.rings = 6
	var node := MeshInstance3D.new()
	node.name = "Blemish"
	node.mesh = mesh
	node.position = center
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	node.material_override = mat
	return node


func _build_photo() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(PHOTO_HALF_W * 2.0, PHOTO_HALF_H * 2.0)
	_photo = MeshInstance3D.new()
	_photo.name = "Photo"
	_photo.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PHOTO_COLOR
	mat.roughness = 1.0
	# A photo reads from one side; keep it lit from the front without cull surprises.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_photo.material_override = mat
	add_child(_photo)


# --- Geometry construction ---------------------------------------------------


func _build() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = _radius
	sphere.height = _radius * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24

	_dirt_image = Image.create_empty(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	_dirt_image.fill(Color(1.0, 1.0, 1.0, 1.0))
	_dirt_texture = ImageTexture.create_from_image(_dirt_image)

	_material = ShaderMaterial.new()
	_material.shader = DIRT_SHADER
	_material.set_shader_parameter("dirt_mask", _dirt_texture)

	_medallion = MeshInstance3D.new()
	_medallion.name = "Medallion"
	_medallion.mesh = sphere
	_medallion.material_override = _material
	add_child(_medallion)

	var bail_mesh := TorusMesh.new()
	bail_mesh.inner_radius = 0.07
	bail_mesh.outer_radius = 0.13
	_bail = MeshInstance3D.new()
	_bail.name = "Bail"
	_bail.mesh = bail_mesh
	_bail.position = Vector3(0.0, _radius + 0.06, 0.0)
	_bail.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	_bail.material_override = _make_metal_material(Color(0.55, 0.5, 0.32))
	add_child(_bail)

	var clasp_mesh := BoxMesh.new()
	clasp_mesh.size = Vector3(0.16, 0.1, 0.06)
	_clasp = MeshInstance3D.new()
	_clasp.name = "Clasp"
	_clasp.mesh = clasp_mesh
	_clasp.position = _clasp_closed_position
	var clasp_mat := _make_metal_material(Color(0.62, 0.56, 0.36))
	clasp_mat.emission = Color(0.9, 0.78, 0.4)
	clasp_mat.emission_energy_multiplier = 0.6
	clasp_mat.emission_enabled = false
	_clasp.material_override = clasp_mat
	_clasp.visible = false
	add_child(_clasp)

	_built = true


func _apply_preset(preset: Dictionary) -> void:
	_radius = float(preset.get("radius", 0.55))
	_clasp_closed_position = preset.get("clasp_offset", Vector3(0.0, 0.62, 0.0))
	if _clasp != null:
		_clasp.position = _clasp_closed_position
	if _medallion != null and _medallion.mesh is SphereMesh:
		var sphere := _medallion.mesh as SphereMesh
		sphere.radius = _radius
		sphere.height = _radius * 2.0
	if _bail != null:
		_bail.position = Vector3(0.0, _radius + 0.06, 0.0)
	if _material != null:
		_material.set_shader_parameter("clean_color", preset.get("clean_color", Color.WHITE))
		_material.set_shader_parameter("grime_color", preset.get("grime_color", Color.BLACK))


func _make_metal_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.6
	mat.roughness = 0.4
	return mat


func _apply_initial_cleanliness(fraction: float) -> void:
	if _dirt_image == null:
		return
	_dirt_image.fill(Color(1.0, 1.0, 1.0, 1.0))
	if fraction <= 0.0:
		_dirt_texture.update(_dirt_image)
		return
	if fraction >= 1.0:
		set_fully_clean()
		return
	# Deterministic scatter so a reopened, partly-cleaned object reconstructs the
	# same visual progress from its saved condition.
	for y in MASK_SIZE:
		for x in MASK_SIZE:
			if _value_noise(x, y) < fraction:
				_dirt_image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 1.0))
	_dirt_texture.update(_dirt_image)


func _value_noise(x: int, y: int) -> float:
	var n := sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
	return n - floor(n)

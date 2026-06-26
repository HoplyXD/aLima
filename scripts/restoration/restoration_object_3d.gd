@tool
class_name RestorationObject3D
extends Node3D

## Per-artifact customisation — one directive per line, in the Inspector. Supported now:
##   Max Decals: N    -> only N of the placed ArtifactConditionDecal children appear,
##                       chosen at random (seeded per save + loop). Place as many decals
##                       as you like; N show in game. 0 = show ALL.
## When NO "Max Decals" line is present the legacy randomized_decal_count below is used
## instead. Unknown lines are ignored, so more directives can be added later.
@export_multiline var customization: String = ""
## Legacy fallback for the decal limit (use the "Max Decals" line above instead). Only
## consulted when the customisation text has no "Max Decals" directive.
@export var randomized_decal_count: int = 0
## OPTIONAL authored 3D model for this artifact. When set, it is instanced and shown in
## place of the placeholder medallion (the placeholder sphere stays, invisible, as the
## rotate/clean hit-test proxy). Set this on a per-artifact scene to use the real model.
@export var model_scene: PackedScene:
	set(value):
		model_scene = value
		if _built:
			_apply_authored_model()
## OPTIONAL authored Mesh (e.g. a `.obj`, which Godot imports as a Mesh, not a scene).
## Used like `model_scene` but for a bare mesh. `model_scene` wins if both are set.
@export var model_mesh: Mesh:
	set(value):
		model_mesh = value
		if _built:
			_apply_authored_model()
## OPTIONAL material for a `model_mesh`. A bare .obj has no material (renders grey), so
## assign one here (e.g. a gold StandardMaterial3D) to give it a look. Ignored for a
## model_scene, which carries its own materials.
@export var model_material: Material:
	set(value):
		model_material = value
		if _built:
			_apply_authored_model()
## Uniform scale applied to the authored model (raw .glb/.obj are often metres-large).
@export var model_scale: float = 1.0:
	set(value):
		model_scale = value
		if _model_instance != null:
			_model_instance.scale = Vector3.ONE * model_scale
## NOTE: @tool so the placeholder geometry builds in the editor — open
## scenes/restoration/restoration_artifact.tscn to view/iterate the model directly.
## Editor execution only ever runs _build()/reset_orientation() (pure geometry);
## all gameplay-driven calls (configure/decals/clean) happen at runtime via the view.
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
const PAINT_SIZE: int = 512  ## Runtime paint-layer (DrawableTexture2D) resolution; crisp, GPU-side.

## --- Dust overlay (model-agnostic grime) ---
## A duplicate "dust shell" of the artifact mesh, textured with a triplanar dust texture (no UV
## needed, so it works on any model), thinned to a random ~50% of its triangles for a patchy dust
## shape, and erased triangle-by-triangle as the player works a tool across it. Replaces per-model
## UV texture painting for grime.
const DUST_TEXTURE := preload("res://assets/artifact_conditions/Dust.png")
const DUST_OPACITY: float = 0.9  ## Strong enough to read clearly; lower toward 0.5 to make it subtler.
const DUST_INFLATE: float = 1.015  ## Shell sits just proud of the surface (avoids z-fighting).
const DUST_NOISE_FREQ: float = 2.4  ## Patch size of the random dust shape (in normalised space).
const DUST_COVERAGE: float = 0.0  ## Noise threshold; 0 ≈ 50% of triangles kept dusty.
const DUST_ERASE_RADIUS: float = 0.13  ## Object-space radius of dust removed per stroke.

## When true the author-placed / data-driven condition DECALS are hidden (the dust overlay is the
## grime now). Flip to false to bring the old decal conditions back.
const HIDE_DECALS: bool = true
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
## When an authored model is shown, the procedural placeholder clasp box is a floating
## eyesore that doesn't match the model — so its mesh is hidden. The clasp stays
## interactive (ray_test_clasp still hits it), so the clean->open click works unchanged;
## the on-screen "click the clasp to open" prompt guides the player.
var _suppress_clasp_visual: bool = false
var _model_instance: Node3D = null  ## Authored model_scene instance, when set.

var _medallion: MeshInstance3D
var _bail: MeshInstance3D
var _clasp: MeshInstance3D
var _material: ShaderMaterial
var _dirt_image: Image
var _dirt_texture: ImageTexture
## Runtime-only drawn grime/damage layer composited by the dirt shader. Null in the editor
## (created at runtime) so the @tool geometry build never depends on the experimental texture.
var _paint_texture: ImageTexture = null
var _paint_image: Image = null

## Dust overlay state: the shell node, its per-triangle vertices (3 per triangle, object space),
## centroids (1 per triangle), and an alive flag per triangle (1 = dusty, 0 = cleaned/absent).
var _dust_overlay: MeshInstance3D
var _dust_verts: PackedVector3Array = PackedVector3Array()
var _dust_centroids: PackedVector3Array = PackedVector3Array()
var _dust_alive: PackedByteArray = PackedByteArray()
var _dust_initial: int = 0  ## Triangles that START dusty, so cleaned-fraction is relative to them.
var _clean_puff: GPUParticles3D  ## Dust burst spawned on the artifact where a tool cleans (runtime).

var _yaw: float = AUTHORED_YAW
var _pitch: float = AUTHORED_PITCH
var _authored_basis: Basis = Basis.IDENTITY
## Uniform scale the dev set on the artifact scene's ROOT node. Captured before the
## orientation system (which rebuilds `basis` as a pure rotation) can wipe it, and folded
## back into every orientation + hit-test so scaling an artifact in the editor actually
## enlarges it on the bench. 1.0 = no scaling.
var _authored_scale: float = 1.0
var _clasp_closed_position: Vector3 = Vector3(0.0, 0.62, 0.0)

## Photo/blemish mode (decal-based templates: photos, frames, paper). Instead of a
## shader dirt mask, the object becomes a flat photo plane carrying discrete
## blemish hotspots the player clicks to clean. Placeholder development geometry.
const PHOTO_HALF_W: float = 0.78
const PHOTO_HALF_H: float = 0.56
const BLEMISH_RADIUS: float = 0.13  ## Pick radius for a blemish hotspot.
const PHOTO_COLOR := Color(0.90, 0.87, 0.79)

## Data-driven conditions/blemishes are built from the same scene devs place by hand,
## so they share its texture/particles/fade behaviour.
const CONDITION_DECAL_SCENE := preload("res://scenes/restoration/artifact_condition_decal.tscn")

var _photo_mode: bool = false
## Conditions mode keeps the 3D object (and clasp) visible and scatters condition
## decals over its surface — used by delivered artifacts carrying random
## conditions, so they present identically to a carrier and still open after CLEAN.
var _conditions_mode: bool = false
var _photo: MeshInstance3D
## blemish_id -> {node: Decal|MeshInstance3D, center: Vector3, removed: bool}. `removed`
## is the logical "cleaned" flag; the decal node fades out separately for presentation.
var _blemishes: Dictionary = {}
## Author-placed ArtifactConditionDecal children discovered at runtime, keyed by node
## name -> {node, required_tool, type_id, removed}. Distinct from `_blemishes` (which
## is data-driven) so authored event-artifact conditions clean with their own tool.
var _authored: Dictionary = {}
## Per-instance layout randomisation phase so the same template's conditions land in
## different spots on different artifacts (seeded by the instance, set on enter_*_mode).
var _layout_phase: float = 0.0


func _ready() -> void:
	_authored_basis = Basis.from_euler(Vector3(AUTHORED_PITCH, AUTHORED_YAW, 0.0))
	# Capture the dev's root-node scale BEFORE reset_orientation() rebuilds basis (which
	# would otherwise discard it), so an artifact scaled in the editor renders that big here.
	_authored_scale = maxf(0.001, transform.basis.get_scale().x)
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
	# Rotation from the orbit controls, with the dev's authored root scale folded back in.
	basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0)).scaled(Vector3.ONE * _authored_scale)


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


# --- Runtime paint layer (DrawableTexture2D) ---------------------------------
# A drawable grime/damage layer the player can draw onto via the dirt shader's paint_layer
# sampler, at the SAME analytic surface UV ray_test_surface returns — so a drawn stamp lands
# exactly where the tool is worked. Presentation only; created at runtime (not in the editor).


## Creates the transparent paint layer and wires it into the dirt material (runtime only).
func _ensure_paint_layer() -> void:
	if Engine.is_editor_hint() or _material == null or _paint_texture != null:
		return
	_paint_image = Image.create_empty(PAINT_SIZE, PAINT_SIZE, false, Image.FORMAT_RGBA8)
	_paint_image.fill(Color(0, 0, 0, 0))
	_paint_texture = ImageTexture.create_from_image(_paint_image)
	_material.set_shader_parameter("paint_layer", _paint_texture)
	_material.set_shader_parameter("paint_enabled", 1.0)


## Draws a brush stamp onto the paint layer at the given surface UV. `size_px` is the stamp's
## half-extent in texels; `material` is the blit material (null = default blend_mix to ADD grime;
## a blend_sub material to ERASE). No-op in the editor or before the layer exists (e.g. an authored
## model that hides the medallion). Also stamps a wrapped copy across the u=0/1 seam so a brush
## straddling the analytic-UV seam isn't sliced into a hard line there.
func paint_at_uv(uv: Vector2, brush: Texture2D, size_px: int, material: Material = null) -> void:
	if _paint_texture == null or brush == null:
		return
	var cx := int(uv.x * PAINT_SIZE)
	var cy := int(uv.y * PAINT_SIZE)
	var r := maxi(1, size_px)
	_blit_paint(cx, cy, r, brush, material)
	if cx - r < 0:
		_blit_paint(cx + PAINT_SIZE, cy, r, brush, material)
	elif cx + r > PAINT_SIZE:
		_blit_paint(cx - PAINT_SIZE, cy, r, brush, material)


func _blit_paint(cx: int, cy: int, r: int, brush: Texture2D, _material: Material) -> void:
	if _paint_image == null or brush == null:
		return
	var src := brush.get_image()
	if src == null:
		return
	if src.get_format() != _paint_image.get_format():
		src = src.duplicate()
		src.convert(_paint_image.get_format())
	var dst := Vector2i(cx - r, cy - r)
	_paint_image.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), dst)
	_paint_texture.update(_paint_image)


## Clears all drawn paint (re-fills the layer transparent) so drawn damage doesn't carry
## between artifacts when the bench loads a new instance.
func clear_paint() -> void:
	if _paint_image == null:
		return
	_paint_image.fill(Color(0, 0, 0, 0))
	_paint_texture.update(_paint_image)


## True when a runtime paint layer exists (not the editor / not yet built).
func has_paint_layer() -> bool:
	return _paint_texture != null


# --- Dust overlay ------------------------------------------------------------


## (Re)builds the dust shell for this artifact: duplicates the visible mesh, keeps a random ~50%
## of its triangles (seeded, so each artifact/loop gets a different patchy shape), and shows them
## as a half-transparent, triplanar-dust shell just proud of the surface. Runtime only.
func build_dust_overlay(seed_value: int) -> void:
	if Engine.is_editor_hint():
		return
	_clear_dust_overlay()
	var mesh := _dust_source_mesh()
	if mesh == null:
		return
	var scale := _dust_source_scale() * DUST_INFLATE
	if not _extract_dust_triangles(mesh, scale):
		return
	_seed_dust_alive(seed_value)
	_dust_overlay = MeshInstance3D.new()
	_dust_overlay.name = "DustOverlay"
	_dust_overlay.material_override = _make_dust_material()
	add_child(_dust_overlay)
	_rebuild_dust_mesh()


func has_dust_overlay() -> bool:
	return _dust_overlay != null and not _dust_verts.is_empty()


## Removes dust where a pointer ray meets the shell: finds the nearest dusty triangle the ray hits,
## then clears every dusty triangle whose centre is within `radius` of that point, and rebuilds the
## shell. Returns true when anything was erased. `origin`/`direction` are world space.
func erase_dust_ray(origin: Vector3, direction: Vector3, radius: float = DUST_ERASE_RADIUS) -> bool:
	if not has_dust_overlay():
		return false
	var inv := _dust_overlay.global_transform.affine_inverse()
	var local_origin := inv * origin
	var local_dir := (inv.basis * direction).normalized()
	var hit_point: Variant = _dust_ray_hit(local_origin, local_dir)
	if hit_point == null:
		return false
	var center: Vector3 = hit_point
	var changed := false
	for i in _dust_alive.size():
		if _dust_alive[i] == 1 and _dust_centroids[i].distance_to(center) <= radius:
			_dust_alive[i] = 0
			changed = true
	if changed:
		_rebuild_dust_mesh()
	return changed


## Fraction of the INITIALLY-dusty triangles that have been cleaned (0 = untouched, 1 = spotless),
## so it reads 0 on a fresh shell even though only ~half the mesh starts dusty. Test/UI seam.
func dust_cleaned_fraction() -> float:
	if _dust_initial == 0:
		return 1.0
	var alive := 0
	for i in _dust_alive.size():
		alive += _dust_alive[i]
	return 1.0 - float(alive) / float(_dust_initial)


## Nearest local-space point where the ray meets a still-dusty triangle, or null on a miss.
func _dust_ray_hit(local_origin: Vector3, local_dir: Vector3) -> Variant:
	var best_t := INF
	var best: Variant = null
	for i in _dust_alive.size():
		if _dust_alive[i] == 0:
			continue
		var base := i * 3
		var p: Variant = Geometry3D.ray_intersects_triangle(
			local_origin, local_dir, _dust_verts[base], _dust_verts[base + 1], _dust_verts[base + 2]
		)
		if p != null:
			var t: float = local_origin.distance_to(p as Vector3)
			if t < best_t:
				best_t = t
				best = p
	return best


## Extracts every triangle of `mesh` (scaled) into _dust_verts (+ centroids). Returns false when the
## mesh exposes no usable geometry.
func _extract_dust_triangles(mesh: Mesh, scale: float) -> bool:
	_dust_verts = PackedVector3Array()
	_dust_centroids = PackedVector3Array()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = (
			arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		)
		if indices.is_empty():
			for i in verts.size():
				indices.append(i)
		for i in range(0, indices.size() - 2, 3):
			var a := verts[indices[i]] * scale
			var b := verts[indices[i + 1]] * scale
			var c := verts[indices[i + 2]] * scale
			_dust_verts.append(a)
			_dust_verts.append(b)
			_dust_verts.append(c)
			_dust_centroids.append((a + b + c) / 3.0)
	return not _dust_verts.is_empty()


## Marks ~half the triangles dusty using value noise over the (normalised) centroid, so the dust
## lands in coherent patches rather than salt-and-pepper, and differently per seed.
func _seed_dust_alive(seed_value: int) -> void:
	var extent := 0.001
	for c in _dust_centroids:
		extent = maxf(extent, c.length())
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = DUST_NOISE_FREQ
	_dust_alive = PackedByteArray()
	_dust_alive.resize(_dust_centroids.size())
	_dust_initial = 0
	for i in _dust_centroids.size():
		var n := noise.get_noise_3dv(_dust_centroids[i] / extent)
		var dusty := 1 if n > DUST_COVERAGE else 0
		_dust_alive[i] = dusty
		_dust_initial += dusty


## Rebuilds the shell mesh from the currently-alive triangles (flat-shaded so dust catches light).
func _rebuild_dust_mesh() -> void:
	if _dust_overlay == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for i in _dust_alive.size():
		if _dust_alive[i] == 0:
			continue
		var base := i * 3
		var a := _dust_verts[base]
		var b := _dust_verts[base + 1]
		var c := _dust_verts[base + 2]
		var n := (b - a).cross(c - a).normalized()
		for v in [a, b, c]:
			st.set_normal(n)
			st.add_vertex(v)
		any = true
	_dust_overlay.mesh = st.commit() if any else null


## The dust material: the dust texture projected triplanar (object space, so it rides the artifact
## as it rotates) at half opacity.
func _make_dust_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = DUST_TEXTURE
	mat.albedo_color = Color(1.0, 1.0, 1.0, DUST_OPACITY)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = false
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## The mesh the dust shell duplicates: the authored model's mesh when present, else the placeholder
## medallion sphere.
func _dust_source_mesh() -> Mesh:
	if model_mesh != null:
		return model_mesh
	if _model_instance != null:
		var mi := _find_mesh_instance(_model_instance)
		if mi != null:
			return mi.mesh
	if _medallion != null:
		return _medallion.mesh
	return null


## Scale to apply to the source mesh so the shell lines up with what is actually rendered.
func _dust_source_scale() -> float:
	if model_mesh != null or _model_instance != null:
		return model_scale
	return 1.0


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


func _clear_dust_overlay() -> void:
	if _dust_overlay != null and is_instance_valid(_dust_overlay):
		_dust_overlay.queue_free()
	_dust_overlay = null
	_dust_verts = PackedVector3Array()
	_dust_centroids = PackedVector3Array()
	_dust_alive = PackedByteArray()
	_dust_initial = 0


# --- Authored condition overlays (smooth, UV-textured, dev-placed) -----------
# Dev-placed ArtifactOverlay nodes (dust / rust / cracking). Each is a textured shell of the model
# the tools erase smoothly via a UV keep-mask. RestorationObject3D builds them from its mesh and
# turns pointer rays into the model UV so erasing lands per-texel (not blocky per-triangle).


## Builds every authored ArtifactOverlay child from the model mesh, and caches the model's
## triangles+UVs for the ray->UV used to erase them. Runtime only.
func build_overlays(seed_value: int = 0) -> void:
	if Engine.is_editor_hint():
		return
	var mesh := _dust_source_mesh()
	var scale := _dust_source_scale()
	for overlay in _find_overlays(self):
		# Offset the seed per layer so each condition rolls its OWN coverage/pattern on the same
		# artifact, while two different instances (different seed_value) differ overall.
		var s: int = seed_value ^ (int(overlay.layer_order) * 73856093)
		overlay.build_with_fallback(mesh, scale, s)


func has_overlays() -> bool:
	return not _find_overlays(self).is_empty()


## Captures every authored overlay's per-vertex keep (cleaning progress) by node name, so the bench
## can restore it after switching artifacts. Empty when there are no built overlays.
func capture_overlay_keep() -> Dictionary:
	var out := {}
	for overlay in _find_overlays(self):
		if overlay.is_built():
			out[String(overlay.name)] = overlay.get_keep()
	return out


## Restores overlay keep states captured earlier (after build_overlays has rebuilt the shells).
func apply_overlay_keep(state: Dictionary) -> void:
	for overlay in _find_overlays(self):
		var key := String(overlay.name)
		if state.has(key):
			overlay.set_keep(state[key])


## Cleans authored overlays where a pointer ray meets them, by 3D position (correct area, smooth) —
## NOT by UV. Tries outer-to-inner (by layer_order) and cleans the first layer the ray actually hits,
## so once the outer layer is cleaned away there (a hole), the stroke peels the layer below. Returns
## true when something was cleaned.
func clean_overlays_ray(origin: Vector3, direction: Vector3) -> bool:
	var overlays := _find_overlays(self)
	overlays.sort_custom(func(a: Node, b: Node) -> bool: return a.layer_order > b.layer_order)
	for overlay in overlays:
		if overlay.is_built() and overlay.clean_ray(origin, direction):
			return true
	return false


## Cleans overlays with a REAL tool: finds the outermost overlay the ray meets whose condition the
## tool can clean (`cleans`{condition_id: power 0-100}), and fades it by that power at `radius_frac`.
## Returns {cleaned, condition_id, fully_cleaned} on success, or {cleaned:false, wrong_tool} when the
## ray meets overlays but the tool can clean none of them.
func clean_overlays_with_tool(
	origin: Vector3, direction: Vector3, cleans: Dictionary, radius_frac: float
) -> Dictionary:
	var overlays := _find_overlays(self)
	overlays.sort_custom(func(a: Node, b: Node) -> bool: return a.layer_order > b.layer_order)
	var any_hit := false
	for overlay in overlays:
		if not overlay.is_built() or not overlay.ray_hits(origin, direction):
			continue
		any_hit = true
		var cond := String(overlay.get_condition_id())
		var power := int(cleans.get(cond, 0))
		if power > 0:
			# Only counts as a clean (puff + wear) if dirt actually came off here — scrubbing an
			# already-clean spot does nothing.
			var changed: bool = overlay.clean_ray(origin, direction, clampf(power / 100.0, 0.0, 1.0), radius_frac)
			return {
				"cleaned": changed,
				"condition_id": cond,
				"fully_cleaned": overlay.cleaned_fraction() >= 0.999,
				"point": overlay.ray_hit_point(origin, direction),
			}
	return {"cleaned": false, "wrong_tool": any_hit}


## A small dust puff burst at a WORLD point on the artifact (the spot the tool just cleaned).
func clean_burst_at_world(world_point: Vector3) -> void:
	if Engine.is_editor_hint():
		return
	if _clean_puff == null or not is_instance_valid(_clean_puff):
		_clean_puff = GPUParticles3D.new()
		_clean_puff.name = "CleanPuff"
		_clean_puff.emitting = false
		_clean_puff.one_shot = true
		_clean_puff.amount = 16
		_clean_puff.lifetime = 0.6
		_clean_puff.explosiveness = 0.9
		_clean_puff.local_coords = false  # particles fly in world space, not with the rotating artifact
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 0.03
		mat.direction = Vector3(0.0, 1.0, 0.0)
		mat.spread = 65.0
		mat.initial_velocity_min = 0.3
		mat.initial_velocity_max = 0.85
		mat.gravity = Vector3(0.0, -0.5, 0.0)
		mat.scale_min = 0.4
		mat.scale_max = 1.0
		mat.color = Color(0.6, 0.55, 0.45, 1.0)
		_clean_puff.process_material = mat
		var fleck := SphereMesh.new()
		fleck.radius = 0.012
		fleck.height = 0.024
		fleck.radial_segments = 6
		fleck.rings = 3
		_clean_puff.draw_pass_1 = fleck
		add_child(_clean_puff)
	_clean_puff.global_position = world_point
	_clean_puff.restart()
	_clean_puff.emitting = true


## Overall clean progress 0..1 across ALL spawned overlay conditions, weighted by how much each one
## spawned (so the sidebar can show a smooth ??% rather than per-condition steps). 1.0 when nothing
## spawned. Crack/never-spawned overlays contribute nothing.
func overlay_clean_percent() -> float:
	var total := 0.0
	var cleaned := 0.0
	for overlay in _find_overlays(self):
		if not overlay.is_built():
			continue
		total += overlay.initial_keep_amount()
		cleaned += overlay.cleaned_amount()
	if total <= 0.0:
		return 1.0
	return clampf(cleaned / total, 0.0, 1.0)


## Pulses the overlays the held tool can clean (condition in `cleans` with power > 0) at `intensity`,
## leaving the others dark — a learning cue so the player can spot e.g. dust on a same-coloured silver
## artifact when a dust tool is equipped.
func highlight_overlays(cleans: Dictionary, intensity: float) -> void:
	for overlay in _find_overlays(self):
		if not overlay.is_built():
			continue
		var on := int(cleans.get(String(overlay.get_condition_id()), 0)) > 0
		overlay.set_highlight(intensity if on else 0.0)


## Instantly clears every overlay whose condition is NOT in `except_conditions` (the auto-finish at
## 99% wipes dust/tarnish/rust but leaves crack, which represents damage).
func force_clean_overlays(except_conditions: Array) -> void:
	for overlay in _find_overlays(self):
		if overlay.is_built() and not except_conditions.has(String(overlay.get_condition_id())):
			overlay.clear_condition()


## {total, cleaned}: how many overlay conditions this artifact has and how many are fully cleaned
## (a condition that never spawned counts as cleaned). Drives condition/value + the clean->open gate.
func overlay_counts() -> Dictionary:
	var total := 0
	var cleaned := 0
	for overlay in _find_overlays(self):
		if not overlay.is_built():
			continue
		total += 1
		if overlay.cleaned_fraction() >= 0.999:
			cleaned += 1
	return {"total": total, "cleaned": cleaned}


func _find_overlays(root: Node) -> Array:
	# Duck-typed (build_with_fallback + clean_ray) so this @tool script needs no ArtifactOverlay ref.
	var out: Array = []
	for child in root.get_children():
		if child is Node3D and child.has_method("build_with_fallback") and child.has_method("clean_ray"):
			out.append(child)
		out.append_array(_find_overlays(child))
	return out


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
		# Stay interactive even when the placeholder box is hidden under an authored model.
		_clasp.visible = value and not _suppress_clasp_visual
		var mat := _clasp.material_override as StandardMaterial3D
		if mat != null:
			# Subtle highlight invites interaction; not a carrier tell (every clean
			# openable shows the same prompt regardless of contents).
			mat.emission_enabled = value and not _suppress_clasp_visual


func set_clasp_open(value: bool) -> void:
	if _clasp == null:
		return
	_clasp.visible = (value or _clasp_interactive) and not _suppress_clasp_visual
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
	var hit := _ray_sphere(
		origin, direction, _medallion.global_position, _radius * _authored_scale
	)
	if not hit.get("hit", false):
		return {"hit": false}
	var local: Vector3 = _medallion.to_local(hit["point"])
	return {"hit": true, "point": hit["point"], "uv": _local_to_uv(local)}


## Ray test against the clasp hotspot. Only hits while the clasp is interactive.
func ray_test_clasp(origin: Vector3, direction: Vector3) -> Dictionary:
	if not _clasp_interactive or _clasp == null:
		return {"hit": false}
	return _ray_sphere(origin, direction, _clasp.global_position, _clasp_radius * _authored_scale)


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
## builds one projected Decal per authored blemish. `colors` maps a blemish type to
## its placeholder tint; `removed_ids` hides already-cleaned blemishes so a reopened
## photo reconstructs saved progress.
func enter_photo_mode(
	decals: Array,
	removed_ids: Array,
	colors: Dictionary,
	textures: Dictionary = {},
	seed_value: int = 0
) -> void:
	if not _built:
		_build()
	_set_photo_mode(true)
	_clear_blemishes()
	_seed_layout(seed_value)
	# The photo plane faces +Z, so every decal projects straight onto its front face.
	_spawn_decals(decals, removed_ids, colors, textures, Vector3.BACK, _blemish_layout)
	reset_orientation()


## Scatters condition decals over the visible 3D object surface. Unlike photo mode
## this keeps the medallion + clasp, so the clean->open flow still works once every
## condition is removed. The medallion itself reads clean — the decals are the only
## dirt — so progress is communicated entirely by the discrete spots.
func enter_conditions_mode(
	decals: Array,
	removed_ids: Array,
	colors: Dictionary,
	textures: Dictionary = {},
	seed_value: int = 0
) -> void:
	if not _built:
		_build()
	_set_photo_mode(false)
	_conditions_mode = true
	set_fully_clean()
	_clear_blemishes()
	_seed_layout(seed_value)
	# Conditions wrap the sphere, so each decal projects along its own outward normal.
	_spawn_decals(decals, removed_ids, colors, textures, Vector3.ZERO, _condition_layout)
	reset_orientation()


## Sets the per-instance layout phase from a seed (e.g. the instance uid) so the same
## template's conditions scatter to different spots on different artifacts.
func _seed_layout(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_layout_phase = rng.randf() * TAU


## Builds one grime decal per mark. `fixed_normal` is the projection normal for flat
## templates (the photo plane); pass Vector3.ZERO to face each decal along its own
## outward surface normal (conditions on the sphere). `textures` maps a condition type
## to its authored PNG; `layout` returns a local centre for decal `index` of `count`.
func _spawn_decals(
	decals: Array,
	removed_ids: Array,
	colors: Dictionary,
	textures: Dictionary,
	fixed_normal: Vector3,
	layout: Callable
) -> void:
	var count := decals.size()
	var index := 0
	for decal in decals:
		var center: Vector3 = layout.call(index, count)
		var normal := fixed_normal if fixed_normal != Vector3.ZERO else center.normalized()
		var node := _make_decal(
			center, colors.get(decal.type, Color(0.5, 0.5, 0.5)), normal, textures.get(decal.type)
		)
		add_child(node)
		var removed: bool = removed_ids.has(decal.id)
		node.visible = not removed and not HIDE_DECALS
		_blemishes[decal.id] = {
			"node": node, "center": center, "removed": removed, "required_tool": decal.required_tool
		}
		index += 1


## True when discrete condition/blemish hotspots drive cleaning (photo OR conditions
## mode), so the view routes clicks to hotspot cleaning rather than a dirt stroke.
func is_decal_mode() -> bool:
	return _photo_mode or _conditions_mode


func is_condition_mode() -> bool:
	return _conditions_mode


## Scatters hotspot `index` of `count` across the front of the sphere surface, a
## little proud of it, so they are visible and clickable without rotating.
func _condition_layout(index: int, count: int) -> Vector3:
	var golden := PI * (3.0 - sqrt(5.0))
	var t := (float(index) + 0.5) / float(maxi(count, 1))
	# _layout_phase (seeded per instance) rotates the spiral and jitters height so the
	# same template's conditions land in different spots on different artifacts.
	var y := clampf(
		lerpf(0.6, -0.6, t) + sin(_layout_phase * 3.0 + float(index)) * 0.08, -0.82, 0.82
	)
	var ring := sqrt(maxf(0.0, 1.0 - y * y))
	var theta := golden * float(index) + _layout_phase
	var x := cos(theta) * ring
	var z := absf(sin(theta) * ring) + 0.2
	return Vector3(x, y, z).normalized() * (_radius + BLEMISH_RADIUS * 0.4)


func _set_photo_mode(enabled: bool) -> void:
	_conditions_mode = false
	_photo_mode = enabled
	# A custom model_scene keeps the placeholder medallion/bail hidden (the sphere is only
	# the invisible hit-test proxy); otherwise the placeholder shows outside photo mode.
	var show_placeholder := not enabled and _model_instance == null
	if _medallion != null:
		_medallion.visible = show_placeholder
	if _bail != null:
		_bail.visible = show_placeholder
	if _model_instance != null:
		_model_instance.visible = not enabled
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


## Ray test against the still-present blemish decals. Returns {hit, blemish_id,
## point}. Analytic (ray-sphere) so it runs headlessly, like the surface test; uses
## the logical `removed` flag so a cleaned decal is unhittable the instant it goes,
## independent of the cosmetic fade-out.
func ray_test_blemish(origin: Vector3, direction: Vector3) -> Dictionary:
	var best := {"hit": false}
	var best_t := INF
	for blemish_id in _blemishes.keys():
		var entry: Dictionary = _blemishes[blemish_id]
		if entry.get("removed", false):
			continue
		var center: Vector3 = to_global(entry["center"])
		var hit := _ray_sphere(origin, direction, center, BLEMISH_RADIUS * _authored_scale)
		if hit.get("hit", false) and hit["t"] < best_t:
			best_t = hit["t"]
			best = {"hit": true, "blemish_id": blemish_id, "point": hit["point"]}
	return best


## The per-stroke grime puff for a blemish (every tool use, right tool or wrong).
func blemish_working_burst(blemish_id: String) -> void:
	if not _blemishes.has(blemish_id):
		return
	var node: Variant = _blemishes[blemish_id]["node"]
	if node != null and node.has_method("working_burst"):
		node.working_burst()


## Marks a cleaned blemish removed and plays its success sparkle + fade. Presentation
## only; the view calls this after RestorationService confirms the tool removed it.
func remove_blemish(blemish_id: String) -> void:
	if not _blemishes.has(blemish_id):
		return
	var entry: Dictionary = _blemishes[blemish_id]
	entry["removed"] = true
	var node: Variant = entry["node"]
	if node == null:
		return
	# A big "power" fully clears the dirt in one go (the service is single-stroke),
	# which triggers the sparkle and hides the decal.
	if node.has_method("apply_clean"):
		node.apply_clean(99999)
	else:
		node.visible = false


## A still-dirty blemish id for controller/keyboard cleaning (auto-target), or "".
func auto_target_blemish_id() -> String:
	for blemish_id in _blemishes.keys():
		if not _blemishes[blemish_id].get("removed", false):
			return blemish_id
	return ""


## Test/integration seam: ids of blemishes not yet cleaned.
func get_visible_blemish_ids() -> Array[String]:
	var out: Array[String] = []
	for blemish_id in _blemishes.keys():
		if not _blemishes[blemish_id].get("removed", false):
			out.append(blemish_id)
	return out


## Test/integration seam: world-space centre of a blemish hotspot (for aiming a ray).
func get_blemish_global_center(blemish_id: String) -> Vector3:
	if _blemishes.has(blemish_id):
		return to_global(_blemishes[blemish_id]["center"])
	return Vector3.ZERO


func has_visible_blemishes() -> bool:
	for blemish_id in _blemishes.keys():
		if not _blemishes[blemish_id].get("removed", false):
			return true
	return false


func _clear_blemishes() -> void:
	for blemish_id in _blemishes.keys():
		var node: Node3D = _blemishes[blemish_id]["node"]
		if node != null:
			node.queue_free()
	_blemishes.clear()


# --- Author-placed condition decals ------------------------------------------
# Decals a dev drops into the artifact scene (ArtifactConditionDecal). Their type
# comes from the albedo file name; here we resolve it to the journal condition so we
# can tint the decal and know which tool cleans it. These coexist with the data-
# driven blemishes above and are cleaned through the same view, with particles.


## Discovers ArtifactConditionDecal children, resolves each to a journal surface condition
## (its TYPE comes from the texture's file name, e.g. Rust.png -> rust -> the wire/rust
## brush), tints it, and registers it as a cleanable hotspot AT ITS AUTHORED POSITION.
## Idempotent: safe to call again on reload (cleaned ones keep their removed flag).
## `seed_value` (instance uid + loop) only drives which decals are active this run
## (randomized_decal_count) and resets dirt; it does NOT move the decals.
func register_authored_conditions(repo: DataRepository, seed_value: int = 0) -> void:
	_authored.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var all := _find_authored_decals(self)
	# Randomly pick which placed conditions are live this run (seeded per save + loop).
	var active := _choose_active_decals(all, rng)
	for raw in all:
		var decal: Variant = raw
		# Inactive decals (this run rolled fewer than were placed) are hidden and not
		# cleanable — they may be picked on a different loop.
		if not active.has(decal):
			decal.visible = false
			continue
		# Registered + cleanable as before, but hidden while HIDE_DECALS is on (the dust shell
		# is the visible grime now). The clean/condition LOGIC is unchanged, so gameplay + tests
		# that drive cleaning through the service still hold.
		decal.visible = not HIDE_DECALS
		# Duck-typed (no static ArtifactConditionDecal reference) so this @tool script
		# always compiles in the editor and the artifact geometry still builds there.
		if decal.has_method("reset"):
			decal.reset()  # fresh dirt for this artifact
		var slug: String = decal.condition_slug()
		var condition := _match_condition(repo, slug)
		var color := Color(0.6, 0.6, 0.6)
		var required_tool := ""
		var type_id := slug
		if condition != null:
			color = condition.to_color()
			required_tool = condition.cleaning_tool
			type_id = condition.id
		decal.tint(color)
		# Keep the decal EXACTLY where the dev placed it in the artifact scene (its authored
		# transform). Positions/rotations set in the editor carry straight into the game; the
		# only randomisation is WHICH decals are active (randomized_decal_count above).
		_authored[decal.name] = {
			"node": decal,
			"required_tool": required_tool,
			"type_id": type_id,
			"removed": decal.is_cleaned(),
		}


## Ray-tests the uncleaned authored decals. Returns {hit, condition_id}.
func ray_test_authored(origin: Vector3, direction: Vector3) -> Dictionary:
	var best := {"hit": false}
	var best_t := INF
	for condition_id in _authored.keys():
		var entry: Dictionary = _authored[condition_id]
		if entry["removed"]:
			continue
		# Duck-typed (ArtifactConditionDecal) so this @tool script needs no class ref.
		var decal: Variant = entry["node"]
		if decal == null:
			continue
		var radius: float = decal.pick_radius() * _authored_scale
		var center: Vector3 = decal.global_position
		var hit := _ray_sphere(origin, direction, center, radius)
		if hit.get("hit", false) and hit["t"] < best_t:
			best_t = hit["t"]
			best = {"hit": true, "condition_id": condition_id}
	return best


## The tool id that cleans the given authored condition ("" when its type is unknown).
func authored_required_tool(condition_id: String) -> String:
	return str(_authored.get(condition_id, {}).get("required_tool", ""))


## The resolved condition type id of an authored decal (for feedback text).
func authored_type_id(condition_id: String) -> String:
	return str(_authored.get(condition_id, {}).get("type_id", ""))


## Plays the per-stroke grime puff on an authored condition (every tool use).
func authored_working_burst(condition_id: String) -> void:
	if not _authored.has(condition_id):
		return
	var decal: Variant = _authored[condition_id]["node"]
	if decal != null and decal.has_method("working_burst"):
		decal.working_burst()


## Applies one correct-tool stroke of `power` to an authored condition: fades it a
## step and, once fully cleaned, plays the success sparkle. Returns true when cleaned.
func apply_authored_clean(condition_id: String, power: int) -> bool:
	if not _authored.has(condition_id):
		return false
	var entry: Dictionary = _authored[condition_id]
	var decal: Variant = entry["node"]
	if decal == null or not decal.has_method("apply_clean"):
		return false
	var cleaned: bool = decal.apply_clean(power)
	if cleaned:
		entry["removed"] = true
	return cleaned


## Optional learning cue: throbs the conditions (authored OR data-driven) that `tool_id`
## can clean, at the given pulse `intensity` (0..1); every other condition goes quiet. Pass
## tool_id "" or intensity 0 to clear. Presentation only — never moves the dev-placed decals.
func highlight_for_tool(tool_id: String, intensity: float) -> void:
	if _authored.is_empty() and _blemishes.is_empty():
		return
	for condition_id in _authored.keys():
		var entry: Dictionary = _authored[condition_id]
		var decal: Variant = entry["node"]
		if decal != null and decal.has_method("set_highlight"):
			var matched := tool_id != "" and str(entry.get("required_tool", "")) == tool_id
			decal.set_highlight(intensity if matched else 0.0)
	for blemish_id in _blemishes.keys():
		var b: Dictionary = _blemishes[blemish_id]
		var node: Variant = b["node"]
		if node != null and node.has_method("set_highlight"):
			var hit := tool_id != "" and str(b.get("required_tool", "")) == tool_id
			node.set_highlight(intensity if hit else 0.0)


func has_authored_conditions() -> bool:
	return not _authored.is_empty()


## How many author-placed conditions are live on this run (after randomisation).
func authored_active_count() -> int:
	return _authored.size()


## The active-decal limit: the "Max Decals: N" directive from `customization` when present
## (authoritative — author it per artifact), otherwise the legacy randomized_decal_count.
## <= 0 means "show all".
func _active_decal_limit() -> int:
	var directive := _max_decals_directive()
	return directive if directive >= 0 else randomized_decal_count


## Parses the "Max Decals: N" line out of `customization` (case-insensitive). Returns the
## integer N, or -1 when no such directive is present so callers fall back to the legacy
## field. More directives can be added here later (the rest of `customization` is ignored).
func _max_decals_directive() -> int:
	for raw_line in customization.split("\n", false):
		var line := raw_line.strip_edges()
		if not line.to_lower().begins_with("max decals"):
			continue
		var colon := line.find(":")
		if colon == -1:
			continue
		var value := line.substr(colon + 1).strip_edges()
		if value.is_valid_int():
			return value.to_int()
	return -1


## Chooses which placed decals are live this run. With the limit <= 0 or >= the number
## placed, every decal is used; otherwise a seeded shuffle picks that many, so the same
## relic shows a different subset each loop / save.
func _choose_active_decals(all: Array, rng: RandomNumberGenerator) -> Array:
	var limit := _active_decal_limit()
	if limit <= 0 or limit >= all.size():
		return all
	var pool := all.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, limit)


## Test/integration seam: ids of authored conditions not yet cleaned.
func uncleaned_authored_ids() -> Array[String]:
	var out: Array[String] = []
	for condition_id in _authored.keys():
		if not _authored[condition_id]["removed"]:
			out.append(condition_id)
	return out


## Test/integration seam: world-space centre of an authored decal (for aiming a ray).
func get_authored_global_center(condition_id: String) -> Vector3:
	if _authored.has(condition_id):
		return (_authored[condition_id]["node"] as Node3D).global_position
	return Vector3.ZERO


func _find_authored_decals(root: Node) -> Array:
	# Identified by behaviour (a Node3D exposing condition_slug) rather than the
	# ArtifactConditionDecal class, so this @tool script carries no class dependency.
	# Runtime data-driven decals are excluded purely by the `data_blemish` meta tag
	# (set in _make_decal), so authored nodes can be named anything ending in "Decal" —
	# including names that collide with the runtime decal — without being skipped.
	var found: Array = []
	for child in root.get_children():
		if (
			child is Node3D
			and child.has_method("condition_slug")
			and not child.has_meta("data_blemish")  # runtime data-driven blemish, not authored
			and not child.is_queued_for_deletion()  # a blemish being cleared this frame
		):
			found.append(child)
		found.append_array(_find_authored_decals(child))
	return found


func _match_condition(repo: DataRepository, slug: String) -> SurfaceCondition:
	if repo == null or slug.is_empty():
		return null
	for raw in repo.get_surface_conditions_sorted():
		var condition := raw as SurfaceCondition
		if condition == null:
			continue
		if slug == condition.id or slug == _slug(condition.display_name):
			return condition
	return null


static func _slug(text: String) -> String:
	return text.to_lower().replace(" ", "_").replace("-", "_")


## Lays blemishes out in a tidy grid across the photo face, slightly proud of it.
func _blemish_layout(index: int, count: int) -> Vector3:
	var cols := maxi(1, int(ceil(sqrt(float(count)))))
	var rows := maxi(1, int(ceil(float(count) / float(cols))))
	var col := index % cols
	var row := index / cols
	var fx := (float(col) + 0.5) / float(cols)
	var fy := (float(row) + 0.5) / float(rows)
	var x := lerpf(-PHOTO_HALF_W * 0.7, PHOTO_HALF_W * 0.7, fx) + sin(_layout_phase + index) * 0.05
	var y := (
		lerpf(PHOTO_HALF_H * 0.7, -PHOTO_HALF_H * 0.7, fy) + cos(_layout_phase * 1.3 + index) * 0.04
	)
	return Vector3(x, y, 0.04)


## True when the renderer can draw engine Decal nodes (Forward+/Mobile have a
## RenderingDevice; gl_compatibility / OpenGL does not). The condition decal scene
## picks the right visual internally; kept for callers/tests that ask.
static func decals_supported() -> bool:
	return RenderingServer.get_rendering_device() != null


## Builds one data-driven condition as an ArtifactConditionDecal instance — the same
## scene devs place by hand — so it carries the correct condition texture, the grime
## puff / sparkle particles, and the dirt fade. `normal` is the outward surface normal
## it faces. Tinted to the condition's journal colour. Returns the instanced node.
func _make_decal(center: Vector3, color: Color, normal: Vector3, texture: Texture2D) -> Node3D:
	var node: Variant = CONDITION_DECAL_SCENE.instantiate()
	# In game we call these "conditions"; authored scene nodes are named "*Decal".
	node.name = "RuntimeCondition"
	# Tagged so register_authored_conditions never mistakes a runtime data-driven condition
	# for an author-placed decal (this meta tag — not the node name — is the discriminator).
	node.set_meta("data_blemish", true)
	node.align_to_surface = false  # we orient it explicitly below
	node.box_size = BLEMISH_RADIUS * 2.6
	if texture != null:
		node.texture = texture
	node.tint(color)
	node.position = center
	_orient_sticker(node, normal)
	return node


## Aligns a flat decal quad's face (+Z, the QuadMesh normal) to the surface normal so
## the sticker lies flush against the surface at that point.
func _orient_sticker(node: Node3D, normal: Vector3) -> void:
	var n := normal.normalized()
	if n.is_zero_approx():
		return
	var reference := Vector3.RIGHT if absf(n.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x_axis := reference.cross(n).normalized()
	var y_axis := n.cross(x_axis).normalized()
	node.basis = Basis(x_axis, y_axis, n)


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
	_ensure_paint_layer()

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
	_apply_authored_model()


## Instances `model_scene` (if set) as the visible artifact and hides the placeholder
## medallion + bail. The placeholder sphere stays in the tree (invisible) so the view's
## analytic rotate/clean hit-testing still works against it. Idempotent.
func _apply_authored_model() -> void:
	if _model_instance != null and is_instance_valid(_model_instance):
		_model_instance.queue_free()
		_model_instance = null
	var has_model := model_scene != null or model_mesh != null
	# Hide the placeholder clasp box when a real model is shown (it floats and clashes).
	_suppress_clasp_visual = has_model
	if _clasp != null and has_model:
		_clasp.visible = false
	if _medallion != null:
		_medallion.visible = not has_model
	if _bail != null:
		_bail.visible = not has_model
	if not has_model:
		return
	# model_scene (.glb, a PackedScene with materials) wins; otherwise wrap the bare
	# model_mesh (.obj) in a MeshInstance3D.
	if model_scene != null:
		var inst: Node = model_scene.instantiate()
		if inst is Node3D:
			_model_instance = inst
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = model_mesh
		if model_material != null:
			mi.material_override = model_material
		_model_instance = mi
	if _model_instance == null:
		return
	_model_instance.name = "Model"
	_model_instance.scale = Vector3.ONE * model_scale
	add_child(_model_instance)


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

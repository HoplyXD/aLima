@tool
class_name ArtifactOverlay
extends Node3D
## An authored, editable condition overlay (dust / rust-tarnish / cracking) a dev drops into an
## artifact scene. It shows `overlay_mesh` (move/scale this node freely to fit), textured with a
## condition texture and half-transparent over the model.
##
## CLEANING IS BY 3D POSITION, NOT UV: the artifact models share/mirror their UVs heavily, so a
## UV-based erase cleans the wrong spots. Instead each vertex carries a "keep" alpha; cleaning fades
## the vertices within the tool radius of the 3D point the tool meets, so exactly the area under the
## tool clears (and the fade is smooth across faces, not blocky). Layers stack by `layer_order`
## (higher = outer / cleaned first): Dust 30, Rust/Tarnish 20, Cracking 10.
##
## @tool: the shell builds in the editor too, so the overlay is visible while you position it. The
## inner OverlayShell is an INTERNAL child (never saved/duplicated into the .tscn).

## condition_tex * per-vertex keep (COLOR.a) * opacity. No UV is used for cleaning, only for the look.
const SHADER := "shader_type spatial;\nrender_mode blend_mix, cull_back, depth_draw_opaque, diffuse_lambert;\nuniform sampler2D condition_tex : source_color, filter_linear;\nuniform float overlay_opacity : hint_range(0.0, 1.0) = 0.9;\nuniform float highlight = 0.0;\nuniform vec4 highlight_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);\nuniform bool use_triplanar = false;\nuniform float triplanar_scale = 0.5;\nvarying vec3 v_pos;\nvarying vec3 v_norm;\nvoid vertex() {\n\tv_pos = VERTEX;\n\tv_norm = NORMAL;\n}\nvec4 sample_tri(vec3 p, vec3 n) {\n\tvec3 b = abs(normalize(n));\n\tb /= (b.x + b.y + b.z + 1e-5);\n\tvec4 cx = texture(condition_tex, p.zy * triplanar_scale);\n\tvec4 cy = texture(condition_tex, p.xz * triplanar_scale);\n\tvec4 cz = texture(condition_tex, p.xy * triplanar_scale);\n\treturn cx * b.x + cy * b.y + cz * b.z;\n}\nvoid fragment() {\n\tvec4 c = use_triplanar ? sample_tri(v_pos, v_norm) : texture(condition_tex, UV);\n\tfloat base = c.a * COLOR.a;\n\tALBEDO = c.rgb;\n\tEMISSION = highlight_color.rgb * highlight * base;\n\tALPHA = clamp(base * overlay_opacity + highlight * base * 0.6, 0.0, 1.0);\n}\n"
const PATTERN_BLOB_RADIUS: float = 0.16  ## Dirt-blob radius as a fraction of the mesh extent.
const PATTERN_BLOB_CORE: float = 0.35  ## Solid-core fraction of each blob; the rest is a soft edge.
const MAX_BLOBS: int = 8000  ## Safety cap on blob stamps while filling toward the target coverage.
## Low-poly meshes (e.g. the 260-vert death mask) clean/pattern too coarsely (linear, not round), so
## the shell is subdivided at build until it has at least this many vertices (capped at 2 levels).
const MIN_VERTS: int = 2000
## Brush radius (fraction of overlay size) used ONLY when no tool radius is supplied — i.e. the debug
## eraser. Real cleaning passes the TOOL's clean_radius (see ToolConfig); the overlay no longer owns one.
const DEFAULT_CLEAN_RADIUS: float = 0.12
## The mesh to show as the overlay shell. Leave null to fall back to the artifact's own mesh.
@export var overlay_mesh: Mesh:
	set(value):
		overlay_mesh = value
		if _shell != null:  # only rebuild an already-shown shell; never during scene instantiation
			_rebuild()
@export var condition_texture: Texture2D:
	set(value):
		condition_texture = value
		if _material != null:
			_material.set_shader_parameter("condition_tex", value)
@export_range(0.0, 1.0) var opacity: float = 0.9:
	set(value):
		opacity = value
		if _material != null:
			_material.set_shader_parameter("overlay_opacity", value)
## The condition this overlay represents (e.g. "dust", "tarnish", "crack"). Leave blank to DERIVE it
## from the condition texture's file name (Rust.png -> rust, "Water Stain.png" -> water_stain,
## Cracking.png -> crack). A tool cleans this overlay only if its config lists this condition.
@export var condition_id: String = ""
## Higher layers sit outer and are cleaned first (dust 30 > rust 20 > cracking 10).
@export var layer_order: int = 30
## Random coverage range (PERCENT). At spawn each artifact instance rolls a value in [min, max] and
## generates a random patchy pattern covering that much of the surface — so two of the same artifact
## get different amounts/patterns of this condition. 0 = none, 100 = the whole surface. Default is a
## moderate random range so overlays that don't set it still spawn partial/varied (tune per layer).
@export_range(0.0, 100.0) var coverage_min: float = 20.0
@export_range(0.0, 100.0) var coverage_max: float = 60.0
## Sample the condition texture by TRIPLANAR projection (object axes) instead of the mesh UV. Turn ON
## for artifacts whose UVs are broken/stretched (e.g. the death mask) so the grime doesn't streak;
## leave OFF for clean-UV models (pendant/locket) which look perfect on their own UVs.
@export var triplanar: bool = false:
	set(value):
		triplanar = value
		if _material != null:
			_material.set_shader_parameter("use_triplanar", value)
## Triplanar texture tiling (only when `triplanar` is on); higher = more, smaller patches.
@export var triplanar_tiling: float = 3.0

var _shell: MeshInstance3D
var _material: ShaderMaterial
var _runtime_mesh: ArrayMesh
var _arrays: Array = []
var _verts: PackedVector3Array = PackedVector3Array()
var _tris: PackedInt32Array = PackedInt32Array()
var _extent: float = 1.0  ## Overlay size, so clean_radius is mesh-scale independent.
var _initial_keep: float = 0.0  ## Total keep at spawn, so cleaned_fraction is progress-relative.


func _ready() -> void:
	# Build the shell only in the EDITOR (so devs can position it). At runtime it is built on demand
	# by the bench (build_with_fallback) for the ONE artifact being cleaned — so card previews in the
	# delivery / storage / top-panel UIs instance the scene WITHOUT paying the overlay build cost.
	if Engine.is_editor_hint():
		_rebuild()


## Called by RestorationObject3D for the bench's active artifact: builds the shell now and rolls this
## instance's random coverage pattern from `seed` (so each artifact instance differs). When no
## overlay_mesh is authored, falls back to the artifact mesh (matched to its scale).
func build_with_fallback(source_mesh: Mesh, source_scale: float, seed: int = 0) -> void:
	if overlay_mesh == null and source_mesh != null:
		scale = Vector3.ONE * source_scale
		overlay_mesh = source_mesh
	_rebuild()
	_apply_pattern(seed)


## Rolls a coverage % in [coverage_min, coverage_max] (seeded) and writes a random patchy keep
## pattern covering that fraction of the surface. Deterministic for a given seed, so the same
## artifact regenerates the same pattern when reloaded.
func _apply_pattern(seed: int) -> void:
	if _arrays.is_empty():
		return
	var colors: PackedColorArray = _arrays[Mesh.ARRAY_COLOR]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var coverage := clampf(rng.randf_range(coverage_min, coverage_max) / 100.0, 0.0, 1.0)
	# Crack is disabled for now (it will only appear in DAMAGED areas once the durability/damage
	# system exists), so it never spawns regardless of its configured range.
	if get_condition_id() == "crack":
		coverage = 0.0
	var sum := 0.0
	if coverage >= 0.999:
		sum = float(colors.size())  # keep all (already white)
	elif coverage <= 0.001:
		for i in colors.size():
			colors[i].a = 0.0
	else:
		# Stamp random CIRCULAR dirt blobs (the same smooth radial falloff the cleaning brush makes)
		# until we hit the target coverage — so spawned grime reads as round patches, not faceted
		# noise. Overlapping blobs merge by max. Deterministic for a given seed.
		for i in colors.size():
			colors[i].a = 0.0
		var ext := maxf(0.001, _extent)
		var target := coverage * float(colors.size())
		var guard := 0
		while sum < target and guard < MAX_BLOBS:
			guard += 1
			var center := _verts[rng.randi_range(0, _verts.size() - 1)]
			var r := ext * PATTERN_BLOB_RADIUS * rng.randf_range(0.6, 1.4)
			var core := r * PATTERN_BLOB_CORE
			for i in _verts.size():
				if colors[i].a >= 0.999:
					continue
				var d := center.distance_to(_verts[i])
				if d > r:
					continue
				var add := 1.0 - smoothstep(core, r, d)
				if add <= colors[i].a:
					continue
				sum += add - colors[i].a
				colors[i].a = add
	_initial_keep = sum
	_arrays[Mesh.ARRAY_COLOR] = colors
	_runtime_mesh.clear_surfaces()
	_runtime_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)


## The current per-vertex keep (opacity) values, for caching the cleaning progress across a switch.
func get_keep() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if _arrays.is_empty():
		return out
	for c in (_arrays[Mesh.ARRAY_COLOR] as PackedColorArray):
		out.append(c.a)
	return out


## Restores a previously-captured keep array (same vertex count), so reopening an artifact keeps the
## player's cleaning progress, not just the spawn pattern.
func set_keep(keep: PackedFloat32Array) -> void:
	if _arrays.is_empty() or keep.size() != _verts.size():
		return
	var colors: PackedColorArray = _arrays[Mesh.ARRAY_COLOR]
	for i in colors.size():
		colors[i].a = keep[i]
	_arrays[Mesh.ARRAY_COLOR] = colors
	_runtime_mesh.clear_surfaces()
	_runtime_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)


## (Re)builds the editable shell from overlay_mesh with a fresh (uncleaned) per-vertex keep array.
## Merges ALL surfaces of the mesh (e.g. a pendant whose chain + body are separate surfaces), so the
## whole artifact is covered, not just surface 0.
func _rebuild() -> void:
	_clear()
	if overlay_mesh == null or overlay_mesh.get_surface_count() == 0:
		return
	if not _build_merged_arrays():
		return
	_subdivide_if_sparse()  # densify low-poly meshes so cleaning reads as smooth circles
	var colors := PackedColorArray()
	colors.resize(_verts.size())
	colors.fill(Color.WHITE)  # keep = 1 everywhere (fully dusty)
	_arrays[Mesh.ARRAY_COLOR] = colors
	_extent = _measure_extent(_verts)
	_runtime_mesh = ArrayMesh.new()
	_runtime_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	_material = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_material.shader = sh
	_material.set_shader_parameter("condition_tex", condition_texture)
	_material.set_shader_parameter("overlay_opacity", opacity)
	_material.set_shader_parameter("use_triplanar", triplanar)
	# Tiling is mesh-relative (divided by the mesh extent) so the same triplanar_tiling reads the same
	# on a big or small artifact. VERTEX in the shader is object-space (raw mesh units).
	_material.set_shader_parameter("triplanar_scale", triplanar_tiling / maxf(0.001, _extent))
	_shell = MeshInstance3D.new()
	_shell.name = "OverlayShell"
	_shell.mesh = _runtime_mesh
	_shell.material_override = _material
	# INTERNAL so the editor never saves/duplicates this generated child into the .tscn.
	add_child(_shell, false, Node.INTERNAL_MODE_BACK)


## Cleans where a world-space ray meets the shell: fades the keep alpha (opacity) of vertices within
## the tool radius of the 3D hit (smooth falloff). The geometry is left intact — only the per-vertex
## opacity drops — so cleaning never mutates the mesh shape (robust). `power` scales how much opacity
## is removed per stroke (1.0 = a full fade at the centre; a tool's per-condition power maps here, e.g.
## 0.5 = remove ~50% opacity). Returns true when anything faded.
func clean_ray(
	world_origin: Vector3, world_dir: Vector3, power: float = 1.0, radius_frac: float = -1.0
) -> bool:
	if _runtime_mesh == null or _shell == null:
		return false
	var inv := _shell.global_transform.affine_inverse()
	var lo: Vector3 = inv * world_origin
	var ld := (inv.basis * world_dir).normalized()
	var hit: Variant = _ray_hit(lo, ld)
	if hit == null:
		return false
	var center: Vector3 = hit
	# The radius comes from the tool (radius_frac); only the debug eraser falls back to a default.
	var rf := radius_frac if radius_frac >= 0.0 else DEFAULT_CLEAN_RADIUS
	var radius := rf * _extent
	var colors: PackedColorArray = _arrays[Mesh.ARRAY_COLOR]
	var changed := false
	for i in _verts.size():
		var d := _verts[i].distance_to(center)
		if d > radius:
			continue
		var new_a := maxf(0.0, colors[i].a - (1.0 - smoothstep(0.0, radius, d)) * maxf(0.0, power))
		if new_a < colors[i].a:
			colors[i].a = new_a
			changed = true
	if changed:
		_arrays[Mesh.ARRAY_COLOR] = colors
		_runtime_mesh.clear_surfaces()
		_runtime_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	return changed


func is_built() -> bool:
	return _shell != null


## The condition id a tool must be able to clean: the explicit `condition_id`, or one derived from the
## condition texture's file name (Cracking.png -> crack, Rust.png -> rust, Dust(2).png -> dust).
func get_condition_id() -> String:
	if not condition_id.is_empty():
		return condition_id
	if condition_texture == null:
		return ""
	var slug := condition_texture.resource_path.get_file().get_basename().to_lower()
	slug = slug.replace(" ", "_").replace("-", "_")
	if slug.begins_with("dust"):
		return "dust"  # "Dust(2)" and similar variants
	if slug == "cracking":
		return "crack"
	return slug


## True when a world-space ray meets this overlay's shell (no cleaning). Used to find which layer the
## tool is over, for tool/condition matching and wrong-tool feedback.
func ray_hits(world_origin: Vector3, world_dir: Vector3) -> bool:
	if _runtime_mesh == null or _shell == null:
		return false
	var inv := _shell.global_transform.affine_inverse()
	return _ray_hit(inv * world_origin, (inv.basis * world_dir).normalized()) != null


## The WORLD-space point where the ray meets this overlay (for spawning a clean puff there), or null.
func ray_hit_point(world_origin: Vector3, world_dir: Vector3) -> Variant:
	if _runtime_mesh == null or _shell == null:
		return null
	var inv := _shell.global_transform.affine_inverse()
	var hit: Variant = _ray_hit(inv * world_origin, (inv.basis * world_dir).normalized())
	if hit == null:
		return null
	return _shell.global_transform * (hit as Vector3)


## Fraction of the SPAWNED condition that has been cleaned (0 = untouched, 1 = spotless), relative to
## the random coverage this instance rolled — so a fresh overlay reads 0 regardless of coverage.
func cleaned_fraction() -> float:
	if _initial_keep <= 0.0:
		return 1.0
	if _arrays.is_empty():
		return 1.0
	var colors: PackedColorArray = _arrays[Mesh.ARRAY_COLOR]
	var sum := 0.0
	for c in colors:
		sum += c.a
	return clampf(1.0 - sum / _initial_keep, 0.0, 1.0)


## Approximate fraction of the surface this condition covers at spawn (test/UI seam).
func coverage_fraction() -> float:
	if _arrays.is_empty():
		return 0.0
	var colors: PackedColorArray = _arrays[Mesh.ARRAY_COLOR]
	return _initial_keep / float(maxi(1, colors.size()))


## How much condition this overlay STARTED with (the spawn amount), for a weighted overall clean %.
func initial_keep_amount() -> float:
	return _initial_keep


## How much of the spawned condition has been cleaned off so far.
func cleaned_amount() -> float:
	if _arrays.is_empty():
		return 0.0
	var colors: PackedColorArray = _arrays[Mesh.ARRAY_COLOR]
	var sum := 0.0
	for c in colors:
		sum += c.a
	return maxf(0.0, _initial_keep - sum)


## Glows the overlay (its dirt pulses brighter + a touch more opaque) as a learning cue that the
## held tool can clean this condition. 0 = off. Presentation only.
func set_highlight(intensity: float) -> void:
	if _material != null:
		_material.set_shader_parameter("highlight", clampf(intensity, 0.0, 1.0))


## Instantly clears this condition (used by the auto-finish at 99%).
func clear_condition() -> void:
	if _arrays.is_empty():
		return
	var colors: PackedColorArray = _arrays[Mesh.ARRAY_COLOR]
	for i in colors.size():
		colors[i].a = 0.0
	_arrays[Mesh.ARRAY_COLOR] = colors
	if _runtime_mesh != null:
		_runtime_mesh.clear_surfaces()
		_runtime_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)


## Nearest local-space point where the ray meets a triangle, or null on a miss.
func _ray_hit(lo: Vector3, ld: Vector3) -> Variant:
	var idx := _tris
	if idx.is_empty():  # non-indexed mesh: every 3 verts is a triangle
		idx = PackedInt32Array()
		for i in _verts.size():
			idx.append(i)
	var best_t := INF
	var best: Variant = null
	for i in range(0, idx.size() - 2, 3):
		var p: Variant = Geometry3D.ray_intersects_triangle(
			lo, ld, _verts[idx[i]], _verts[idx[i + 1]], _verts[idx[i + 2]]
		)
		if p != null:
			var t: float = lo.distance_to(p as Vector3)
			if t < best_t:
				best_t = t
				best = p
	return best


## Combines every surface of overlay_mesh into one indexed set in _arrays (+ _verts/_tris). Per-vertex
## normals/UVs are kept only when every surface provides them, so the merged arrays stay consistent.
func _build_merged_arrays() -> bool:
	var all_verts := PackedVector3Array()
	var all_normals := PackedVector3Array()
	var all_uvs := PackedVector2Array()
	var all_indices := PackedInt32Array()
	var has_normals := true
	var has_uvs := true
	for s in overlay_mesh.get_surface_count():
		var arrays := overlay_mesh.surface_get_arrays(s)
		if arrays.size() <= Mesh.ARRAY_VERTEX or not (arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array):
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		var base := all_verts.size()
		all_verts.append_array(verts)
		var raw_n: Variant = arrays[Mesh.ARRAY_NORMAL]
		if raw_n is PackedVector3Array and (raw_n as PackedVector3Array).size() == verts.size():
			all_normals.append_array(raw_n)
		else:
			has_normals = false
		var raw_u: Variant = arrays[Mesh.ARRAY_TEX_UV]
		if raw_u is PackedVector2Array and (raw_u as PackedVector2Array).size() == verts.size():
			all_uvs.append_array(raw_u)
		else:
			has_uvs = false
		var raw_i: Variant = arrays[Mesh.ARRAY_INDEX]
		if raw_i is PackedInt32Array and not (raw_i as PackedInt32Array).is_empty():
			for i in (raw_i as PackedInt32Array):
				all_indices.append(base + i)
		else:
			for i in verts.size():
				all_indices.append(base + i)
	if all_verts.is_empty():
		return false
	_arrays = []
	_arrays.resize(Mesh.ARRAY_MAX)
	_arrays[Mesh.ARRAY_VERTEX] = all_verts
	if has_normals and all_normals.size() == all_verts.size():
		_arrays[Mesh.ARRAY_NORMAL] = all_normals
	if has_uvs and all_uvs.size() == all_verts.size():
		_arrays[Mesh.ARRAY_TEX_UV] = all_uvs
	_arrays[Mesh.ARRAY_INDEX] = all_indices
	_verts = all_verts
	_tris = all_indices
	return true


## Splits each triangle into 4 (midpoint subdivision) until the shell has >= MIN_VERTS vertices, so a
## coarse mesh cleans/patterns smoothly. Independent per-triangle split (duplicate midpoints) — fine
## for the per-vertex shader, and cheap at these sizes.
func _subdivide_if_sparse() -> void:
	var levels := 0
	while _verts.size() < MIN_VERTS and levels < 2:
		_subdivide_once()
		levels += 1


func _subdivide_once() -> void:
	var verts := _verts
	var raw_n: Variant = _arrays[Mesh.ARRAY_NORMAL]
	var raw_u: Variant = _arrays[Mesh.ARRAY_TEX_UV]
	var has_n := raw_n is PackedVector3Array and (raw_n as PackedVector3Array).size() == verts.size()
	var has_u := raw_u is PackedVector2Array and (raw_u as PackedVector2Array).size() == verts.size()
	var norms: PackedVector3Array = raw_n if has_n else PackedVector3Array()
	var uvs: PackedVector2Array = raw_u if has_u else PackedVector2Array()
	var idx := _tris
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nu := PackedVector2Array()
	var ni := PackedInt32Array()
	for t in range(0, idx.size() - 2, 3):
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		var base := nv.size()
		nv.append(verts[a])
		nv.append(verts[b])
		nv.append(verts[c])
		nv.append((verts[a] + verts[b]) * 0.5)
		nv.append((verts[b] + verts[c]) * 0.5)
		nv.append((verts[c] + verts[a]) * 0.5)
		if has_n:
			nn.append(norms[a])
			nn.append(norms[b])
			nn.append(norms[c])
			nn.append(((norms[a] + norms[b]) * 0.5).normalized())
			nn.append(((norms[b] + norms[c]) * 0.5).normalized())
			nn.append(((norms[c] + norms[a]) * 0.5).normalized())
		if has_u:
			nu.append(uvs[a])
			nu.append(uvs[b])
			nu.append(uvs[c])
			nu.append((uvs[a] + uvs[b]) * 0.5)
			nu.append((uvs[b] + uvs[c]) * 0.5)
			nu.append((uvs[c] + uvs[a]) * 0.5)
		# corner verts 0,1,2 ; midpoints ab=3, bc=4, ca=5 -> 4 sub-triangles
		_add_tri(ni, base, 0, 3, 5)
		_add_tri(ni, base, 3, 1, 4)
		_add_tri(ni, base, 5, 4, 2)
		_add_tri(ni, base, 3, 4, 5)
	_arrays[Mesh.ARRAY_VERTEX] = nv
	_arrays[Mesh.ARRAY_NORMAL] = nn if has_n else null
	_arrays[Mesh.ARRAY_TEX_UV] = nu if has_u else null
	_arrays[Mesh.ARRAY_INDEX] = ni
	_verts = nv
	_tris = ni


func _add_tri(ni: PackedInt32Array, base: int, i: int, j: int, k: int) -> void:
	ni.append(base + i)
	ni.append(base + j)
	ni.append(base + k)


func _measure_extent(verts: PackedVector3Array) -> float:
	var lo := verts[0]
	var hi := verts[0]
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	return maxf(0.001, (hi - lo).length() * 0.5)


func _clear() -> void:
	if _shell != null and is_instance_valid(_shell):
		_shell.queue_free()
	_shell = null
	_material = null
	_runtime_mesh = null
	_arrays = []
	_verts = PackedVector3Array()
	_tris = PackedInt32Array()

@tool
class_name ArtifactConditionDecal
extends Node3D
## An author-placed surface condition on a restoration artifact.
##
## A renderer-adaptive decal: on Forward+/Mobile it builds a real projected engine
## Decal (which wraps onto the surface), and on gl_compatibility it falls back to a
## flat textured quad "sticker" that still draws. Either way it's a child visual of
## this Node3D, so the authoring API is the same.
##
## Drop one onto a RestorationArtifact scene (or instance
## scenes/restoration/artifact_condition_decal.tscn), move it onto the spot that
## should be grimy, and set the `texture` export to a file under
## assets/artifact_conditions/ — the file name *is* the condition type
## (Rust.png -> rust, "Water Stain.png" -> water_stain). At runtime RestorationObject3D
## resolves that type against the journal surface-condition catalog to tint the decal
## and decide which tool cleans it. Cleaning plays the attached GPUParticles3D burst
## and fades the decal out.
##
## Authoring/presentation only: it holds no save state and no cleaning rule of its
## own — the type->tool mapping lives in data, so this stays artifact-agnostic.

## Dirt level (0..255). Starts near-opaque and drops by the tool's power each correct
## stroke; once it reaches MIN_DIRT the condition is cleaned (removed + sparkle).
const START_DIRT: float = 230.0
const MIN_DIRT: float = 55.0
const PARTICLES_NAME := "CleanParticles"  ## The grime puff shown on every clean.
const SPARKLE_PARTICLES_NAME := "SparkleParticles"  ## The success sparkle.
## Dedicated render layer (20) the projected Decal is restricted to, so it lands ONLY on the
## artifact's meshes (which RestorationObject3D puts on this same layer) and never on the
## bench table behind them. Must match RestorationObject3D.ARTIFACT_DECAL_LAYER.
const ARTIFACT_DECAL_LAYER: int = 1 << 19

## The condition texture. Its file name decides the type. (@tool: live-rebuilds the
## visual in the editor so you can see it on the artifact while authoring.)
@export var texture: Texture2D:
	set(value):
		texture = value
		_apply()
## Side length of the decal, in metres.
@export var box_size: float = 0.4:
	set(value):
		box_size = value
		_apply()
## When true (the common case on the rounded medallion) the decal is re-aimed at
## runtime so it sits on the surface beneath it — author by just moving it. Turn off
## for flat artifacts (photos, frames) to keep a hand-set rotation.
@export var align_to_surface: bool = true

var _removed: bool = false
var _dirt: float = START_DIRT
var _tint_color: Color = Color.WHITE
var _highlight_scale: float = 1.0  ## 1.0 = normal; >1 throbs the visual as a tool-match cue.
var _visual: Node3D  ## A Decal (Forward+/Mobile) or a sticker MeshInstance3D (compat).
var _particles: GPUParticles3D  ## Grime puff (every clean).
var _sparkle: GPUParticles3D  ## Success sparkle (when fully cleaned).


func _enter_tree() -> void:
	# In the editor, rebuild the visual whenever the node (re)enters the tree — e.g. right
	# after a duplicate/paste — so a copied or stale Decal child can't linger at the wrong
	# size/opacity. Runtime builds via _ready instead.
	if Engine.is_editor_hint():
		_apply()


func _ready() -> void:
	_apply()
	# Editor just renders the decal so devs can place it; runtime also makes sure a
	# particle burst node exists for cleaning.
	if Engine.is_editor_hint():
		return
	_particles = _ensure_particles()


## (Re)builds the visual for the current renderer from the current texture / box_size.
func _apply() -> void:
	# Free EVERY prior visual before building a fresh one. A decal duplicated in the editor
	# can carry a copied/stale Decal child — sometimes a default 2-metre one (hence a pasted
	# decal looking several times too big), sometimes renamed "Visual2" — and the _visual ref
	# is null on the copy. So clear by TYPE, not by ref or exact name: any Decal, or any
	# "Visual"-named sticker mesh. (CleanParticles/SparkleParticles are GPUParticles3D, so
	# they're untouched.) Leaving one behind stacks decals at the wrong size / double opacity.
	for child in get_children():
		if child is Decal or (child is MeshInstance3D and String(child.name).begins_with("Visual")):
			child.free()
	_visual = null
	# Forward+/Mobile have a RenderingDevice and can draw engine Decals; gl_compatibility
	# (OpenGL) does not, so it falls back to the flat sticker.
	var supported := RenderingServer.get_rendering_device() != null
	_visual = _build_projector() if supported else _build_sticker()
	add_child(_visual)
	_visual.scale = Vector3.ONE * _highlight_scale  # preserve any active highlight on rebuild
	_apply_tint()


## A real projected Decal child (Forward+/Mobile). Rotated so the engine's -Y
## projection points into the surface beneath this node (which faces +Z outward).
func _build_projector() -> Decal:
	var decal := Decal.new()
	decal.name = "Visual"
	decal.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
	decal.texture_albedo = texture
	decal.size = Vector3(box_size, box_size, box_size)
	decal.albedo_mix = 1.0
	decal.upper_fade = 0.0
	decal.lower_fade = 0.0
	# Project ONLY onto the artifact's meshes (which sit on this layer), never the table.
	decal.cull_mask = ARTIFACT_DECAL_LAYER
	return decal


## A flat textured quad "sticker" child (gl_compatibility fallback). Faces +Z.
func _build_sticker() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(box_size, box_size)
	var node := MeshInstance3D.new()
	node.name = "Visual"
	node.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	node.material_override = mat
	return node


## The condition type slug derived from the texture file name (e.g. "Water Stain.png"
## -> "water_stain"). Empty when no texture is set.
func condition_slug() -> String:
	if texture == null:
		return ""
	var path := texture.resource_path
	if path.is_empty():
		return ""
	return path.get_file().get_basename().to_lower().replace(" ", "_").replace("-", "_")


## Tints the decal (and its cleaning particles) to the condition's journal colour.
func tint(color: Color) -> void:
	_tint_color = color
	_apply_tint()
	var particles := _ensure_particles()
	var process := particles.process_material as ParticleProcessMaterial
	if process != null:
		process.color = Color(color.r, color.g, color.b, 1.0)


func _apply_tint() -> void:
	if _visual is Decal:
		(_visual as Decal).texture_albedo = texture
	elif _visual is MeshInstance3D:
		var mat := (_visual as MeshInstance3D).material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_texture = texture
	_set_visual_alpha(clampf(_dirt / 255.0, 0.0, 1.0))


## Sets the decal's opacity, keeping its tint colour.
func _set_visual_alpha(alpha: float) -> void:
	var rgba := Color(_tint_color.r, _tint_color.g, _tint_color.b, alpha)
	if _visual is Decal:
		(_visual as Decal).modulate = rgba
	elif _visual is MeshInstance3D:
		var mat := (_visual as MeshInstance3D).material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = rgba


## Emphasises this decal as a tool-match cue: `intensity` 0..1 throbs the runtime visual a
## little larger (0 restores normal size). Scales ONLY the built visual child, never the
## dev-authored decal node transform, so manual placement/scale is never disturbed.
func set_highlight(intensity: float) -> void:
	_highlight_scale = 1.0 + 0.3 * clampf(intensity, 0.0, 1.0)
	if _visual != null and is_instance_valid(_visual):
		_visual.scale = Vector3.ONE * _highlight_scale


## Pick radius for ray-testing this decal (half the footprint).
func pick_radius() -> float:
	return maxf(0.12, box_size * 0.5)


func is_cleaned() -> bool:
	return _removed


## Restores the decal to fully dirty and visible. Used when a shared decal node is
## reused for a different artifact, so each artifact is cleaned independently.
func reset() -> void:
	_removed = false
	_dirt = START_DIRT
	if _visual != null and is_instance_valid(_visual):
		_visual.visible = true
	_set_visual_alpha(clampf(_dirt / 255.0, 0.0, 1.0))


## Current dirt level (255 = full, MIN_DIRT = clean threshold). Test/UI seam.
func dirt() -> float:
	return _dirt


## The grime puff shown on EVERY tool stroke against this condition — right tool or
## wrong. Purely cosmetic feedback that the tool is doing something here.
func working_burst() -> void:
	var dust := _ensure_particles()
	dust.restart()
	dust.emitting = true


## Removes `power` from the dirt level and fades the decal accordingly. Returns true
## once the condition is fully cleaned (dirt hit MIN_DIRT) — at which point it plays
## the success sparkle and hides. Call working_burst() separately for the per-stroke
## puff; this is the "correct tool" progress step.
func apply_clean(power: int) -> bool:
	if _removed:
		return true
	_dirt -= float(maxi(1, power))
	_set_visual_alpha(clampf(_dirt / 255.0, 0.0, 1.0))
	if _dirt <= MIN_DIRT:
		_removed = true
		_play_sparkle()
		_hide_visual()
		return true
	return false


func _play_sparkle() -> void:
	var sparkle := _ensure_sparkle()
	sparkle.restart()
	sparkle.emitting = true


func _hide_visual() -> void:
	if is_instance_valid(_visual):
		_visual.visible = false


func _ensure_particles() -> GPUParticles3D:
	if _particles != null and is_instance_valid(_particles):
		return _particles
	if has_node(PARTICLES_NAME):
		_particles = get_node(PARTICLES_NAME) as GPUParticles3D
		return _particles
	_particles = GPUParticles3D.new()
	_particles.name = PARTICLES_NAME
	_particles.emitting = false
	_particles.one_shot = true
	_particles.amount = 24
	_particles.lifetime = 0.6
	_particles.explosiveness = 0.9
	_particles.process_material = _default_process_material()
	_particles.draw_pass_1 = _default_particle_mesh()
	add_child(_particles)
	return _particles


func _default_process_material() -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = maxf(0.05, box_size * 0.4)
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 60.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 0.9
	mat.gravity = Vector3(0.0, -0.6, 0.0)
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	return mat


func _default_particle_mesh() -> Mesh:
	var fleck := SphereMesh.new()
	fleck.radius = 0.015
	fleck.height = 0.03
	fleck.radial_segments = 6
	fleck.rings = 3
	return fleck


## The bright "sparkling clean!" burst played once the condition is fully removed.
func _ensure_sparkle() -> GPUParticles3D:
	if _sparkle != null and is_instance_valid(_sparkle):
		return _sparkle
	if has_node(SPARKLE_PARTICLES_NAME):
		_sparkle = get_node(SPARKLE_PARTICLES_NAME) as GPUParticles3D
		return _sparkle
	_sparkle = GPUParticles3D.new()
	_sparkle.name = SPARKLE_PARTICLES_NAME
	_sparkle.emitting = false
	_sparkle.one_shot = true
	_sparkle.amount = 32
	_sparkle.lifetime = 0.8
	_sparkle.explosiveness = 1.0
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = maxf(0.05, box_size * 0.5)
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 50.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.3
	mat.gravity = Vector3(0.0, 0.25, 0.0)  # drift upward — celebratory, not falling
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.color = Color(1.0, 0.97, 0.8, 1.0)  # warm white sparkle
	_sparkle.process_material = mat
	var star := SphereMesh.new()
	star.radius = 0.012
	star.height = 0.024
	star.radial_segments = 6
	star.rings = 3
	_sparkle.draw_pass_1 = star
	add_child(_sparkle)
	return _sparkle

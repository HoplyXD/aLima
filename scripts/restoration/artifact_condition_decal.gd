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

const DEFAULT_OPACITY: float = 0.9
const FADE_TIME: float = 0.25
const PARTICLES_NAME := "CleanParticles"

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
var _tint_color: Color = Color.WHITE
var _visual: Node3D  ## A Decal (Forward+/Mobile) or a sticker MeshInstance3D (compat).
var _particles: GPUParticles3D


func _ready() -> void:
	_apply()
	# Editor just renders the decal so devs can place it; runtime also makes sure a
	# particle burst node exists for cleaning.
	if Engine.is_editor_hint():
		return
	_particles = _ensure_particles()


## (Re)builds the visual for the current renderer from the current texture / box_size.
func _apply() -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
	# Forward+/Mobile have a RenderingDevice and can draw engine Decals; gl_compatibility
	# (OpenGL) does not, so it falls back to the flat sticker.
	var supported := RenderingServer.get_rendering_device() != null
	_visual = _build_projector() if supported else _build_sticker()
	add_child(_visual)
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
	var rgba := Color(_tint_color.r, _tint_color.g, _tint_color.b, DEFAULT_OPACITY)
	if _visual is Decal:
		(_visual as Decal).texture_albedo = texture
		(_visual as Decal).modulate = rgba
	elif _visual is MeshInstance3D:
		var mat := (_visual as MeshInstance3D).material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_texture = texture
			mat.albedo_color = rgba


## Pick radius for ray-testing this decal (half the footprint).
func pick_radius() -> float:
	return maxf(0.12, box_size * 0.5)


func is_cleaned() -> bool:
	return _removed


## Plays the cleaning burst and fades the decal out. Logic elsewhere already treats
## the condition as gone; this is purely the visual.
func play_clean() -> void:
	_removed = true
	var particles := _ensure_particles()
	particles.restart()
	particles.emitting = true
	if not (is_inside_tree() and _visual != null and is_instance_valid(_visual)):
		if _visual != null:
			_visual.visible = false
		return
	var tween := create_tween()
	if _visual is Decal:
		tween.tween_property(_visual, "modulate:a", 0.0, FADE_TIME)
	else:
		var mat := (_visual as MeshInstance3D).material_override as StandardMaterial3D
		if mat == null:
			_visual.visible = false
			return
		tween.tween_property(mat, "albedo_color:a", 0.0, FADE_TIME)
	tween.tween_callback(_hide_visual)


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

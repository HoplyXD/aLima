class_name ArtifactConditionDecal
extends Decal
## An author-placed surface condition on a restoration artifact.
##
## Drop one of these onto a RestorationArtifact scene (or instance
## scenes/restoration/artifact_condition_decal.tscn), move it onto the spot that
## should be grimy, and set `texture_albedo` to a file under
## assets/artifact_conditions/ — the file name *is* the condition type
## (Rust.png -> rust, "Water Stain.png" -> water_stain). At runtime
## RestorationObject3D resolves that type against the journal surface-condition
## catalog (data/journal/surface_conditions.json) to tint the decal and decide which
## tool cleans it. Cleaning plays the attached GPUParticles3D burst and fades it out.
##
## Authoring/presentation only: it holds no save state and no cleaning rule of its
## own — the type->tool mapping lives in data, so this stays artifact-agnostic.

const DEFAULT_OPACITY: float = 0.9
const FADE_TIME: float = 0.25
const PARTICLES_NAME := "CleanParticles"

## When true (the common case on the rounded medallion) the decal is re-aimed at
## runtime so it projects onto the surface beneath it — author by just moving it.
## Turn off for flat artifacts (photos, frames) to keep a hand-set rotation.
@export var align_to_surface: bool = true

var _removed: bool = false
var _particles: GPUParticles3D


func _ready() -> void:
	# Editor just renders the Decal so devs can place it; runtime sets projection
	# defaults and makes sure a particle burst node exists.
	if Engine.is_editor_hint():
		return
	albedo_mix = 1.0
	upper_fade = 0.0
	lower_fade = 0.0
	if size == Vector3.ZERO:
		size = Vector3(0.4, 0.4, 0.4)
	_particles = _ensure_particles()


## The condition type slug derived from the albedo file name (e.g. "Water Stain.png"
## -> "water_stain"). Empty when no albedo texture is set.
func condition_slug() -> String:
	if texture_albedo == null:
		return ""
	var path := texture_albedo.resource_path
	if path.is_empty():
		return ""
	return path.get_file().get_basename().to_lower().replace(" ", "_").replace("-", "_")


## Tints the decal (and its cleaning particles) to the condition's journal colour.
func tint(color: Color) -> void:
	modulate = Color(color.r, color.g, color.b, DEFAULT_OPACITY)
	var particles := _ensure_particles()
	var mat := particles.process_material as ParticleProcessMaterial
	if mat != null:
		mat.color = Color(color.r, color.g, color.b, 1.0)


func is_cleaned() -> bool:
	return _removed


## Plays the cleaning burst and fades the decal out. Logic elsewhere already treats
## the condition as gone; this is purely the visual.
func play_clean() -> void:
	_removed = true
	var particles := _ensure_particles()
	particles.restart()
	particles.emitting = true
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
		tween.tween_callback(_hide_self)
	else:
		visible = false


func _hide_self() -> void:
	visible = false


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
	mat.emission_sphere_radius = maxf(0.05, size.x * 0.4)
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 60.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 0.9
	mat.gravity = Vector3(0.0, -0.6, 0.0)
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	return mat


func _default_particle_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.015
	mesh.height = 0.03
	mesh.radial_segments = 6
	mesh.rings = 3
	return mesh

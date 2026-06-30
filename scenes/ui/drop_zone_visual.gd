class_name DropZoneVisual
extends Node3D
## Presentation-only juice for a diegetic 3D triage drop zone (Keep / Recycle).
##
## This drives the bin's `Ring` (and optional `Pad`) MeshInstance3D through `Tween`s:
## a smooth hover lift + glow, a snap back when the held item leaves, and a sharp
## "absorption" pulse on a successful drop. It owns NO decision logic — TriageController
## still calls TriageState.set_decision()/TriageService.apply_triage(). It only reacts.
##
## Attach this as a child of a bin (KeepBin / RecycleBin), point `ring_path` at the bin's
## `Ring` MeshInstance3D (and `pad_path` at the translucent `Pad`, optional), then drive it
## from the controller with `set_hovered(true/false)` and `play_drop()`.
##
## The ring/pad materials are duplicated at runtime, so tweening never mutates the shared
## scene sub-resource and two bins can glow independently.

## Ring grows to this multiple of its rest scale while hovered (10% by default).
@export var hover_scale: float = 1.1
## Seconds for the smooth hover in / hover out transition.
@export var tween_duration: float = 0.18
## Emission colour the ring/pad blend toward while hovered. Set per-bin in the Inspector
## (e.g. green for Keep, red for Recycle) — defaults to the ring's authored colour if left black.
@export var highlight_color: Color = Color(0, 0, 0, 0)

@export_group("Glow Energy")
## Ring emission energy at rest.
@export var base_energy: float = 0.25
## Ring emission energy while hovered.
@export var hover_energy: float = 2.5

@export_group("Drop Pulse")
## Ring overshoots to this multiple of rest scale at the peak of the drop pulse.
@export var drop_punch_scale: float = 1.35
## Emission energy spike at the peak of the drop pulse.
@export var drop_flash_energy: float = 5.0
## Seconds for the sharp scale-up / flash.
@export var drop_punch_in: float = 0.08
## Seconds for the elastic snap back to rest (or hover) state.
@export var drop_settle: float = 0.45

@export_group("Wiring")
@export var ring_path: NodePath
@export var pad_path: NodePath

var _ring: MeshInstance3D = null
var _pad: MeshInstance3D = null
var _ring_mat: StandardMaterial3D = null
var _pad_mat: StandardMaterial3D = null
var _base_scale: Vector3 = Vector3.ONE
var _base_emission: Color = Color.WHITE
var _hovered: bool = false
var _tween: Tween = null


func _ready() -> void:
	_ring = get_node_or_null(ring_path) as MeshInstance3D
	_pad = get_node_or_null(pad_path) as MeshInstance3D
	_ring_mat = _make_unique_material(_ring)
	_pad_mat = _make_unique_material(_pad)
	if _ring != null:
		_base_scale = _ring.scale
	if _ring_mat != null:
		_base_emission = _ring_mat.emission
		if highlight_color.a <= 0.0:
			highlight_color = _base_emission
	_apply_rest_state()


## Smoothly lifts + glows the zone (true) or settles it back to rest (false).
## Idempotent: re-calling with the same state does nothing.
func set_hovered(on: bool) -> void:
	if on == _hovered:
		return
	_hovered = on
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target_scale := _base_scale * hover_scale if on else _base_scale
	var target_energy := hover_energy if on else base_energy
	var target_color := highlight_color if on else _base_emission
	if _ring != null:
		_tween.tween_property(_ring, "scale", target_scale, tween_duration)
	if _ring_mat != null:
		_tween.tween_property(_ring_mat, "emission_energy_multiplier", target_energy, tween_duration)
		_tween.tween_property(_ring_mat, "emission", target_color, tween_duration)
	if _pad_mat != null:
		_tween.tween_property(_pad_mat, "emission_energy_multiplier", target_energy, tween_duration)


## High-energy "absorption" pulse for a successful drop: a sharp scale punch + emission
## flash that snaps back to whichever state (hover or rest) the zone is in afterwards.
func play_drop() -> void:
	_kill_tween()
	var rest_scale := _base_scale * hover_scale if _hovered else _base_scale
	var rest_energy := hover_energy if _hovered else base_energy
	_tween = create_tween()
	# Punch out hard.
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _ring != null:
		_tween.tween_property(_ring, "scale", _base_scale * drop_punch_scale, drop_punch_in)
	if _ring_mat != null:
		(
			_tween
			. parallel()
			. tween_property(_ring_mat, "emission_energy_multiplier", drop_flash_energy, drop_punch_in)
		)
	# Elastic snap back to the resting/hover state.
	_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if _ring != null:
		_tween.tween_property(_ring, "scale", rest_scale, drop_settle)
	if _ring_mat != null:
		_tween.parallel().tween_property(
			_ring_mat, "emission_energy_multiplier", rest_energy, drop_settle
		)


func _apply_rest_state() -> void:
	if _ring != null:
		_ring.scale = _base_scale
	if _ring_mat != null:
		_ring_mat.emission_energy_multiplier = base_energy
		_ring_mat.emission = _base_emission
	if _pad_mat != null:
		_pad_mat.emission_energy_multiplier = base_energy


## Duplicates a mesh's material so tweens are local to this instance, returning the
## StandardMaterial3D we can animate (or null if the mesh has no usable material).
func _make_unique_material(mesh: MeshInstance3D) -> StandardMaterial3D:
	if mesh == null:
		return null
	var src: Material = mesh.material_override
	if src == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		src = mesh.mesh.surface_get_material(0)
	if src is StandardMaterial3D:
		var unique := (src as StandardMaterial3D).duplicate() as StandardMaterial3D
		unique.emission_enabled = true
		mesh.material_override = unique
		return unique
	return null


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

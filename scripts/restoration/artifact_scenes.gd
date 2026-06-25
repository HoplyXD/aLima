extends RefCounted
## Maps a template id to its authored presentation scene (custom model + placed decals).
## Preloaded by consumers (no class_name) so it resolves without a global-class-cache pass.
##
## A template listed here is shown — on the restoration bench, in card previews, and in
## the triage screen — using its OWN scene instead of the default placeholder. Add an
## entry once an artifact's scene has a real model. Kept central so every place that
## renders an artifact agrees. Templates NOT listed fall back to the placeholder, which is
## why the data-driven test artifacts (photos, the carrier pendant) keep their behaviour.

const _SCENES := {
	"dusty_locket":
	preload("res://scenes/restoration/artifacts/Basic Artifacts/dusty_locket.tscn"),
	"tarnished_pendant":
	preload("res://scenes/restoration/artifacts/Basic Artifacts/tarnished_pendant.tscn"),
	"oton_death_mask":
	preload("res://scenes/restoration/artifacts/Historical Artifacts/oton_death_mask.tscn"),
	"silver_locket":
	preload("res://scenes/restoration/artifacts/Basic Artifacts/silver_locket.tscn"),
	"silver_pendant":
	preload("res://scenes/restoration/artifacts/Basic Artifacts/silver_pendant.tscn"),
	"bronze_locket":
	preload("res://scenes/restoration/artifacts/Basic Artifacts/bronze_locket.tscn"),
	"bronze_pendant":
	preload("res://scenes/restoration/artifacts/Basic Artifacts/bronze_pendant.tscn"),
}


## The authored scene for `template_id`, or `fallback` (the placeholder) when none is set.
static func scene_for(template_id: String, fallback: PackedScene) -> PackedScene:
	return _SCENES.get(template_id, fallback)


static func has_scene(template_id: String) -> bool:
	return _SCENES.has(template_id)
